import 'dart:async';

import 'package:os_2604/services/device/led_transport.dart';

class FakeLedTransport implements LedTransport {
  final status = StreamController<BluetoothAvailability>.broadcast(sync: true);
  final devices = StreamController<LedKit>.broadcast(sync: true);
  final links = <StreamController<KitLink>>[];
  final writes = <(String, int)>[];
  Completer<void>? writeGate;
  Completer<bool>? discoveryGate;
  Completer<void>? linkCancelGate;
  bool supported = true;
  bool failWrite = false;

  @override
  Stream<BluetoothAvailability> get availability => status.stream;
  @override
  Stream<LedKit> scan() => devices.stream;
  @override
  Stream<KitLink> connect(String id) {
    final cancelGate = linkCancelGate;
    final link = StreamController<KitLink>(
      sync: true,
      onCancel: () => cancelGate?.future,
    );
    links.add(link);
    return link.stream;
  }

  @override
  Future<bool> supportsAlert(String id) async =>
      discoveryGate?.future ?? supported;

  @override
  Future<void> writeAlert(String id, int level) async {
    writes.add((id, level));
    await writeGate?.future;
    if (failWrite) throw StateError('test write failed');
  }

  @override
  Future<void> dispose() async {
    await status.close();
    await devices.close();
    for (final link in links) {
      await link.close();
    }
  }
}
