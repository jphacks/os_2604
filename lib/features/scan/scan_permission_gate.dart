/// C-internal preparation, before opening a camera or starting the scan clock.
abstract interface class ScanPermissionGate {
  Future<bool> request();

  /// Ends the local wait; a late OS permission response must be ignored.
  void cancel();
}
