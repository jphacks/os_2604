/// C-internal availability states. These are not Swift enum names.
enum AiAvailability {
  available,
  unsupported,
  disabled,
  modelNotReady,
  initializing,
  restricted,
  bridgeUnavailable,
  unavailable,
}

enum AiFallbackReason {
  unsupported,
  disabled,
  modelNotReady,
  initializing,
  restricted,
  bridgeUnavailable,
  unavailable,
  availabilityCheckFailed,
  generationFailed,
  invalidResponse,
  timedOut,
  busy,
  cancelled,
  disposed,
  invalidScan,
}

/// Typed failures carry no prompt, health values or native exception text.
class AiClientFailure implements Exception {
  const AiClientFailure(this.reason);
  final AiFallbackReason reason;
}

/// A local-only transport. No cloud implementation or automatic network fallback.
abstract interface class OnDeviceAiClient {
  Future<AiAvailability> checkAvailability();

  /// Must return one permitted reflection key, not display-ready free text.
  Future<String> generateReflection({
    required String requestId,
    required String instructions,
    required String prompt,
  });

  /// Best effort. The original generation future must also settle after cancel.
  Future<void> cancelGeneration(String requestId);
}
