import 'dart:typed_data';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/services/device/reactive_led_transport.dart';
import 'package:os_2604/models/environment_snapshot.dart';

class _Ble extends Fake implements FlutterReactiveBle {
  List<Uuid>? scanFilter;
  List<DiscoveredDevice> devices = [];
  List<Service> services = [];
  String? discoveredDevice;
  QualifiedCharacteristic? readTarget;
  @override
  Future<List<int>> readCharacteristic(
    QualifiedCharacteristic characteristic,
  ) async {
    readTarget = characteristic;
    return List<int>.filled(20, 0);
  }

  @override
  Stream<DiscoveredDevice> scanForDevices({
    required List<Uuid> withServices,
    ScanMode scanMode = ScanMode.balanced,
    bool requireLocationServicesEnabled = true,
  }) {
    scanFilter = withServices;
    return Stream.fromIterable(devices);
  }

  @override
  Future<void> discoverAllServices(String deviceId) async {
    discoveredDevice = deviceId;
  }

  @override
  Future<List<Service>> getDiscoveredServices(String deviceId) async =>
      services;
}

class _Service extends Fake implements Service {
  _Service(this.id, this.characteristics);

  @override
  final Uuid id;
  @override
  final List<Characteristic> characteristics;
}

class _Characteristic extends Fake implements Characteristic {
  _Characteristic(
    this.id, {
    required this.isWritableWithoutResponse,
    this.isReadable = false,
  });
  @override
  final bool isReadable;

  @override
  final Uuid id;
  @override
  final bool isWritableWithoutResponse;
}

DiscoveredDevice _device(
  String id,
  String name, [
  List<Uuid> services = const [],
]) => DiscoveredDevice(
  id: id,
  name: name,
  serviceData: const {},
  manufacturerData: Uint8List(0),
  rssi: -50,
  serviceUuids: services,
);

void main() {
  test('environment capability requires project UUID pair and readable property; read shares chosen device', () async {
    final ble = _Ble();
    final transport = ReactiveLedTransport(ble: ble);
    expect(await transport.supportsEnvironment('kit'), isFalse);
    for (final readable in [false, true]) {
      ble.services = [
        _Service(Uuid.parse(EnvironmentProtocol.serviceUuid), [
          _Characteristic(
            Uuid.parse(EnvironmentProtocol.characteristicUuid),
            isWritableWithoutResponse: false,
            isReadable: readable,
          ),
        ]),
      ];
      expect(await transport.supportsEnvironment('kit'), readable);
    }
    expect(await transport.readEnvironment('kit'), hasLength(20));
    expect(ble.readTarget!.deviceId, 'kit');
    expect(
      ble.readTarget!.serviceId,
      Uuid.parse(EnvironmentProtocol.serviceUuid),
    );
    expect(
      ble.readTarget!.characteristicId,
      Uuid.parse(EnvironmentProtocol.characteristicUuid),
    );
    expect(
      ble.discoveredDevice,
      isNull,
    ); // Uses the already discovered connection.
  });
  test(
    'official name-only advertisement is discoverable without an IAS filter',
    () async {
      final ble = _Ble()
        ..devices = [
          _device('kit', 'Find Me Target'),
          _device('other', 'Other device'),
        ];
      final kits = await ReactiveLedTransport(ble: ble).scan().toList();

      expect(ble.scanFilter, isEmpty);
      expect(kits.map((kit) => kit.id), ['kit']);
      expect(kits.single.name, 'Find Me Target');
      expect(ble.discoveredDevice, isNull); // Selection precedes connection.
    },
  );

  test(
    'IAS advertisements accept short and full UUIDs and preserve candidates',
    () async {
      final ble = _Ble()
        ..devices = [
          _device('a', '', [Uuid.parse('1802')]),
          _device('b', 'Other IAS kit', [ReactiveLedTransport.serviceId]),
          _device('c', 'Find Me Target'),
          _device('d', 'Find Me Target'),
          _device('other', 'Find Me Target clone'),
        ];
      final kits = await ReactiveLedTransport(ble: ble).scan().toList();
      expect(kits.map((kit) => kit.id), ['a', 'b', 'c', 'd']);
    },
  );

  test('name alone cannot bypass GATT or write property validation', () async {
    final ble = _Ble();
    final transport = ReactiveLedTransport(ble: ble);
    expect(await transport.supportsAlert('kit'), isFalse);
    ble.services = [
      _Service(Uuid.parse('1802'), [
        _Characteristic(Uuid.parse('2a06'), isWritableWithoutResponse: false),
      ]),
    ];
    expect(await transport.supportsAlert('kit'), isFalse);
    ble.services = [
      _Service(Uuid.parse('1802'), [
        _Characteristic(Uuid.parse('2a06'), isWritableWithoutResponse: true),
      ]),
    ];
    expect(await transport.supportsAlert('kit'), isTrue);
    expect(ble.discoveredDevice, 'kit');
  });
}
