import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import 'led_transport.dart';
import 'environment_transport.dart';
import '../../models/environment_snapshot.dart';

class ReactiveLedTransport implements LedTransport, EnvironmentTransport {
  ReactiveLedTransport({FlutterReactiveBle? ble})
    : _ble = ble ?? FlutterReactiveBle();

  final FlutterReactiveBle _ble;
  static final serviceId = Uuid.parse('00001802-0000-1000-8000-00805f9b34fb');
  static final alertId = Uuid.parse('00002a06-0000-1000-8000-00805f9b34fb');

  @override
  Stream<BluetoothAvailability> get availability => _ble.statusStream.map(
    (status) => switch (status) {
      BleStatus.ready => BluetoothAvailability.ready,
      BleStatus.poweredOff => BluetoothAvailability.poweredOff,
      BleStatus.unauthorized => BluetoothAvailability.denied,
      BleStatus.unsupported ||
      BleStatus.locationServicesDisabled => BluetoothAvailability.unsupported,
      BleStatus.unknown => BluetoothAvailability.unknown,
    },
  );

  @override
  Stream<LedKit> scan() => _ble
      // Official Find Me advertises its name, but no service UUIDs.
      // Verify the actual IAS characteristic after the user selects a candidate.
      .scanForDevices(withServices: const [])
      .where(
        (d) =>
            d.name == 'Find Me Target' ||
            d.serviceUuids.any((id) => id.expanded == serviceId),
      )
      .map((d) => LedKit(d.id, d.name));

  @override
  Stream<KitLink> connect(String deviceId) => _ble
      .connectToDevice(
        id: deviceId,
        connectionTimeout: const Duration(seconds: 10),
      )
      .map(
        (update) => switch (update.connectionState) {
          DeviceConnectionState.connected => KitLink.connected,
          DeviceConnectionState.connecting => KitLink.connecting,
          _ => KitLink.disconnected,
        },
      );

  @override
  Future<bool> supportsAlert(String deviceId) async {
    await _ble.discoverAllServices(deviceId);
    final services = await _ble.getDiscoveredServices(deviceId);
    return services.any(
      (service) =>
          service.id.expanded == serviceId &&
          service.characteristics.any(
            (c) => c.id.expanded == alertId && c.isWritableWithoutResponse,
          ),
    );
  }

  @override
  Future<void> writeAlert(String deviceId, int level) {
    if (level != 0 && level != 2) throw ArgumentError.value(level, 'level');
    return _ble.writeCharacteristicWithoutResponse(
      QualifiedCharacteristic(
        deviceId: deviceId,
        serviceId: serviceId,
        characteristicId: alertId,
      ),
      value: [level],
    );
  }

  @override
  Future<bool> supportsEnvironment(String deviceId) async {
    final services = await _ble.getDiscoveredServices(deviceId);
    return services.any(
      (service) =>
          service.id.expanded == Uuid.parse(EnvironmentProtocol.serviceUuid) &&
          service.characteristics.any(
            (c) =>
                c.id.expanded ==
                    Uuid.parse(EnvironmentProtocol.characteristicUuid) &&
                c.isReadable,
          ),
    );
  }

  @override
  Future<List<int>> readEnvironment(String deviceId) => _ble.readCharacteristic(
    QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: Uuid.parse(EnvironmentProtocol.serviceUuid),
      characteristicId: Uuid.parse(EnvironmentProtocol.characteristicUuid),
    ),
  );

  @override
  Future<void> dispose() => _ble.deinitialize();
}
