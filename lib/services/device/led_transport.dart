enum BluetoothAvailability { unknown, ready, poweredOff, denied, unsupported }

enum KitLink { connecting, connected, disconnected }

class LedKit {
  const LedKit(this.id, this.name);
  final String id;
  final String name;
}

/// IAS専用。健康記録を受け取らず、消灯と点灯の操作値だけを送る。
abstract interface class LedTransport {
  Stream<BluetoothAvailability> get availability;
  Stream<LedKit> scan();
  Stream<KitLink> connect(String deviceId);
  Future<bool> supportsAlert(String deviceId);
  Future<void> writeAlert(String deviceId, int level);
  Future<void> dispose();
}
