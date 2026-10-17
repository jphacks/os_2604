import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../settings/onboarding_store.dart';

part 'app_database.g.dart';

/// A singleton row exists only after the introductory explanation is completed.
class OnboardingCompletions extends Table {
  IntColumn get id => integer().customConstraint('NOT NULL CHECK (id = 1)')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The application owns this connection and must await [close] on disposal.
@DriftDatabase(tables: [OnboardingCompletions])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.production() : super(driftDatabase(name: 'os_2604'));

  @override
  int get schemaVersion => 1;
}

/// Uses the supplied database without taking ownership of its connection.
class DriftOnboardingStore implements OnboardingStore {
  DriftOnboardingStore(this._database);

  final AppDatabase _database;

  @override
  Future<bool> hasCompletedOnboarding() async {
    final row = await (_database.select(
      _database.onboardingCompletions,
    )..where((row) => row.id.equals(1))).getSingleOrNull();
    return row != null;
  }

  @override
  Future<void> completeOnboarding() async {
    await _database
        .into(_database.onboardingCompletions)
        .insert(
          const OnboardingCompletionsCompanion(id: Value(1)),
          mode: InsertMode.insertOrIgnore,
        );
  }
}
