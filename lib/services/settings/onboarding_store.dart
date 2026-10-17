/// Persists whether the user has completed the introductory explanation.
abstract interface class OnboardingStore {
  Future<bool> hasCompletedOnboarding();

  Future<void> completeOnboarding();
}
