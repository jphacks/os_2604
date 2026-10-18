import 'dart:async';

import 'package:flutter/foundation.dart';

import 'led_transport.dart';
import 'environment_transport.dart';
import '../../models/environment_snapshot.dart';

enum LedConnection { disconnected, connecting, ready, unsupported }

enum LedDelivery { idle, sending, sent, failed, skipped, offSent }

/// 保存を取りまとめる画面が所有する一時トークン。記録IDは不要。
class LedAttempt {
  bool _consumed = false;
}

/// 画面より長く生存する。DB・カメラ・AIの成否を変更しない。
class LedNotificationService extends ChangeNotifier {
  LedNotificationService(
    this._transport, {
    this.pulseDuration = const Duration(seconds: 3),
    this.writeTimeout = const Duration(seconds: 2),
    Duration Function()? monotonicNow,
    this.wallNow = DateTime.now,
  }) {
    _monotonicNow = monotonicNow ?? (() => _clock.elapsed);
  }

  final Stopwatch _clock = Stopwatch()..start();
  late final Duration Function() _monotonicNow;
  final DateTime Function() wallNow;
  bool environmentEnabled = false;
  EnvironmentState _environmentState = EnvironmentState.disconnected;
  EnvironmentPacket? _environmentPacket;
  DateTime? _environmentReceivedAt;
  Duration? _environmentReceivedTick;
  Duration _environmentRoundTrip = Duration.zero;
  bool? _environmentSupported;
  int _environmentOperation = 0;
  int? _environmentBusy;
  int _pendingLed = 0;
  Timer? _environmentTimer;
  Timer? _freshnessTimer;

  EnvironmentSnapshot snapshotEnvironment() {
    if (!environmentEnabled) {
      return EnvironmentSnapshot(state: EnvironmentState.disabled);
    }
    if (!ready) {
      return EnvironmentSnapshot(state: EnvironmentState.disconnected);
    }
    final packet = _environmentPacket;
    if (_environmentState != EnvironmentState.available || packet == null) {
      return EnvironmentSnapshot(state: _environmentState);
    }
    final age =
        packet.age! +
        _environmentRoundTrip +
        (_monotonicNow() - _environmentReceivedTick!);
    if (age > EnvironmentSnapshot.freshnessLimit) {
      return EnvironmentSnapshot(state: EnvironmentState.stale);
    }
    return EnvironmentSnapshot(
      state: EnvironmentState.available,
      ambientTemperatureC: packet.temperatureC,
      relativeHumidityPct: packet.humidityPct,
      receivedAt: _environmentReceivedAt,
      sampleAgeAtSnapshot: age,
      sampleSequence: packet.sequence,
      protocolVersion: 1,
    );
  }

  void enableEnvironment(bool enabled) {
    if (_disposed) return;
    environmentEnabled = enabled;
    _invalidateEnvironment();
    _scheduleEnvironment();
    _emit();
  }

  void _invalidateEnvironment() {
    _environmentOperation++;
    _environmentPacket = null;
    _environmentReceivedTick = null;
    _environmentReceivedAt = null;
    _environmentState = EnvironmentState.disconnected;
    _environmentTimer?.cancel();
    _environmentTimer = null;
    _freshnessTimer?.cancel();
    _freshnessTimer = null;
  }

