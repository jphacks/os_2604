import 'package:flutter/services.dart';

import 'on_device_ai_client.dart';

/// Dart half of a proposed C-internal channel; Swift registration is not present.
/// Missing native code is reported explicitly instead of claiming AI support.
class FoundationModelsClient implements OnDeviceAiClient {
  const FoundationModelsClient({
    MethodChannel channel = const MethodChannel(
      'jp.jphacks.os_2604/on_device_ai',
    ),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<AiAvailability> checkAvailability() async {
    try {
      final value = await _channel.invokeMethod<Object?>('availability');
      if (value is! String) {
        throw const AiClientFailure(AiFallbackReason.invalidResponse);
      }
      return switch (value) {
        'available' => AiAvailability.available,
        'deviceNotEligible' => AiAvailability.unsupported,
        'appleIntelligenceNotEnabled' => AiAvailability.disabled,
        'modelNotReady' => AiAvailability.modelNotReady,
        'initializing' => AiAvailability.initializing,
        'restricted' => AiAvailability.restricted,
        _ => AiAvailability.unavailable,
      };
    } on MissingPluginException {
      return AiAvailability.bridgeUnavailable;
    } on PlatformException catch (error) {
      throw AiClientFailure(
        _reason(error.code, fallback: AiFallbackReason.availabilityCheckFailed),
      );
    }
  }

  @override
  Future<String> generateReflection({
    required String requestId,
    required String instructions,
    required String prompt,
  }) async {
    try {
      final value = await _channel.invokeMethod<Object?>('generateReflection', {
        'requestId': requestId,
        'instructions': instructions,
        'prompt': prompt,
      });
      if (value is! String) {
        throw const AiClientFailure(AiFallbackReason.invalidResponse);
      }
      return value;
    } on MissingPluginException {
      throw const AiClientFailure(AiFallbackReason.bridgeUnavailable);
    } on PlatformException catch (error) {
      throw AiClientFailure(_reason(error.code));
    }
  }

  @override
  Future<void> cancelGeneration(String requestId) =>
      _channel.invokeMethod<void>('cancelGeneration', {'requestId': requestId});

  // Application channel codes, not an exhaustive list of Apple error cases.
  AiFallbackReason _reason(
    String code, {
    AiFallbackReason fallback = AiFallbackReason.generationFailed,
  }) => switch (code) {
    'unsupported' => AiFallbackReason.unsupported,
    'disabled' => AiFallbackReason.disabled,
    'modelNotReady' => AiFallbackReason.modelNotReady,
    'initializing' => AiFallbackReason.initializing,
    'restricted' || 'rateLimited' || 'refused' => AiFallbackReason.restricted,
    'timeout' => AiFallbackReason.timedOut,
    'cancelled' => AiFallbackReason.cancelled,
    _ => fallback,
  };
}
