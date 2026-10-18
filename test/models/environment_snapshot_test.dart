import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/environment_snapshot.dart';

import '../support/environment_packet.dart';

void main() {
  test('protocol UUID and timing match firmware contract', () {
    final contract = jsonDecode(
      File('firmware/e84/environment-protocol.json').readAsStringSync(),
    ) as Map<String, Object?>;
    expect(contract['serviceUuid'], EnvironmentProtocol.serviceUuid);
    final header = File('firmware/e84/environment/environment_sensor.h')
        .readAsStringSync();
    for (final pair in [
      ('ENV_SERVICE_UUID', EnvironmentProtocol.serviceUuid),
      ('ENV_VALUE_UUID', EnvironmentProtocol.characteristicUuid),
    ]) {
      final definition = RegExp('#define ${pair.$1} ([^\\n]+)')
          .firstMatch(header)!
          .group(1)!;
      final bytes = RegExp(r'0x([0-9a-f]{2})')
          .allMatches(definition)
          .map((m) => m.group(1)!)
          .toList();
      expect(bytes.reversed.join(), pair.$2.replaceAll('-', ''));
    }
    expect(
      contract['characteristicUuid'],
      EnvironmentProtocol.characteristicUuid,
    );
    expect(
      contract['freshnessLimitMs'],
      EnvironmentSnapshot.freshnessLimit.inMilliseconds,
    );
  });
  test('milli units, signed values, zero and range boundaries', () {
    final p = EnvironmentProtocol.parse(environmentPacket());
    expect(p.temperatureC, 23.456);
    expect(p.humidityPct, 56.789);
    for (final t in [-40000, -1, 0, 125000]) {
      for (final h in [0, 100000]) {
        final p = EnvironmentProtocol.parse(
          environmentPacket(temperature: t, humidity: h),
        );
        expect(p.temperatureC, t / 1000);
        expect(p.humidityPct, h / 1000);
      }
    }
    for (final pair in [(-40001, 0), (125001, 0), (0, -1), (0, 100001)]) {
      expect(
        () => EnvironmentProtocol.parse(
          environmentPacket(temperature: pair.$1, humidity: pair.$2),
        ),
        throwsFormatException,
      );
    }
  });
  test('invalid length, byte, version, status, reserved are rejected', () {
    for (final bytes in [
      <int>[],
      List<int>.filled(19, 0),
      List<int>.filled(21, 0),
      environmentPacket()..[0] = 2,
      environmentPacket()..[1] = 4,
      environmentPacket()..[18] = 1,
      environmentPacket()..[19] = 1,
      environmentPacket()..[10] = 256,
      environmentPacket()..[10] = -1,
    ]) {
      expect(() => EnvironmentProtocol.parse(bytes), throwsFormatException);
    }
  });
  test('nonvalid packets ignore undefined age and both numeric fields', () {
    for (final status in [1, 2, 3]) {
      final p = EnvironmentProtocol.parse(
        environmentPacket(
          status: status,
          age: 0xffffffff,
          temperature: -2147483648,
          humidity: 2147483647,
        ),
      );
      expect(p.temperatureC, isNull);
      expect(p.humidityPct, isNull);
      expect(p.age, isNull);
      expect(p.sequence, 1);
    }
  });
  test('snapshot rejects partial, nonfinite, stale or missing metadata', () {
    expect(
      () => EnvironmentSnapshot(
        state: EnvironmentState.disabled,
        ambientTemperatureC: 0,
      ),
      throwsArgumentError,
    );
    for (final t in [double.nan, double.infinity, -41.0]) {
      expect(
        () => EnvironmentSnapshot(
          state: EnvironmentState.available,
          ambientTemperatureC: t,
          relativeHumidityPct: 0,
          receivedAt: DateTime.utc(2026),
          sampleAgeAtSnapshot: Duration.zero,
          sampleSequence: 0,
          protocolVersion: 1,
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => EnvironmentSnapshot(state: EnvironmentState.available),
      throwsArgumentError,
    );
  });
}
