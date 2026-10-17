// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $OnboardingCompletionsTable extends OnboardingCompletions
    with TableInfo<$OnboardingCompletionsTable, OnboardingCompletion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OnboardingCompletionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL CHECK (id = 1)',
  );
  @override
  List<GeneratedColumn> get $columns => [id];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'onboarding_completions';
  @override
  VerificationContext validateIntegrity(
    Insertable<OnboardingCompletion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OnboardingCompletion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OnboardingCompletion(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
    );
  }

  @override
  $OnboardingCompletionsTable createAlias(String alias) {
    return $OnboardingCompletionsTable(attachedDatabase, alias);
  }
}

class OnboardingCompletion extends DataClass
    implements Insertable<OnboardingCompletion> {
  final int id;
  const OnboardingCompletion({required this.id});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    return map;
  }

  OnboardingCompletionsCompanion toCompanion(bool nullToAbsent) {
    return OnboardingCompletionsCompanion(id: Value(id));
  }

  factory OnboardingCompletion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OnboardingCompletion(id: serializer.fromJson<int>(json['id']));
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'id': serializer.toJson<int>(id)};
  }

  OnboardingCompletion copyWith({int? id}) =>
      OnboardingCompletion(id: id ?? this.id);
  OnboardingCompletion copyWithCompanion(OnboardingCompletionsCompanion data) {
    return OnboardingCompletion(id: data.id.present ? data.id.value : this.id);
  }

  @override
  String toString() {
    return (StringBuffer('OnboardingCompletion(')
          ..write('id: $id')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => id.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OnboardingCompletion && other.id == this.id);
}

class OnboardingCompletionsCompanion
    extends UpdateCompanion<OnboardingCompletion> {
  final Value<int> id;
  const OnboardingCompletionsCompanion({this.id = const Value.absent()});
  OnboardingCompletionsCompanion.insert({this.id = const Value.absent()});
  static Insertable<OnboardingCompletion> custom({Expression<int>? id}) {
    return RawValuesInsertable({if (id != null) 'id': id});
  }

  OnboardingCompletionsCompanion copyWith({Value<int>? id}) {
    return OnboardingCompletionsCompanion(id: id ?? this.id);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OnboardingCompletionsCompanion(')
          ..write('id: $id')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $OnboardingCompletionsTable onboardingCompletions =
      $OnboardingCompletionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [onboardingCompletions];
}

typedef $$OnboardingCompletionsTableCreateCompanionBuilder =
    OnboardingCompletionsCompanion Function({Value<int> id});
typedef $$OnboardingCompletionsTableUpdateCompanionBuilder =
    OnboardingCompletionsCompanion Function({Value<int> id});

class $$OnboardingCompletionsTableFilterComposer
    extends Composer<_$AppDatabase, $OnboardingCompletionsTable> {
  $$OnboardingCompletionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OnboardingCompletionsTableOrderingComposer
    extends Composer<_$AppDatabase, $OnboardingCompletionsTable> {
  $$OnboardingCompletionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OnboardingCompletionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OnboardingCompletionsTable> {
  $$OnboardingCompletionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);
}

class $$OnboardingCompletionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OnboardingCompletionsTable,
          OnboardingCompletion,
          $$OnboardingCompletionsTableFilterComposer,
          $$OnboardingCompletionsTableOrderingComposer,
          $$OnboardingCompletionsTableAnnotationComposer,
          $$OnboardingCompletionsTableCreateCompanionBuilder,
          $$OnboardingCompletionsTableUpdateCompanionBuilder,
          (
            OnboardingCompletion,
            BaseReferences<
              _$AppDatabase,
              $OnboardingCompletionsTable,
              OnboardingCompletion
            >,
          ),
          OnboardingCompletion,
          PrefetchHooks Function()
        > {
  $$OnboardingCompletionsTableTableManager(
    _$AppDatabase db,
    $OnboardingCompletionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OnboardingCompletionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$OnboardingCompletionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$OnboardingCompletionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback: ({Value<int> id = const Value.absent()}) =>
              OnboardingCompletionsCompanion(id: id),
          createCompanionCallback: ({Value<int> id = const Value.absent()}) =>
              OnboardingCompletionsCompanion.insert(id: id),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $OnboardingCompletionsTable,
                    OnboardingCompletion
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $OnboardingCompletionsTable,
                    OnboardingCompletion
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OnboardingCompletionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OnboardingCompletionsTable,
      OnboardingCompletion,
      $$OnboardingCompletionsTableFilterComposer,
      $$OnboardingCompletionsTableOrderingComposer,
      $$OnboardingCompletionsTableAnnotationComposer,
      $$OnboardingCompletionsTableCreateCompanionBuilder,
      $$OnboardingCompletionsTableUpdateCompanionBuilder,
      (
        OnboardingCompletion,
        BaseReferences<
          _$AppDatabase,
          $OnboardingCompletionsTable,
          OnboardingCompletion
        >,
      ),
      OnboardingCompletion,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$OnboardingCompletionsTableTableManager get onboardingCompletions =>
      $$OnboardingCompletionsTableTableManager(_db, _db.onboardingCompletions);
}
