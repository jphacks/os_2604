/// Optional capabilities of the existing connection, never a second connection.
abstract interface class EnvironmentTransport {
  Future<bool> supportsEnvironment(String deviceId);
  Future<List<int>> readEnvironment(String deviceId);
}
