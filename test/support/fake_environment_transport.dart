import 'dart:async';

import 'package:os_2604/services/device/environment_transport.dart';

import 'fake_led_transport.dart';
import 'environment_packet.dart';

class FakeEnvironmentTransport extends FakeLedTransport
    implements EnvironmentTransport {
  bool environmentSupported = true;
  bool failRead = false;
  int reads = 0;
  int discoveries = 0;
  Completer<List<int>>? readGate;
  Completer<bool>? environmentDiscoveryGate;
  List<int> packet = environmentPacket();
  final operations = <String>[];
  @override
  Future<bool> supportsEnvironment(String id) async {
    discoveries++;
    return environmentDiscoveryGate?.future ?? environmentSupported;
  }

  @override
  Future<List<int>> readEnvironment(String id) async {
    reads++;
    operations.add('read');
    if (failRead) throw StateError('synthetic read failure');
    return readGate?.future ?? packet;
  }

  @override
  Future<void> writeAlert(String id, int level) async {
    operations.add('led:$level');
    await super.writeAlert(id, level);
  }
}
