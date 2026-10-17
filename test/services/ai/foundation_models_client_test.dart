import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/ai/foundation_models_client.dart';
import '../../../lib/services/ai/on_device_ai_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.os2604/foundation-models');
  const client = FoundationModelsClient(channel: channel);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  final states = <String, AiAvailability>{
    'available': AiAvailability.available,
    'deviceNotEligible': AiAvailability.unsupported,
    'appleIntelligenceNotEnabled': AiAvailability.disabled,
    'modelNotReady': AiAvailability.modelNotReady,
    'initializing': AiAvailability.initializing,
    'restricted': AiAvailability.restricted,
    'unavailable': AiAvailability.unavailable,
    'futureUnknownReason': AiAvailability.unavailable,
  };
  for (final entry in states.entries) {
    test('availability wire status ${entry.key}', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'availability');
        expect(call.arguments, isNull);
        return entry.key;
      });
      expect(await client.checkAvailability(), entry.value);
    });
  }

  test(
    'missing Swift bridge is distinguished from an unsupported device',
    () async {
      expect(
        await client.checkAvailability(),
        AiAvailability.bridgeUnavailable,
      );
      await expectLater(
        client.generateReflection(
          requestId: 'synthetic-id',
          instructions: 'synthetic instructions',
          prompt: 'synthetic prompt',
        ),
        throwsA(
          isA<AiClientFailure>().having(
            (error) => error.reason,
            'reason',
            AiFallbackReason.bridgeUnavailable,
          ),
        ),
      );
    },
  );

  for (final response in <Object?>[
    null,
    1,
    <String, Object?>{'state': 'available'},
  ]) {
    test('malformed availability value $response is rejected', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => response);
      await expectLater(
        client.checkAvailability(),
        throwsA(
          isA<AiClientFailure>().having(
            (error) => error.reason,
            'reason',
            AiFallbackReason.invalidResponse,
          ),
        ),
      );
    });
  }

  test('generation and cancellation carry the same request identity', () async {
    final methods = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      final args = call.arguments as Map<Object?, Object?>;
      expect(args['requestId'], 'synthetic-id');
      if (call.method == 'generateReflection') {
        expect(args['instructions'], 'synthetic instructions');
        expect(args['prompt'], 'synthetic prompt');
        return 'reviewRecord';
      }
      return null;
    });
    expect(
      await client.generateReflection(
        requestId: 'synthetic-id',
        instructions: 'synthetic instructions',
        prompt: 'synthetic prompt',
      ),
      'reviewRecord',
    );
    await client.cancelGeneration('synthetic-id');
    expect(methods, ['generateReflection', 'cancelGeneration']);
  });

  test('non-string generation output is rejected', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => 72);
    await expectLater(
      client.generateReflection(
        requestId: 'synthetic-id',
        instructions: 'synthetic instructions',
        prompt: 'synthetic prompt',
      ),
      throwsA(
        isA<AiClientFailure>().having(
          (error) => error.reason,
          'reason',
          AiFallbackReason.invalidResponse,
        ),
      ),
    );
  });

  final failures = <String, AiFallbackReason>{
    'unsupported': AiFallbackReason.unsupported,
    'disabled': AiFallbackReason.disabled,
    'modelNotReady': AiFallbackReason.modelNotReady,
    'initializing': AiFallbackReason.initializing,
    'restricted': AiFallbackReason.restricted,
    'rateLimited': AiFallbackReason.restricted,
    'refused': AiFallbackReason.restricted,
    'timeout': AiFallbackReason.timedOut,
    'cancelled': AiFallbackReason.cancelled,
    'unknown': AiFallbackReason.generationFailed,
  };
  for (final entry in failures.entries) {
    test('generation error code ${entry.key} is normalized', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(
          code: entry.key,
          message: 'synthetic private detail',
        );
      });
      await expectLater(
        client.generateReflection(
          requestId: 'synthetic-id',
          instructions: 'synthetic instructions',
          prompt: 'synthetic prompt',
        ),
        throwsA(
          isA<AiClientFailure>().having(
            (error) => error.reason,
            'reason',
            entry.value,
          ),
        ),
      );
    });
  }

  test(
    'unknown availability error is not labeled as generation failure',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(
          code: 'unknown',
          message: 'synthetic private detail',
        );
      });
      await expectLater(
        client.checkAvailability(),
        throwsA(
          isA<AiClientFailure>().having(
            (error) => error.reason,
            'reason',
            AiFallbackReason.availabilityCheckFailed,
          ),
        ),
      );
    },
  );
}
