import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/services/db/app_database.dart';

void main() {
  group('DriftOnboardingStore', () {
    late AppDatabase database;
    late DriftOnboardingStore store;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      store = DriftOnboardingStore(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('a new database has not completed onboarding', () async {
      expect(await store.hasCompletedOnboarding(), isFalse);
    });

    test(
      'completion is awaited and repeated completion is idempotent',
      () async {
        await store.completeOnboarding();
        expect(await store.hasCompletedOnboarding(), isTrue);
        await store.completeOnboarding();
        expect(await store.hasCompletedOnboarding(), isTrue);
        expect(
          await database.select(database.onboardingCompletions).get(),
          hasLength(1),
        );
      },
    );

    test(
      'a SQLite write failure propagates without marking completion',
      () async {
        // Open the schema before installing a real SQLite failure trigger.
        expect(await store.hasCompletedOnboarding(), isFalse);
        await database.customStatement('''
        CREATE TRIGGER reject_onboarding_completion
        BEFORE INSERT ON onboarding_completions
        BEGIN
          SELECT RAISE(ABORT, 'test write failure');
        END
      ''');

        await expectLater(
          store.completeOnboarding(),
          throwsA(isA<Exception>()),
        );
        expect(await store.hasCompletedOnboarding(), isFalse);
      },
    );
  });

  test(
    'completion persists after closing and reopening the file database',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'onboarding_test_',
      );
      final file = File('${directory.path}/settings.sqlite');
      AppDatabase? openDatabase;
      try {
        var database = AppDatabase(NativeDatabase(file));
        openDatabase = database;
        expect(
          await DriftOnboardingStore(database).hasCompletedOnboarding(),
          isFalse,
        );
        await database.close();
        openDatabase = null;

        database = AppDatabase(NativeDatabase(file));
        openDatabase = database;
        final store = DriftOnboardingStore(database);
        expect(await store.hasCompletedOnboarding(), isFalse);
        await store.completeOnboarding();
        await database.close();
        openDatabase = null;

        database = AppDatabase(NativeDatabase(file));
        openDatabase = database;
        expect(
          await DriftOnboardingStore(database).hasCompletedOnboarding(),
          isTrue,
        );
      } finally {
        await openDatabase?.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
