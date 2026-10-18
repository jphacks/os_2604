import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/environment_snapshot.dart';
import '../db/environment_record_repository.dart';

enum EnvironmentSaveState { saving, saved, failed, deleted }

/// App-owned: survives normal navigation and retries only the frozen snapshot.
class EnvironmentSaveService extends ChangeNotifier {
  EnvironmentSaveService(this.store);
  final EnvironmentRecordStore store;
  final _entries =
      <String, ({EnvironmentSnapshot snapshot, EnvironmentSaveState state})>{};
  bool _disposed = false;
  EnvironmentSaveState? stateFor(String id) => _entries[id]?.state;

  void savedHealthRecord(String id, EnvironmentSnapshot snapshot) {
    if (_disposed || _entries.containsKey(id)) return;
    _entries[id] = (snapshot: snapshot, state: EnvironmentSaveState.saving);
    notifyListeners();
    unawaited(_write(id, snapshot));
  }

  void retry(String id) {
    final entry = _entries[id];
    if (_disposed ||
        entry == null ||
        entry.state != EnvironmentSaveState.failed) {
      return;
    }
    _entries[id] = (
      snapshot: entry.snapshot,
      state: EnvironmentSaveState.saving,
    );
    notifyListeners();
    unawaited(_write(id, entry.snapshot));
  }

  Future<void> _write(String id, EnvironmentSnapshot snapshot) async {
    var state = EnvironmentSaveState.failed;
    try {
      state = await store.attach(id, snapshot)
          ? EnvironmentSaveState.saved
          : EnvironmentSaveState.deleted;
    } catch (_) {
      /* Health record remains saved; the same snapshot can retry. */
    }
    if (_disposed) return;
    _entries[id] = (snapshot: snapshot, state: state);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
