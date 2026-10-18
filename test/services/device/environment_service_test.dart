import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/models/environment_snapshot.dart';
import 'package:os_2604/services/device/led_notification_service.dart';
import 'package:os_2604/services/device/led_transport.dart';

import '../../support/environment_packet.dart';
import '../../support/fake_environment_transport.dart';

void main() {
  late FakeEnvironmentTransport transport;
  late LedNotificationService service;
  late DateTime wall;
  void connect(FakeAsync time, {bool expectReady = true}) {
    unawaited(service.connect(const LedKit('kit', 'Find Me Target')));
    time.flushMicrotasks();
    transport.links.last.add(KitLink.connected);
    time.flushMicrotasks();
    time.elapse(Duration.zero);
    time.flushMicrotasks();
    expect(service.ready, expectReady);
  }

  void setup(FakeAsync time) {
    transport = FakeEnvironmentTransport();
    wall = DateTime.utc(2026, 10, 18);
    service = LedNotificationService(
      transport,
      monotonicNow: () => time.elapsed,
      wallNow: () => wall,
    );
    service.initialize();
    transport.status.add(BluetoothAvailability.ready);
    time.flushMicrotasks();
    connect(time);
  }

  void enable(FakeAsync time) {
    service.enableEnvironment(true);
    time.elapse(Duration.zero);
    time.flushMicrotasks();
  }

  void done(FakeAsync time) {
    service.dispose();
    time.flushMicrotasks();
  }

  test('opt-in, single connection and LED automatic off still reads', () {
    fakeAsync((time) {
      setup(time);
      expect(transport.reads, 0);
      expect(service.snapshotEnvironment().state, EnvironmentState.disabled);
      enable(time);
      expect(transport.links, hasLength(1));
      expect(service.automatic, isFalse);
      expect(service.snapshotEnvironment().ambientTemperatureC, 23.456);
      expect(transport.reads, 1);
      time.elapse(const Duration(seconds: 2));
      expect(transport.reads, 2);
      service.enableEnvironment(false);
      time.elapse(const Duration(seconds: 5));
      expect(transport.reads, 2);
      expect(service.snapshotEnvironment().relativeHumidityPct, isNull);
      done(time);
    });
  });
  test('5-second boundary adds sample age, RTT, monotonic elapsed; no wall clock dependency', () {
    fakeAsync((time) {
      setup(time);
      transport.readGate = Completer<List<int>>();
      enable(time);
      time.elapse(const Duration(seconds: 1));
      transport.readGate!.complete(environmentPacket(age: 3000));
      time.flushMicrotasks();
      expect(
        service.snapshotEnvironment().sampleAgeAtSnapshot,
        const Duration(seconds: 4),
      );
      wall = wall.subtract(const Duration(days: 30));
      // Hold the next read open while checking the original pair's freshness.
      transport.readGate = Completer<List<int>>();
      time.elapse(const Duration(seconds: 1));
      expect(service.snapshotEnvironment().state, EnvironmentState.available);
      expect(
        service.snapshotEnvironment().sampleAgeAtSnapshot,
        const Duration(seconds: 5),
      );
      time.elapse(const Duration(microseconds: 1));
      expect(service.snapshotEnvironment().state, EnvironmentState.stale);
      expect(service.snapshotEnvironment().ambientTemperatureC, isNull);
      done(time);
    });
  });
  test(
    'read timeout invalidates session and late response cannot enter reconnect',
    () {
      fakeAsync((time) {
        setup(time);
        final old = Completer<List<int>>();
        transport.readGate = old;
        enable(time);
        time.elapse(const Duration(seconds: 2));
        time.flushMicrotasks();
        expect(service.connection, LedConnection.disconnected);
        expect(transport.reads, 1);
        transport.readGate = null;
        transport.packet = environmentPacket(temperature: -1000, sequence: 1);
        connect(time);
        expect(service.snapshotEnvironment().ambientTemperatureC, -1);
        old.complete(environmentPacket(temperature: 90000, sequence: 1));
        time.flushMicrotasks();
        expect(service.snapshotEnvironment().ambientTemperatureC, -1);
        done(time);
      });
    },
  );
  test('old discovery, disable, background and device change cannot revive cached values', () {
    fakeAsync((time) {
      setup(time);
      final old = Completer<bool>();
      transport.environmentDiscoveryGate = old;
      enable(time);
      service.setForeground(false);
      time.flushMicrotasks();
      transport.environmentDiscoveryGate = null;
      transport.environmentSupported = false;
      service.setForeground(true);
      connect(time, expectReady: false);
      old.complete(true);
      time.flushMicrotasks();
      // The old queued operation releases first, then next poll checks this session.
      time.elapse(const Duration(seconds: 2));
      expect(service.snapshotEnvironment().state, EnvironmentState.unsupported);
      expect(transport.reads, 0);
      expect(service.ready, isTrue); // IAS is independent.
      done(time);
    });
  });
  test('old firmware and sensor errors keep LED operational, values null', () {
    fakeAsync((time) {
      setup(time);
      transport.environmentSupported = false;
      enable(time);
      expect(service.snapshotEnvironment().state, EnvironmentState.unsupported);
      unawaited(service.testLed());
      time.flushMicrotasks();
      expect(transport.writes.last.$2, 2);
      unawaited(service.disconnect());
      time.flushMicrotasks();
      transport.environmentSupported = true;
      transport.packet = environmentPacket(status: 2);
      connect(time);
      expect(service.snapshotEnvironment().state, EnvironmentState.sensorError);
      expect(service.snapshotEnvironment().ambientTemperatureC, isNull);
      done(time);
    });
  });
  test('unknown protocol and reserved bytes disable environment without disconnecting IAS', () {
    fakeAsync((time) {
      setup(time);
      transport.packet = environmentPacket()..[0] = 2;
      enable(time);
      expect(service.snapshotEnvironment().state, EnvironmentState.unsupported);
      expect(service.ready, isTrue);
      expect(service.snapshotEnvironment().ambientTemperatureC, isNull);
      done(time);
    });
    fakeAsync((time) {
      setup(time);
      transport.packet = environmentPacket()..[18] = 1;
      enable(time);
      expect(service.snapshotEnvironment().state, EnvironmentState.unsupported);
      expect(service.ready, isTrue);
      done(time);
    });
  });
  test('timeout still closes same session after acquisition is disabled', () {
    fakeAsync((time) {
      setup(time);
      transport.readGate = Completer<List<int>>();
      enable(time);
      service.enableEnvironment(false);
      time.elapse(const Duration(seconds: 2));
      expect(service.connection, LedConnection.disconnected);
      expect(service.snapshotEnvironment().state, EnvironmentState.disabled);
      done(time);
    });
  });
  test('invalid packet or read exception clears prior pair and recovers', () {
    fakeAsync((time) {
      setup(time);
      enable(time);
      expect(service.snapshotEnvironment().state, EnvironmentState.available);
      transport.packet = [1];
      time.elapse(const Duration(seconds: 2));
      expect(service.snapshotEnvironment().state, EnvironmentState.readFailed);
      transport.packet = environmentPacket(temperature: 0, humidity: 0);
      time.elapse(const Duration(seconds: 2));
      expect(service.snapshotEnvironment().ambientTemperatureC, 0);
      transport.failRead = true;
      time.elapse(const Duration(seconds: 2));
      expect(service.snapshotEnvironment().relativeHumidityPct, isNull);
      done(time);
    });
  });
  test(
    'LED commands take queue priority; reads do not cancel pulse off timer',
    () {
      fakeAsync((time) {
        setup(time);
        service.enableEnvironment(true); // queued as low priority timer
        unawaited(service.testLed());
        time.flushMicrotasks();
        time.elapse(Duration.zero);
        expect(transport.operations.last, 'led:2');
        expect(
          transport.reads,
          0,
        ); // Keep queue clear for the pulse-off deadline.
        time.elapse(const Duration(seconds: 3));
        expect(transport.writes.last.$2, 0);
        expect(service.delivery, LedDelivery.offSent);
        time.elapse(const Duration(seconds: 1));
        expect(transport.reads, 1);
        done(time);
      });
    },
  );
  test('inflight read does not stack, LED waits only for that read', () {
    fakeAsync((time) {
      setup(time);
      final read = Completer<List<int>>();
      transport.readGate = read;
      enable(time);
      unawaited(service.testLed());
      time.flushMicrotasks();
      time.elapse(const Duration(milliseconds: 1900));
      expect(transport.reads, 1);
      expect(transport.writes.last.$2, 0);
      read.complete(environmentPacket());
      time.flushMicrotasks();
      expect(transport.writes.last.$2, 2);
      transport.readGate = null;
      time.elapse(const Duration(seconds: 3));
      expect(transport.writes.last.$2, 0);
      done(time);
    });
  });
}
