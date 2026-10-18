import 'dart:typed_data';

enum EnvironmentState {
  available,
  disabled,
  disconnected,
  unsupported,
  initializing,
  sensorError,
  outOfRange,
  stale,
  readFailed,
}

/// One pair from SHT40, frozen at scan completion. Never a body temperature.
class EnvironmentSnapshot {
  EnvironmentSnapshot({
    required this.state,
    this.ambientTemperatureC,
    this.relativeHumidityPct,
    this.receivedAt,
    this.sampleAgeAtSnapshot,
    this.sampleSequence,
    this.protocolVersion,
  }) {
    final t = ambientTemperatureC;
    final h = relativeHumidityPct;
    if (state == EnvironmentState.available) {
      if (t == null ||
          h == null ||
          !t.isFinite ||
          !h.isFinite ||
          t < -40 ||
          t > 125 ||
          h < 0 ||
          h > 100 ||
          receivedAt == null ||
          sampleAgeAtSnapshot == null ||
          sampleAgeAtSnapshot!.isNegative ||
          sampleAgeAtSnapshot! > freshnessLimit ||
          sampleSequence == null ||
          sampleSequence! < 0 ||
          sampleSequence! > 0xffffffff ||
          protocolVersion != 1) {
        throw ArgumentError('Invalid environment snapshot');
      }
    } else if (t != null || h != null || sampleAgeAtSnapshot != null) {
      throw ArgumentError('Unavailable environment values must be null');
    }
  }

  static const source = 'e84_sht40';
  static const freshnessLimit = Duration(seconds: 5);
  final EnvironmentState state;
  final double? ambientTemperatureC;
  final double? relativeHumidityPct;
  final DateTime? receivedAt;
  final Duration? sampleAgeAtSnapshot;
  final int? sampleSequence;
  final int? protocolVersion;
}

class UnsupportedEnvironmentProtocol extends FormatException {
  const UnsupportedEnvironmentProtocol()
    : super('Unsupported environment protocol');
}

/// Project-owned UUIDs; shared with firmware/e84/environment-protocol.json.
abstract final class EnvironmentProtocol {
  static const serviceUuid = '3c1d0001-8e4b-4b1c-9a62-6d485a7e9010';
  static const characteristicUuid = '3c1d0002-8e4b-4b1c-9a62-6d485a7e9010';

  static EnvironmentPacket parse(List<int> bytes) {
    if (bytes.length != 20 || bytes.any((b) => b < 0 || b > 255)) {
      throw const FormatException('Environment packet must be 20 bytes');
    }
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    if (data.getUint8(0) != 1 || data.getUint16(18, Endian.little) != 0) {
      throw const UnsupportedEnvironmentProtocol();
    }
    final state = switch (data.getUint8(1)) {
      0 => EnvironmentState.available,
      1 => EnvironmentState.initializing,
      2 => EnvironmentState.sensorError,
      3 => EnvironmentState.outOfRange,
      _ => throw const FormatException('Unknown environment status'),
    };
    final sequence = data.getUint32(2, Endian.little);
    // For non-valid states, age and numeric fields are undefined.
    if (state != EnvironmentState.available) {
      return EnvironmentPacket(state: state, sequence: sequence);
    }
    final t = data.getInt32(10, Endian.little) / 1000.0;
    final h = data.getInt32(14, Endian.little) / 1000.0;
    if (t < -40 || t > 125 || h < 0 || h > 100) {
      throw const FormatException('Environment values outside sensor range');
    }
    return EnvironmentPacket(
      state: state,
      sequence: sequence,
      age: Duration(milliseconds: data.getUint32(6, Endian.little)),
      temperatureC: t,
      humidityPct: h,
    );
  }
}

class EnvironmentPacket {
  const EnvironmentPacket({
    required this.state,
    required this.sequence,
    this.age,
    this.temperatureC,
    this.humidityPct,
  });
  final EnvironmentState state;
  final int sequence;
  final Duration? age;
  final double? temperatureC;
  final double? humidityPct;
}
