import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/services/device/led_notification_service.dart';
import 'package:os_2604/services/device/led_transport.dart';

import '../../support/fake_led_transport.dart';

void main() {
  late FakeLedTransport transport;
  late LedNotificationService service;

  void setup(FakeAsync time) {
    transport = FakeLedTransport();
    service = LedNotificationService(transport);
    service.initialize();
    transport.status.add(BluetoothAvailability.ready);
    time.flushMicrotasks();
  }

  void connect(FakeAsync time, [String id = 'kit-a']) {
    unawaited(service.connect(LedKit(id, 'Find Me Target')));
    time.flushMicrotasks();
    transport.links.last.add(KitLink.connected);
    time.flushMicrotasks();
    expect(service.ready, isTrue);
    expect(transport.writes.last, (id, 0));
  }

  void enable(FakeAsync time) {
    unawaited(service.testLed());
    time.flushMicrotasks();
    service.enableAutomatic(true);
    expect(service.automatic, isTrue);
    time.elapse(const Duration(seconds: 3));
    time.flushMicrotasks();
    transport.writes.clear();
  }

  test(
    'explicit selection, property validation, initial off, no health payload',
    () {
      fakeAsync((time) {
        setup(time);
        service.startScan();
        transport.devices.add(const LedKit('a', 'Find Me Target'));
        transport.devices.add(const LedKit('b', 'Find Me Target'));
        expect(service.kits, hasLength(2));
        expect(transport.links, isEmpty);
        time.elapse(const Duration(seconds: 10));
        expect(service.scanning, isFalse);
        connect(time);
        expect(transport.writes, [('kit-a', 0)]);
        expect(service.automatic, isFalse);
        service.enableAutomatic(true);
        expect(service.automatic, isFalse);
        service.dispose();
        time.flushMicrotasks();
      });
    },
  );

  test(
    'one pulse only after saved, 3 second off survives ordinary navigation',
    () {
      fakeAsync((time) {
        setup(time);
        connect(time);
        enable(time);
        final attempt = service.beginAttempt();
        time.flushMicrotasks();
        expect(transport.writes, [('kit-a', 0)]);
        service.saved(attempt);
        service.saved(attempt);
        time.flushMicrotasks();
        expect(transport.writes, [('kit-a', 0), ('kit-a', 2)]);
        time.elapse(const Duration(milliseconds: 2999));
        expect(transport.writes.last.$2, 2);
        time.elapse(const Duration(milliseconds: 1));
        time.flushMicrotasks();
        expect(transport.writes.last.$2, 0);
        expect(service.delivery, LedDelivery.offSent);
        service.saved(attempt);
        time.flushMicrotasks();
        expect(transport.writes.where((w) => w.$2 == 2), hasLength(1));
        service.dispose();
        time.flushMicrotasks();
      });
    },
  );

  test('cancelled and replaced attempts cannot pulse', () {
    fakeAsync((time) {
      setup(time);
      connect(time);
      enable(time);
      final cancelled = service.beginAttempt();
      service.cancelAttempt(cancelled);
      service.saved(cancelled);
      final old = service.beginAttempt();
      final current = service.beginAttempt();
      service.saved(old);
      time.flushMicrotasks();
      expect(transport.writes.every((w) => w.$2 == 0), isTrue);
      service.saved(current);
      time.flushMicrotasks();
      expect(transport.writes.last.$2, 2);
      service.dispose();
      time.flushMicrotasks();
    });
  });

  test('background invalidates pending completion and cancels timer', () {
    fakeAsync((time) {
      setup(time);
      connect(time);
      enable(time);
      final attempt = service.beginAttempt();
      service.saved(attempt);
      service.setForeground(false);
      time.flushMicrotasks();
      service.setForeground(true);
      service.saved(attempt);
      time.elapse(const Duration(seconds: 5));
      time.flushMicrotasks();
      expect(transport.writes.every((w) => w.$2 == 0), isTrue);
      expect(service.ready, isFalse);
      service.dispose();
      time.flushMicrotasks();
    });
  });

  test('unconnected completion is consumed, reconnect does not replay it', () {
    fakeAsync((time) {
      setup(time);
      final attempt = service.beginAttempt();
      service.saved(attempt);
      expect(service.delivery, LedDelivery.skipped);
      connect(time);
      enable(time);
      service.saved(attempt);
      time.flushMicrotasks();
      expect(transport.writes, isEmpty);
      service.dispose();
      time.flushMicrotasks();
    });
  });

  test(
    'permission dialog inactive holds connection but cannot start a pulse',
    () {
      fakeAsync((time) {
        setup(time);
        connect(time);
        enable(time);
        final attempt = service.beginAttempt();
        time.flushMicrotasks();
        transport.writes.clear();
        service.setForeground(false, interrupt: false);
        expect(service.ready, isFalse);
        expect(service.connection, LedConnection.ready);
        service.setForeground(true);
        service.saved(attempt);
        time.flushMicrotasks();
        expect(transport.writes, [('kit-a', 2)]);
        service.dispose();
        time.flushMicrotasks();
      });
    },
  );

  test('old off timer does not extinguish new pulse', () {
    fakeAsync((time) {
      setup(time);
      connect(time);
      enable(time);
      service.saved(service.beginAttempt());
      time.flushMicrotasks();
      time.elapse(const Duration(seconds: 2));
      final next = service.beginAttempt();
      time.flushMicrotasks();
      service.saved(next);
      time.flushMicrotasks();
      final count = transport.writes.length;
      time.elapse(const Duration(seconds: 1));
      time.flushMicrotasks();
      expect(transport.writes, hasLength(count));
      time.elapse(const Duration(seconds: 2));
      time.flushMicrotasks();
      expect(transport.writes.last.$2, 0);
      service.dispose();
      time.flushMicrotasks();
    });
  });

  for (final timeout in [false, true]) {
    test(
      'write ${timeout ? 'timeout' : 'exception'} disconnects without retry or stale update',
      () {
        fakeAsync((time) {
          setup(time);
          connect(time);
          enable(time);
          final attempt = service.beginAttempt();
          time.flushMicrotasks();
          transport.writes.clear();
          if (timeout) {
            transport.writeGate = Completer<void>();
          } else {
            transport.failWrite = true;
          }
          service.saved(attempt);
          time.flushMicrotasks();
          time.elapse(const Duration(seconds: 2));
          time.flushMicrotasks();
          expect(service.delivery, LedDelivery.failed);
          expect(service.ready, isFalse);
          expect(transport.writes, [('kit-a', 2)]);
          transport.failWrite = false;
          final oldGate = transport.writeGate;
          transport.writeGate = null;
          connect(time, 'kit-b');
          enable(time);
          final next = service.beginAttempt();
          time.flushMicrotasks();
          service.saved(next);
          time.flushMicrotasks();
          oldGate?.complete();
          time.flushMicrotasks();
          expect(service.delivery, LedDelivery.sent);
          expect(transport.writes.last, ('kit-b', 2));
          service.saved(attempt);
          time.flushMicrotasks();
          expect(transport.writes.where((w) => w.$2 == 2), hasLength(1));
          service.dispose();
          time.flushMicrotasks();
        });
      },
    );
  }

  test('late discovery on previous connection cannot mark new kit ready', () {
    fakeAsync((time) {
      setup(time);
      final gate = Completer<bool>();
      transport.discoveryGate = gate;
      unawaited(service.connect(const LedKit('old', 'Find Me Target')));
      time.flushMicrotasks();
      transport.links.last.add(KitLink.connected);
      time.flushMicrotasks();
      transport.discoveryGate = null;
      connect(time, 'new');
      gate.complete(true);
      time.flushMicrotasks();
      expect(transport.writes, [('new', 0)]);
      expect(service.selected?.id, 'new');
      service.dispose();
      time.flushMicrotasks();
    });
  });

  test(
    'late disconnect completion cannot overwrite a new connection status',
    () {
      fakeAsync((time) {
        setup(time);
        final cancelGate = Completer<void>();
        transport.linkCancelGate = cancelGate;
        connect(time);
        enable(time);
        final attempt = service.beginAttempt();
        time.flushMicrotasks();
        transport.failWrite = true;
        service.saved(attempt);
        time.flushMicrotasks();
        expect(service.connection, LedConnection.disconnected);
        transport.failWrite = false;
        transport.linkCancelGate = null;
        unawaited(service.connect(const LedKit('new', 'Find Me Target')));
        time.flushMicrotasks();
        transport.links.last.add(KitLink.connected);
        time.flushMicrotasks();
        cancelGate.complete();
        time.flushMicrotasks();
        expect(service.ready, isTrue);
        expect(service.delivery, LedDelivery.idle);
        service.dispose();
        time.flushMicrotasks();
      });
    },
  );

  test('unsupported characteristic never ready or sends', () {
    fakeAsync((time) {
      setup(time);
      transport.supported = false;
      unawaited(service.connect(const LedKit('wrong', 'Find Me Target')));
      time.flushMicrotasks();
      transport.links.last.add(KitLink.connected);
      time.flushMicrotasks();
      expect(service.connection, LedConnection.unsupported);
      expect(transport.writes, isEmpty);
      service.dispose();
      time.flushMicrotasks();
    });
  });

  for (final status in [
    BluetoothAvailability.denied,
    BluetoothAvailability.poweredOff,
  ]) {
    test('$status stops scan and disconnects', () {
      fakeAsync((time) {
        setup(time);
        connect(time);
        enable(time);
        final attempt = service.beginAttempt();
        transport.status.add(status);
        service.saved(attempt);
        time.flushMicrotasks();
        expect(service.bluetooth, status);
        expect(service.scanning, isFalse);
        expect(service.ready, isFalse);
        expect(transport.writes, isEmpty);
        service.dispose();
        time.flushMicrotasks();
      });
    });
  }
}
