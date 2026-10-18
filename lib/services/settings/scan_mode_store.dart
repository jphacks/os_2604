/// Device-local preference. New installations use standard scans.
abstract interface class ScanModeStore {
  Future<bool> loadResearchMode();
  Future<void> saveResearchMode(bool enabled);
}