  void _scheduleEnvironment() {
    if (!environmentEnabled || !ready) return;
    if (_environmentState == EnvironmentState.disconnected) {
      _environmentState = EnvironmentState.initializing;
    }
    _environmentTimer ??= Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollEnvironment(),
    );
    _pollEnvironment();
  }

  void _pollEnvironment() {
    if (!environmentEnabled ||
        !ready ||
        _environmentBusy != null ||
        delivery == LedDelivery.sending ||
        delivery == LedDelivery.sent ||
        _environmentSupported == false) {
      return;
    }
    final transport = _transport;
    if (transport is! EnvironmentTransport) {
      _environmentState = EnvironmentState.unsupported;
      _environmentSupported = false;
      _emit();
      return;
    }
    final environmentTransport = transport as EnvironmentTransport;
    final generation = _generation;
    final operation = _environmentOperation;
    final id = selected!.id;
    _environmentBusy = operation;
    // Schedule low-priority work after synchronous LED commands have queued.
    Timer.run(() {
      _tail = (_tail ?? Future<void>.value()).then((_) async {
        bool current() =>
            _current(generation) &&
            operation == _environmentOperation &&
            ready &&
            environmentEnabled;
        try {
          if (!current() ||
              _pendingLed > 0 ||
              delivery == LedDelivery.sending ||
              delivery == LedDelivery.sent) {
            return;
          }
          final started = _monotonicNow();
          final packet = await (() async {
            final supported =
                _environmentSupported ??
                await environmentTransport.supportsEnvironment(id);
            if (!current()) return null;
            _environmentSupported = supported;
            if (!supported) return null;
            return EnvironmentProtocol.parse(
              await environmentTransport.readEnvironment(id),
            );
          })().timeout(writeTimeout);
          if (!current()) return;
          if (packet == null) {
            _environmentState = EnvironmentState.unsupported;
            _environmentPacket = null;
          } else {
            _environmentState = packet.state;
            _environmentPacket = packet;
            _environmentReceivedAt = wallNow().toUtc();
            _environmentReceivedTick = _monotonicNow();
            _environmentRoundTrip = _environmentReceivedTick! - started;
            _freshnessTimer?.cancel();
            if (packet.state == EnvironmentState.available) {
              final remaining =
                  EnvironmentSnapshot.freshnessLimit -
                  packet.age! -
                  _environmentRoundTrip;
              _freshnessTimer = Timer(
                remaining.isNegative
                    ? Duration.zero
                    : remaining + const Duration(microseconds: 1),
                _emit,
              );
            }
          }
          _emit();
        } on UnsupportedEnvironmentProtocol {
          if (!current()) return;
          _environmentSupported = false;
          _environmentPacket = null;
          _environmentState = EnvironmentState.unsupported;
          _freshnessTimer?.cancel();
          _emit();
        } on TimeoutException {
          if (!_current(generation)) return;
          // A timed-out Future cannot cancel the native read; close the session.
          unawaited(disconnect(clearLed: false));
        } catch (_) {
          if (!current()) return;
          _environmentPacket = null;
          _environmentState = EnvironmentState.readFailed;
          _freshnessTimer?.cancel();
          _emit();
        } finally {
          if (_environmentBusy == operation) _environmentBusy = null;
        }
      });
    });
  }

  final LedTransport _transport;
  final Duration pulseDuration;
  final Duration writeTimeout;
  BluetoothAvailability bluetooth = BluetoothAvailability.unknown;
  LedConnection connection = LedConnection.disconnected;
  LedDelivery delivery = LedDelivery.idle;
  final Map<String, LedKit> _kits = {};
  List<LedKit> get kits => List.unmodifiable(_kits.values);
  LedKit? selected;
  bool scanning = false;
  String? discoveryMessage;
  bool automatic = false;
  bool testSent = false;
  bool _foreground = true;
  bool _disposed = false;
  int _generation = 0;
  int _operation = 0;
  LedAttempt? _attempt;
  StreamSubscription<BluetoothAvailability>? _status;
  StreamSubscription<LedKit>? _scan;
  StreamSubscription<KitLink>? _link;
  Timer? _scanTimer;
  Timer? _offTimer;
  Future<void>? _tail;

  bool get ready =>
      !_disposed &&
      _foreground &&
      bluetooth == BluetoothAvailability.ready &&
      connection == LedConnection.ready;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  /// ユーザーが接続画面を開くまでBluetoothを初期化しない。
  void initialize() {
    if (_status != null || _disposed) return;
    _status = _transport.availability.listen(
      (value) {
        bluetooth = value;
        if (value != BluetoothAvailability.ready) {
          stopScan();
          unawaited(disconnect());
        }
        _emit();
      },
      onError: (Object _) {
        bluetooth = BluetoothAvailability.unsupported;
        stopScan();
        unawaited(disconnect());
      },
    );
  }

  void startScan() {
    if (_disposed || !_foreground || bluetooth != BluetoothAvailability.ready) {
      return;
    }
    stopScan();
    _kits.clear();
    discoveryMessage = null;
    scanning = true;
    _scan = _transport.scan().listen(
      (kit) {
        _kits[kit.id] = kit;
        _emit();
      },
      onError: (Object _) {
        discoveryMessage = 'キットを検索できませんでした。もう一度お試しください。';
        stopScan();
      },
      onDone: stopScan,
    );
    _scanTimer = Timer(const Duration(seconds: 10), stopScan);
    _emit();
  }

  void stopScan() {
    _scanTimer?.cancel();
    _scanTimer = null;
    final scan = _scan;
    _scan = null;
    if (scan != null) unawaited(scan.cancel().catchError((Object _) {}));
    scanning = false;
    _emit();
  }

  Future<void> connect(LedKit kit) async {
    if (_disposed || !_foreground || bluetooth != BluetoothAvailability.ready) {
      return;
    }
    final closing = disconnect();
    final generation = _generation;
    await closing;
    if (!_current(generation) ||
        !_foreground ||
        bluetooth != BluetoothAvailability.ready) {
      return;
    }
    stopScan();
    selected = kit;
    connection = LedConnection.connecting;
    var verifying = false;
    _link = _transport
        .connect(kit.id)
        .listen(
          (link) {
            if (!_current(generation)) return;
            if (link == KitLink.connected && !verifying) {
              verifying = true;
              unawaited(_verify(kit.id, generation));
            } else if (link == KitLink.disconnected) {
              unawaited(disconnect());
            }
          },
          onError: (Object _) {
            if (_current(generation)) unawaited(disconnect());
          },
          onDone: () {
            if (_current(generation)) unawaited(disconnect());
          },
        );
    _emit();
  }

  Future<void> _verify(String id, int generation) async {
    try {
      final supported = await _transport
          .supportsAlert(id)
          .timeout(const Duration(seconds: 5));
      if (!_current(generation)) return;
      if (!supported) {
        await disconnect();
        if (_generation == generation + 1) {
          connection = LedConnection.unsupported;
          _emit();
        }
        return;
      }
      // 消灯を投入できた接続だけを準備完了とする。
      final off = await _write(0, generation, _operation);
      if (off && _current(generation)) {
        connection = LedConnection.ready;
        _scheduleEnvironment();
        _emit();
      } else if (_current(generation)) {
        await disconnect();
      }
    } catch (_) {
      if (_current(generation)) await disconnect();
    }
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  /// キューを直列化し、未投入の古い命令を捨てる。
  /// timeoutは取消ではないため、上限超過後は接続も破棄する。
  Future<bool> _write(int level, int generation, int operation) {
    final id = selected?.id;
    final done = Completer<bool>();
    _pendingLed++;
    _tail = (_tail ?? Future<void>.value()).then((_) async {
      try {
        if (!_current(generation) ||
            operation != _operation ||
            id == null ||
            (level == 2 && !_foreground)) {
          done.complete(false);
          return;
        }
        try {
          await _transport.writeAlert(id, level).timeout(writeTimeout);
          done.complete(_current(generation) && operation == _operation);
        } catch (_) {
          done.complete(false);
          if (_current(generation)) {
            final closing = disconnect(clearLed: false);
            final failedGeneration = _generation;
            await closing;
            if (_current(failedGeneration)) {
              delivery = LedDelivery.failed;
              _emit();
            }
          }
        }
      } finally {
        _pendingLed--;
      }
    });
    return done.future;
  }

  LedAttempt beginAttempt() {
    final attempt = LedAttempt();
    _attempt = attempt;
    _newOperation();
    delivery = LedDelivery.idle;
    if (ready) unawaited(_write(0, _generation, _operation));
    _emit();
    return attempt;
  }

  void cancelAttempt(LedAttempt? attempt) {
    if (attempt == null || !identical(attempt, _attempt)) return;
    _attempt = null;
    _newOperation();
    if (ready) unawaited(_write(0, _generation, _operation));
  }

  /// 呼び出し元が有効計測のinsert成功を確認した後にだけ呼ぶ。
  /// 戻りを結果画面やAI生成が待たない。
  void saved(LedAttempt attempt) {
    if (!identical(attempt, _attempt) || attempt._consumed || _disposed) return;
    attempt._consumed = true; // 未接続でも消費。再接続時に再送しない。
    if (!automatic || !ready) {
      delivery = LedDelivery.skipped;
      _emit();
      return;
    }
    unawaited(_pulse());
  }

  void enableAutomatic(bool enabled) {
    automatic = enabled && ready && testSent;
    _emit();
  }

  Future<void> testLed() async {
    if (!ready || delivery == LedDelivery.sending) return;
    await _pulse();
    if (delivery == LedDelivery.sent) testSent = true;
    _emit();
  }

  Future<void> _pulse() async {
    _newOperation();
    final generation = _generation;
    final operation = _operation;
    delivery = LedDelivery.sending;
    _emit();
    final sent = await _write(2, generation, operation);
    if (!_current(generation) || operation != _operation) return;
    delivery = sent ? LedDelivery.sent : LedDelivery.failed;
    if (sent) {
      _offTimer = Timer(pulseDuration, () async {
        final off = await _write(0, generation, operation);
        if (_current(generation) && operation == _operation) {
          delivery = off ? LedDelivery.offSent : LedDelivery.failed;
          _emit();
        }
      });
    }
    _emit();
  }

  Future<void> turnOff() async {
    _newOperation();
    if (!ready) return;
    final generation = _generation;
    final operation = _operation;
    final off = await _write(0, generation, operation);
    if (_current(generation) && operation == _operation) {
      delivery = off ? LedDelivery.offSent : LedDelivery.failed;
      _emit();
    }
  }

  void _newOperation() {
    _operation++;
    _offTimer?.cancel();
    _offTimer = null;
  }

  Future<void> disconnect({bool clearLed = true}) async {
    final canClear =
        clearLed &&
        !_disposed &&
        connection == LedConnection.ready &&
        bluetooth == BluetoothAvailability.ready;
    _generation++;
    _invalidateEnvironment();
    _environmentSupported = null;
    final generation = _generation;
    _newOperation();
    connection = LedConnection.disconnected;
    automatic = false;
    testSent = false;
    delivery = LedDelivery.idle;
    final link = _link;
    _link = null;
    _emit();
    // 未投入の点灯を無効化した後、同じ接続へ直列に消灯を試す。
    // 背景化でOSが停止する場合もあるため、実消灯は保証しない。
    if (canClear) await _write(0, generation, _operation);
    // cancellation severs the connection; a timed-out write is never retried.
    try {
      await link?.cancel().timeout(writeTimeout);
    } catch (_) {
      /* 状態は未接続のまま。 */
    }
    _emit();
  }

  void setForeground(bool foreground, {bool interrupt = true}) {
    _foreground = foreground;
    if (!foreground) _invalidateEnvironment();
    if (foreground) _scheduleEnvironment();
    if (!foreground && interrupt) {
      _attempt = null;
      stopScan();
      unawaited(disconnect());
    }
    _emit();
  }

  @override
  void dispose() {
    _disposed = true;
    stopScan();
    unawaited(disconnect());
    unawaited(_status?.cancel() ?? Future.value());
    unawaited(_transport.dispose().catchError((Object _) {}));
    super.dispose();
  }
}
