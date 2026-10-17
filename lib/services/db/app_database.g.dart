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

class $HealthRecordsTable extends HealthRecords
    with TableInfo<$HealthRecordsTable, HealthRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HealthRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> measuredAt =
      GeneratedColumn<int>(
        'measured_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($HealthRecordsTable.$convertermeasuredAt);
  static const VerificationMeta _elapsedMicrosMeta = const VerificationMeta(
    'elapsedMicros',
  );
  @override
  late final GeneratedColumn<int> elapsedMicros = GeneratedColumn<int>(
    'elapsed_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _faceDetectedMeta = const VerificationMeta(
    'faceDetected',
  );
  @override
  late final GeneratedColumn<bool> faceDetected = GeneratedColumn<bool>(
    'face_detected',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("face_detected" IN (0, 1))',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<MeasurementQuality, String>
  quality = GeneratedColumn<String>(
    'quality',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<MeasurementQuality>($HealthRecordsTable.$converterquality);
  static const VerificationMeta _estimatedHeartRateBpmMeta =
      const VerificationMeta('estimatedHeartRateBpm');
  @override
  late final GeneratedColumn<double> estimatedHeartRateBpm =
      GeneratedColumn<double>(
        'estimated_heart_rate_bpm',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  @override
  late final GeneratedColumnWithTypeConverter<HeartRateSource, String>
  heartRateSource =
      GeneratedColumn<String>(
        'heart_rate_source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<HeartRateSource>(
        $HealthRecordsTable.$converterheartRateSource,
      );
  static const VerificationMeta _faceColorFeatureMeta = const VerificationMeta(
    'faceColorFeature',
  );
  @override
  late final GeneratedColumn<double> faceColorFeature = GeneratedColumn<double>(
    'face_color_feature',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _selfConditionMeta = const VerificationMeta(
    'selfCondition',
  );
  @override
  late final GeneratedColumn<int> selfCondition = GeneratedColumn<int>(
    'self_condition',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyTemperatureCMeta = const VerificationMeta(
    'bodyTemperatureC',
  );
  @override
  late final GeneratedColumn<double> bodyTemperatureC = GeneratedColumn<double>(
    'body_temperature_c',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TemperatureSource, String>
  temperatureSource =
      GeneratedColumn<String>(
        'temperature_source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TemperatureSource>(
        $HealthRecordsTable.$convertertemperatureSource,
      );
  static const VerificationMeta _reportTextMeta = const VerificationMeta(
    'reportText',
  );
  @override
  late final GeneratedColumn<String> reportText = GeneratedColumn<String>(
    'report_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ReportMode?, String> aiMode =
      GeneratedColumn<String>(
        'ai_mode',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<ReportMode?>($HealthRecordsTable.$converteraiModen);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    measuredAt,
    elapsedMicros,
    faceDetected,
    quality,
    estimatedHeartRateBpm,
    heartRateSource,
    faceColorFeature,
    selfCondition,
    bodyTemperatureC,
    temperatureSource,
    reportText,
    aiMode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'health_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<HealthRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('elapsed_micros')) {
      context.handle(
        _elapsedMicrosMeta,
        elapsedMicros.isAcceptableOrUnknown(
          data['elapsed_micros']!,
          _elapsedMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_elapsedMicrosMeta);
    }
    if (data.containsKey('face_detected')) {
      context.handle(
        _faceDetectedMeta,
        faceDetected.isAcceptableOrUnknown(
          data['face_detected']!,
          _faceDetectedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_faceDetectedMeta);
    }
    if (data.containsKey('estimated_heart_rate_bpm')) {
      context.handle(
        _estimatedHeartRateBpmMeta,
        estimatedHeartRateBpm.isAcceptableOrUnknown(
          data['estimated_heart_rate_bpm']!,
          _estimatedHeartRateBpmMeta,
        ),
      );
    }
    if (data.containsKey('face_color_feature')) {
      context.handle(
        _faceColorFeatureMeta,
        faceColorFeature.isAcceptableOrUnknown(
          data['face_color_feature']!,
          _faceColorFeatureMeta,
        ),
      );
    }
    if (data.containsKey('self_condition')) {
      context.handle(
        _selfConditionMeta,
        selfCondition.isAcceptableOrUnknown(
          data['self_condition']!,
          _selfConditionMeta,
        ),
      );
    }
    if (data.containsKey('body_temperature_c')) {
      context.handle(
        _bodyTemperatureCMeta,
        bodyTemperatureC.isAcceptableOrUnknown(
          data['body_temperature_c']!,
          _bodyTemperatureCMeta,
        ),
      );
    }
    if (data.containsKey('report_text')) {
      context.handle(
        _reportTextMeta,
        reportText.isAcceptableOrUnknown(data['report_text']!, _reportTextMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HealthRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HealthRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      measuredAt: $HealthRecordsTable.$convertermeasuredAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}measured_at'],
        )!,
      ),
      elapsedMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}elapsed_micros'],
      )!,
      faceDetected: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}face_detected'],
      )!,
      quality: $HealthRecordsTable.$converterquality.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}quality'],
        )!,
      ),
      estimatedHeartRateBpm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}estimated_heart_rate_bpm'],
      ),
      heartRateSource: $HealthRecordsTable.$converterheartRateSource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}heart_rate_source'],
        )!,
      ),
      faceColorFeature: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}face_color_feature'],
      ),
      selfCondition: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}self_condition'],
      ),
      bodyTemperatureC: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}body_temperature_c'],
      ),
      temperatureSource: $HealthRecordsTable.$convertertemperatureSource
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}temperature_source'],
            )!,
          ),
      reportText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}report_text'],
      ),
      aiMode: $HealthRecordsTable.$converteraiModen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}ai_mode'],
        ),
      ),
    );
  }

  @override
  $HealthRecordsTable createAlias(String alias) {
    return $HealthRecordsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertermeasuredAt =
      const _MicrosecondsConverter();
  static JsonTypeConverter2<MeasurementQuality, String, String>
  $converterquality = const EnumNameConverter<MeasurementQuality>(
    MeasurementQuality.values,
  );
  static JsonTypeConverter2<HeartRateSource, String, String>
  $converterheartRateSource = const EnumNameConverter<HeartRateSource>(
    HeartRateSource.values,
  );
  static JsonTypeConverter2<TemperatureSource, String, String>
  $convertertemperatureSource = const EnumNameConverter<TemperatureSource>(
    TemperatureSource.values,
  );
  static JsonTypeConverter2<ReportMode, String, String> $converteraiMode =
      const EnumNameConverter<ReportMode>(ReportMode.values);
  static JsonTypeConverter2<ReportMode?, String?, String?> $converteraiModen =
      JsonTypeConverter2.asNullable($converteraiMode);
}

class HealthRecord extends DataClass implements Insertable<HealthRecord> {
  final String id;
  final DateTime measuredAt;
  final int elapsedMicros;
  final bool faceDetected;
  final MeasurementQuality quality;
  final double? estimatedHeartRateBpm;
  final HeartRateSource heartRateSource;
  final double? faceColorFeature;
  final int? selfCondition;
  final double? bodyTemperatureC;
  final TemperatureSource temperatureSource;
  final String? reportText;
  final ReportMode? aiMode;
  const HealthRecord({
    required this.id,
    required this.measuredAt,
    required this.elapsedMicros,
    required this.faceDetected,
    required this.quality,
    this.estimatedHeartRateBpm,
    required this.heartRateSource,
    this.faceColorFeature,
    this.selfCondition,
    this.bodyTemperatureC,
    required this.temperatureSource,
    this.reportText,
    this.aiMode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['measured_at'] = Variable<int>(
        $HealthRecordsTable.$convertermeasuredAt.toSql(measuredAt),
      );
    }
    map['elapsed_micros'] = Variable<int>(elapsedMicros);
    map['face_detected'] = Variable<bool>(faceDetected);
    {
      map['quality'] = Variable<String>(
        $HealthRecordsTable.$converterquality.toSql(quality),
      );
    }
    if (!nullToAbsent || estimatedHeartRateBpm != null) {
      map['estimated_heart_rate_bpm'] = Variable<double>(estimatedHeartRateBpm);
    }
    {
      map['heart_rate_source'] = Variable<String>(
        $HealthRecordsTable.$converterheartRateSource.toSql(heartRateSource),
      );
    }
    if (!nullToAbsent || faceColorFeature != null) {
      map['face_color_feature'] = Variable<double>(faceColorFeature);
    }
    if (!nullToAbsent || selfCondition != null) {
      map['self_condition'] = Variable<int>(selfCondition);
    }
    if (!nullToAbsent || bodyTemperatureC != null) {
      map['body_temperature_c'] = Variable<double>(bodyTemperatureC);
    }
    {
      map['temperature_source'] = Variable<String>(
        $HealthRecordsTable.$convertertemperatureSource.toSql(
          temperatureSource,
        ),
      );
    }
    if (!nullToAbsent || reportText != null) {
      map['report_text'] = Variable<String>(reportText);
    }
    if (!nullToAbsent || aiMode != null) {
      map['ai_mode'] = Variable<String>(
        $HealthRecordsTable.$converteraiModen.toSql(aiMode),
      );
    }
    return map;
  }

  HealthRecordsCompanion toCompanion(bool nullToAbsent) {
    return HealthRecordsCompanion(
      id: Value(id),
      measuredAt: Value(measuredAt),
      elapsedMicros: Value(elapsedMicros),
      faceDetected: Value(faceDetected),
      quality: Value(quality),
      estimatedHeartRateBpm: estimatedHeartRateBpm == null && nullToAbsent
          ? const Value.absent()
          : Value(estimatedHeartRateBpm),
      heartRateSource: Value(heartRateSource),
      faceColorFeature: faceColorFeature == null && nullToAbsent
          ? const Value.absent()
          : Value(faceColorFeature),
      selfCondition: selfCondition == null && nullToAbsent
          ? const Value.absent()
          : Value(selfCondition),
      bodyTemperatureC: bodyTemperatureC == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyTemperatureC),
      temperatureSource: Value(temperatureSource),
      reportText: reportText == null && nullToAbsent
          ? const Value.absent()
          : Value(reportText),
      aiMode: aiMode == null && nullToAbsent
          ? const Value.absent()
          : Value(aiMode),
    );
  }

  factory HealthRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HealthRecord(
      id: serializer.fromJson<String>(json['id']),
      measuredAt: serializer.fromJson<DateTime>(json['measuredAt']),
      elapsedMicros: serializer.fromJson<int>(json['elapsedMicros']),
      faceDetected: serializer.fromJson<bool>(json['faceDetected']),
      quality: $HealthRecordsTable.$converterquality.fromJson(
        serializer.fromJson<String>(json['quality']),
      ),
      estimatedHeartRateBpm: serializer.fromJson<double?>(
        json['estimatedHeartRateBpm'],
      ),
      heartRateSource: $HealthRecordsTable.$converterheartRateSource.fromJson(
        serializer.fromJson<String>(json['heartRateSource']),
      ),
      faceColorFeature: serializer.fromJson<double?>(json['faceColorFeature']),
      selfCondition: serializer.fromJson<int?>(json['selfCondition']),
      bodyTemperatureC: serializer.fromJson<double?>(json['bodyTemperatureC']),
      temperatureSource: $HealthRecordsTable.$convertertemperatureSource
          .fromJson(serializer.fromJson<String>(json['temperatureSource'])),
      reportText: serializer.fromJson<String?>(json['reportText']),
      aiMode: $HealthRecordsTable.$converteraiModen.fromJson(
        serializer.fromJson<String?>(json['aiMode']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'measuredAt': serializer.toJson<DateTime>(measuredAt),
      'elapsedMicros': serializer.toJson<int>(elapsedMicros),
      'faceDetected': serializer.toJson<bool>(faceDetected),
      'quality': serializer.toJson<String>(
        $HealthRecordsTable.$converterquality.toJson(quality),
      ),
      'estimatedHeartRateBpm': serializer.toJson<double?>(
        estimatedHeartRateBpm,
      ),
      'heartRateSource': serializer.toJson<String>(
        $HealthRecordsTable.$converterheartRateSource.toJson(heartRateSource),
      ),
      'faceColorFeature': serializer.toJson<double?>(faceColorFeature),
      'selfCondition': serializer.toJson<int?>(selfCondition),
      'bodyTemperatureC': serializer.toJson<double?>(bodyTemperatureC),
      'temperatureSource': serializer.toJson<String>(
        $HealthRecordsTable.$convertertemperatureSource.toJson(
          temperatureSource,
        ),
      ),
      'reportText': serializer.toJson<String?>(reportText),
      'aiMode': serializer.toJson<String?>(
        $HealthRecordsTable.$converteraiModen.toJson(aiMode),
      ),
    };
  }

  HealthRecord copyWith({
    String? id,
    DateTime? measuredAt,
    int? elapsedMicros,
    bool? faceDetected,
    MeasurementQuality? quality,
    Value<double?> estimatedHeartRateBpm = const Value.absent(),
    HeartRateSource? heartRateSource,
    Value<double?> faceColorFeature = const Value.absent(),
    Value<int?> selfCondition = const Value.absent(),
    Value<double?> bodyTemperatureC = const Value.absent(),
    TemperatureSource? temperatureSource,
    Value<String?> reportText = const Value.absent(),
    Value<ReportMode?> aiMode = const Value.absent(),
  }) => HealthRecord(
    id: id ?? this.id,
    measuredAt: measuredAt ?? this.measuredAt,
    elapsedMicros: elapsedMicros ?? this.elapsedMicros,
    faceDetected: faceDetected ?? this.faceDetected,
    quality: quality ?? this.quality,
    estimatedHeartRateBpm: estimatedHeartRateBpm.present
        ? estimatedHeartRateBpm.value
        : this.estimatedHeartRateBpm,
    heartRateSource: heartRateSource ?? this.heartRateSource,
    faceColorFeature: faceColorFeature.present
        ? faceColorFeature.value
        : this.faceColorFeature,
    selfCondition: selfCondition.present
        ? selfCondition.value
        : this.selfCondition,
    bodyTemperatureC: bodyTemperatureC.present
        ? bodyTemperatureC.value
        : this.bodyTemperatureC,
    temperatureSource: temperatureSource ?? this.temperatureSource,
    reportText: reportText.present ? reportText.value : this.reportText,
    aiMode: aiMode.present ? aiMode.value : this.aiMode,
  );
  HealthRecord copyWithCompanion(HealthRecordsCompanion data) {
    return HealthRecord(
      id: data.id.present ? data.id.value : this.id,
      measuredAt: data.measuredAt.present
          ? data.measuredAt.value
          : this.measuredAt,
      elapsedMicros: data.elapsedMicros.present
          ? data.elapsedMicros.value
          : this.elapsedMicros,
      faceDetected: data.faceDetected.present
          ? data.faceDetected.value
          : this.faceDetected,
      quality: data.quality.present ? data.quality.value : this.quality,
      estimatedHeartRateBpm: data.estimatedHeartRateBpm.present
          ? data.estimatedHeartRateBpm.value
          : this.estimatedHeartRateBpm,
      heartRateSource: data.heartRateSource.present
          ? data.heartRateSource.value
          : this.heartRateSource,
      faceColorFeature: data.faceColorFeature.present
          ? data.faceColorFeature.value
          : this.faceColorFeature,
      selfCondition: data.selfCondition.present
          ? data.selfCondition.value
          : this.selfCondition,
      bodyTemperatureC: data.bodyTemperatureC.present
          ? data.bodyTemperatureC.value
          : this.bodyTemperatureC,
      temperatureSource: data.temperatureSource.present
          ? data.temperatureSource.value
          : this.temperatureSource,
      reportText: data.reportText.present
          ? data.reportText.value
          : this.reportText,
      aiMode: data.aiMode.present ? data.aiMode.value : this.aiMode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HealthRecord(')
          ..write('id: $id, ')
          ..write('measuredAt: $measuredAt, ')
          ..write('elapsedMicros: $elapsedMicros, ')
          ..write('faceDetected: $faceDetected, ')
          ..write('quality: $quality, ')
          ..write('estimatedHeartRateBpm: $estimatedHeartRateBpm, ')
          ..write('heartRateSource: $heartRateSource, ')
          ..write('faceColorFeature: $faceColorFeature, ')
          ..write('selfCondition: $selfCondition, ')
          ..write('bodyTemperatureC: $bodyTemperatureC, ')
          ..write('temperatureSource: $temperatureSource, ')
          ..write('reportText: $reportText, ')
          ..write('aiMode: $aiMode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    measuredAt,
    elapsedMicros,
    faceDetected,
    quality,
    estimatedHeartRateBpm,
    heartRateSource,
    faceColorFeature,
    selfCondition,
    bodyTemperatureC,
    temperatureSource,
    reportText,
    aiMode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HealthRecord &&
          other.id == this.id &&
          other.measuredAt == this.measuredAt &&
          other.elapsedMicros == this.elapsedMicros &&
          other.faceDetected == this.faceDetected &&
          other.quality == this.quality &&
          other.estimatedHeartRateBpm == this.estimatedHeartRateBpm &&
          other.heartRateSource == this.heartRateSource &&
          other.faceColorFeature == this.faceColorFeature &&
          other.selfCondition == this.selfCondition &&
          other.bodyTemperatureC == this.bodyTemperatureC &&
          other.temperatureSource == this.temperatureSource &&
          other.reportText == this.reportText &&
          other.aiMode == this.aiMode);
}

class HealthRecordsCompanion extends UpdateCompanion<HealthRecord> {
  final Value<String> id;
  final Value<DateTime> measuredAt;
  final Value<int> elapsedMicros;
  final Value<bool> faceDetected;
  final Value<MeasurementQuality> quality;
  final Value<double?> estimatedHeartRateBpm;
  final Value<HeartRateSource> heartRateSource;
  final Value<double?> faceColorFeature;
  final Value<int?> selfCondition;
  final Value<double?> bodyTemperatureC;
  final Value<TemperatureSource> temperatureSource;
  final Value<String?> reportText;
  final Value<ReportMode?> aiMode;
  final Value<int> rowid;
  const HealthRecordsCompanion({
    this.id = const Value.absent(),
    this.measuredAt = const Value.absent(),
    this.elapsedMicros = const Value.absent(),
    this.faceDetected = const Value.absent(),
    this.quality = const Value.absent(),
    this.estimatedHeartRateBpm = const Value.absent(),
    this.heartRateSource = const Value.absent(),
    this.faceColorFeature = const Value.absent(),
    this.selfCondition = const Value.absent(),
    this.bodyTemperatureC = const Value.absent(),
    this.temperatureSource = const Value.absent(),
    this.reportText = const Value.absent(),
    this.aiMode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HealthRecordsCompanion.insert({
    required String id,
    required DateTime measuredAt,
    required int elapsedMicros,
    required bool faceDetected,
    required MeasurementQuality quality,
    this.estimatedHeartRateBpm = const Value.absent(),
    required HeartRateSource heartRateSource,
    this.faceColorFeature = const Value.absent(),
    this.selfCondition = const Value.absent(),
    this.bodyTemperatureC = const Value.absent(),
    required TemperatureSource temperatureSource,
    this.reportText = const Value.absent(),
    this.aiMode = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       measuredAt = Value(measuredAt),
       elapsedMicros = Value(elapsedMicros),
       faceDetected = Value(faceDetected),
       quality = Value(quality),
       heartRateSource = Value(heartRateSource),
       temperatureSource = Value(temperatureSource);
  static Insertable<HealthRecord> custom({
    Expression<String>? id,
    Expression<int>? measuredAt,
    Expression<int>? elapsedMicros,
    Expression<bool>? faceDetected,
    Expression<String>? quality,
    Expression<double>? estimatedHeartRateBpm,
    Expression<String>? heartRateSource,
    Expression<double>? faceColorFeature,
    Expression<int>? selfCondition,
    Expression<double>? bodyTemperatureC,
    Expression<String>? temperatureSource,
    Expression<String>? reportText,
    Expression<String>? aiMode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (measuredAt != null) 'measured_at': measuredAt,
      if (elapsedMicros != null) 'elapsed_micros': elapsedMicros,
      if (faceDetected != null) 'face_detected': faceDetected,
      if (quality != null) 'quality': quality,
      if (estimatedHeartRateBpm != null)
        'estimated_heart_rate_bpm': estimatedHeartRateBpm,
      if (heartRateSource != null) 'heart_rate_source': heartRateSource,
      if (faceColorFeature != null) 'face_color_feature': faceColorFeature,
      if (selfCondition != null) 'self_condition': selfCondition,
      if (bodyTemperatureC != null) 'body_temperature_c': bodyTemperatureC,
      if (temperatureSource != null) 'temperature_source': temperatureSource,
      if (reportText != null) 'report_text': reportText,
      if (aiMode != null) 'ai_mode': aiMode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HealthRecordsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? measuredAt,
    Value<int>? elapsedMicros,
    Value<bool>? faceDetected,
    Value<MeasurementQuality>? quality,
    Value<double?>? estimatedHeartRateBpm,
    Value<HeartRateSource>? heartRateSource,
    Value<double?>? faceColorFeature,
    Value<int?>? selfCondition,
    Value<double?>? bodyTemperatureC,
    Value<TemperatureSource>? temperatureSource,
    Value<String?>? reportText,
    Value<ReportMode?>? aiMode,
    Value<int>? rowid,
  }) {
    return HealthRecordsCompanion(
      id: id ?? this.id,
      measuredAt: measuredAt ?? this.measuredAt,
      elapsedMicros: elapsedMicros ?? this.elapsedMicros,
      faceDetected: faceDetected ?? this.faceDetected,
      quality: quality ?? this.quality,
      estimatedHeartRateBpm:
          estimatedHeartRateBpm ?? this.estimatedHeartRateBpm,
      heartRateSource: heartRateSource ?? this.heartRateSource,
      faceColorFeature: faceColorFeature ?? this.faceColorFeature,
      selfCondition: selfCondition ?? this.selfCondition,
      bodyTemperatureC: bodyTemperatureC ?? this.bodyTemperatureC,
      temperatureSource: temperatureSource ?? this.temperatureSource,
      reportText: reportText ?? this.reportText,
      aiMode: aiMode ?? this.aiMode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (measuredAt.present) {
      map['measured_at'] = Variable<int>(
        $HealthRecordsTable.$convertermeasuredAt.toSql(measuredAt.value),
      );
    }
    if (elapsedMicros.present) {
      map['elapsed_micros'] = Variable<int>(elapsedMicros.value);
    }
    if (faceDetected.present) {
      map['face_detected'] = Variable<bool>(faceDetected.value);
    }
    if (quality.present) {
      map['quality'] = Variable<String>(
        $HealthRecordsTable.$converterquality.toSql(quality.value),
      );
    }
    if (estimatedHeartRateBpm.present) {
      map['estimated_heart_rate_bpm'] = Variable<double>(
        estimatedHeartRateBpm.value,
      );
    }
    if (heartRateSource.present) {
      map['heart_rate_source'] = Variable<String>(
        $HealthRecordsTable.$converterheartRateSource.toSql(
          heartRateSource.value,
        ),
      );
    }
    if (faceColorFeature.present) {
      map['face_color_feature'] = Variable<double>(faceColorFeature.value);
    }
    if (selfCondition.present) {
      map['self_condition'] = Variable<int>(selfCondition.value);
    }
    if (bodyTemperatureC.present) {
      map['body_temperature_c'] = Variable<double>(bodyTemperatureC.value);
    }
    if (temperatureSource.present) {
      map['temperature_source'] = Variable<String>(
        $HealthRecordsTable.$convertertemperatureSource.toSql(
          temperatureSource.value,
        ),
      );
    }
    if (reportText.present) {
      map['report_text'] = Variable<String>(reportText.value);
    }
    if (aiMode.present) {
      map['ai_mode'] = Variable<String>(
        $HealthRecordsTable.$converteraiModen.toSql(aiMode.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HealthRecordsCompanion(')
          ..write('id: $id, ')
          ..write('measuredAt: $measuredAt, ')
          ..write('elapsedMicros: $elapsedMicros, ')
          ..write('faceDetected: $faceDetected, ')
          ..write('quality: $quality, ')
          ..write('estimatedHeartRateBpm: $estimatedHeartRateBpm, ')
          ..write('heartRateSource: $heartRateSource, ')
          ..write('faceColorFeature: $faceColorFeature, ')
          ..write('selfCondition: $selfCondition, ')
          ..write('bodyTemperatureC: $bodyTemperatureC, ')
          ..write('temperatureSource: $temperatureSource, ')
          ..write('reportText: $reportText, ')
          ..write('aiMode: $aiMode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReminderPreferencesTable extends ReminderPreferences
    with TableInfo<$ReminderPreferencesTable, ReminderPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReminderPreferencesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
  );
  static const VerificationMeta _hourMeta = const VerificationMeta('hour');
  @override
  late final GeneratedColumn<int> hour = GeneratedColumn<int>(
    'hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minuteMeta = const VerificationMeta('minute');
  @override
  late final GeneratedColumn<int> minute = GeneratedColumn<int>(
    'minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, enabled, hour, minute];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminder_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReminderPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    } else if (isInserting) {
      context.missing(_enabledMeta);
    }
    if (data.containsKey('hour')) {
      context.handle(
        _hourMeta,
        hour.isAcceptableOrUnknown(data['hour']!, _hourMeta),
      );
    } else if (isInserting) {
      context.missing(_hourMeta);
    }
    if (data.containsKey('minute')) {
      context.handle(
        _minuteMeta,
        minute.isAcceptableOrUnknown(data['minute']!, _minuteMeta),
      );
    } else if (isInserting) {
      context.missing(_minuteMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReminderPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReminderPreference(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      hour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hour'],
      )!,
      minute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minute'],
      )!,
    );
  }

  @override
  $ReminderPreferencesTable createAlias(String alias) {
    return $ReminderPreferencesTable(attachedDatabase, alias);
  }
}

class ReminderPreference extends DataClass
    implements Insertable<ReminderPreference> {
  final int id;
  final bool enabled;
  final int hour;
  final int minute;
  const ReminderPreference({
    required this.id,
    required this.enabled,
    required this.hour,
    required this.minute,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['enabled'] = Variable<bool>(enabled);
    map['hour'] = Variable<int>(hour);
    map['minute'] = Variable<int>(minute);
    return map;
  }

  ReminderPreferencesCompanion toCompanion(bool nullToAbsent) {
    return ReminderPreferencesCompanion(
      id: Value(id),
      enabled: Value(enabled),
      hour: Value(hour),
      minute: Value(minute),
    );
  }

  factory ReminderPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReminderPreference(
      id: serializer.fromJson<int>(json['id']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      hour: serializer.fromJson<int>(json['hour']),
      minute: serializer.fromJson<int>(json['minute']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'enabled': serializer.toJson<bool>(enabled),
      'hour': serializer.toJson<int>(hour),
      'minute': serializer.toJson<int>(minute),
    };
  }

  ReminderPreference copyWith({
    int? id,
    bool? enabled,
    int? hour,
    int? minute,
  }) => ReminderPreference(
    id: id ?? this.id,
    enabled: enabled ?? this.enabled,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
  );
  ReminderPreference copyWithCompanion(ReminderPreferencesCompanion data) {
    return ReminderPreference(
      id: data.id.present ? data.id.value : this.id,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      hour: data.hour.present ? data.hour.value : this.hour,
      minute: data.minute.present ? data.minute.value : this.minute,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReminderPreference(')
          ..write('id: $id, ')
          ..write('enabled: $enabled, ')
          ..write('hour: $hour, ')
          ..write('minute: $minute')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, enabled, hour, minute);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReminderPreference &&
          other.id == this.id &&
          other.enabled == this.enabled &&
          other.hour == this.hour &&
          other.minute == this.minute);
}

class ReminderPreferencesCompanion extends UpdateCompanion<ReminderPreference> {
  final Value<int> id;
  final Value<bool> enabled;
  final Value<int> hour;
  final Value<int> minute;
  const ReminderPreferencesCompanion({
    this.id = const Value.absent(),
    this.enabled = const Value.absent(),
    this.hour = const Value.absent(),
    this.minute = const Value.absent(),
  });
  ReminderPreferencesCompanion.insert({
    this.id = const Value.absent(),
    required bool enabled,
    required int hour,
    required int minute,
  }) : enabled = Value(enabled),
       hour = Value(hour),
       minute = Value(minute);
  static Insertable<ReminderPreference> custom({
    Expression<int>? id,
    Expression<bool>? enabled,
    Expression<int>? hour,
    Expression<int>? minute,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (enabled != null) 'enabled': enabled,
      if (hour != null) 'hour': hour,
      if (minute != null) 'minute': minute,
    });
  }

  ReminderPreferencesCompanion copyWith({
    Value<int>? id,
    Value<bool>? enabled,
    Value<int>? hour,
    Value<int>? minute,
  }) {
    return ReminderPreferencesCompanion(
      id: id ?? this.id,
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (hour.present) {
      map['hour'] = Variable<int>(hour.value);
    }
    if (minute.present) {
      map['minute'] = Variable<int>(minute.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReminderPreferencesCompanion(')
          ..write('id: $id, ')
          ..write('enabled: $enabled, ')
          ..write('hour: $hour, ')
          ..write('minute: $minute')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $OnboardingCompletionsTable onboardingCompletions =
      $OnboardingCompletionsTable(this);
  late final $HealthRecordsTable healthRecords = $HealthRecordsTable(this);
  late final $ReminderPreferencesTable reminderPreferences =
      $ReminderPreferencesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    onboardingCompletions,
    healthRecords,
    reminderPreferences,
  ];
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
typedef $$HealthRecordsTableCreateCompanionBuilder =
    HealthRecordsCompanion Function({
      required String id,
      required DateTime measuredAt,
      required int elapsedMicros,
      required bool faceDetected,
      required MeasurementQuality quality,
      Value<double?> estimatedHeartRateBpm,
      required HeartRateSource heartRateSource,
      Value<double?> faceColorFeature,
      Value<int?> selfCondition,
      Value<double?> bodyTemperatureC,
      required TemperatureSource temperatureSource,
      Value<String?> reportText,
      Value<ReportMode?> aiMode,
      Value<int> rowid,
    });
typedef $$HealthRecordsTableUpdateCompanionBuilder =
    HealthRecordsCompanion Function({
      Value<String> id,
      Value<DateTime> measuredAt,
      Value<int> elapsedMicros,
      Value<bool> faceDetected,
      Value<MeasurementQuality> quality,
      Value<double?> estimatedHeartRateBpm,
      Value<HeartRateSource> heartRateSource,
      Value<double?> faceColorFeature,
      Value<int?> selfCondition,
      Value<double?> bodyTemperatureC,
      Value<TemperatureSource> temperatureSource,
      Value<String?> reportText,
      Value<ReportMode?> aiMode,
      Value<int> rowid,
    });

class $$HealthRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $HealthRecordsTable> {
  $$HealthRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get measuredAt =>
      $composableBuilder(
        column: $table.measuredAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get elapsedMicros => $composableBuilder(
    column: $table.elapsedMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get faceDetected => $composableBuilder(
    column: $table.faceDetected,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MeasurementQuality, MeasurementQuality, String>
  get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get estimatedHeartRateBpm => $composableBuilder(
    column: $table.estimatedHeartRateBpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<HeartRateSource, HeartRateSource, String>
  get heartRateSource => $composableBuilder(
    column: $table.heartRateSource,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get faceColorFeature => $composableBuilder(
    column: $table.faceColorFeature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get selfCondition => $composableBuilder(
    column: $table.selfCondition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bodyTemperatureC => $composableBuilder(
    column: $table.bodyTemperatureC,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TemperatureSource, TemperatureSource, String>
  get temperatureSource => $composableBuilder(
    column: $table.temperatureSource,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get reportText => $composableBuilder(
    column: $table.reportText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ReportMode?, ReportMode, String> get aiMode =>
      $composableBuilder(
        column: $table.aiMode,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$HealthRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $HealthRecordsTable> {
  $$HealthRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get measuredAt => $composableBuilder(
    column: $table.measuredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get elapsedMicros => $composableBuilder(
    column: $table.elapsedMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get faceDetected => $composableBuilder(
    column: $table.faceDetected,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get estimatedHeartRateBpm => $composableBuilder(
    column: $table.estimatedHeartRateBpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get heartRateSource => $composableBuilder(
    column: $table.heartRateSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get faceColorFeature => $composableBuilder(
    column: $table.faceColorFeature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get selfCondition => $composableBuilder(
    column: $table.selfCondition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bodyTemperatureC => $composableBuilder(
    column: $table.bodyTemperatureC,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get temperatureSource => $composableBuilder(
    column: $table.temperatureSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reportText => $composableBuilder(
    column: $table.reportText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aiMode => $composableBuilder(
    column: $table.aiMode,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HealthRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HealthRecordsTable> {
  $$HealthRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get measuredAt =>
      $composableBuilder(
        column: $table.measuredAt,
        builder: (column) => column,
      );

  GeneratedColumn<int> get elapsedMicros => $composableBuilder(
    column: $table.elapsedMicros,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get faceDetected => $composableBuilder(
    column: $table.faceDetected,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<MeasurementQuality, String> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumn<double> get estimatedHeartRateBpm => $composableBuilder(
    column: $table.estimatedHeartRateBpm,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<HeartRateSource, String>
  get heartRateSource => $composableBuilder(
    column: $table.heartRateSource,
    builder: (column) => column,
  );

  GeneratedColumn<double> get faceColorFeature => $composableBuilder(
    column: $table.faceColorFeature,
    builder: (column) => column,
  );

  GeneratedColumn<int> get selfCondition => $composableBuilder(
    column: $table.selfCondition,
    builder: (column) => column,
  );

  GeneratedColumn<double> get bodyTemperatureC => $composableBuilder(
    column: $table.bodyTemperatureC,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<TemperatureSource, String>
  get temperatureSource => $composableBuilder(
    column: $table.temperatureSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reportText => $composableBuilder(
    column: $table.reportText,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<ReportMode?, String> get aiMode =>
      $composableBuilder(column: $table.aiMode, builder: (column) => column);
}

class $$HealthRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HealthRecordsTable,
          HealthRecord,
          $$HealthRecordsTableFilterComposer,
          $$HealthRecordsTableOrderingComposer,
          $$HealthRecordsTableAnnotationComposer,
          $$HealthRecordsTableCreateCompanionBuilder,
          $$HealthRecordsTableUpdateCompanionBuilder,
          (
            HealthRecord,
            BaseReferences<_$AppDatabase, $HealthRecordsTable, HealthRecord>,
          ),
          HealthRecord,
          PrefetchHooks Function()
        > {
  $$HealthRecordsTableTableManager(_$AppDatabase db, $HealthRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HealthRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HealthRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HealthRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> measuredAt = const Value.absent(),
                Value<int> elapsedMicros = const Value.absent(),
                Value<bool> faceDetected = const Value.absent(),
                Value<MeasurementQuality> quality = const Value.absent(),
                Value<double?> estimatedHeartRateBpm = const Value.absent(),
                Value<HeartRateSource> heartRateSource = const Value.absent(),
                Value<double?> faceColorFeature = const Value.absent(),
                Value<int?> selfCondition = const Value.absent(),
                Value<double?> bodyTemperatureC = const Value.absent(),
                Value<TemperatureSource> temperatureSource =
                    const Value.absent(),
                Value<String?> reportText = const Value.absent(),
                Value<ReportMode?> aiMode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HealthRecordsCompanion(
                id: id,
                measuredAt: measuredAt,
                elapsedMicros: elapsedMicros,
                faceDetected: faceDetected,
                quality: quality,
                estimatedHeartRateBpm: estimatedHeartRateBpm,
                heartRateSource: heartRateSource,
                faceColorFeature: faceColorFeature,
                selfCondition: selfCondition,
                bodyTemperatureC: bodyTemperatureC,
                temperatureSource: temperatureSource,
                reportText: reportText,
                aiMode: aiMode,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime measuredAt,
                required int elapsedMicros,
                required bool faceDetected,
                required MeasurementQuality quality,
                Value<double?> estimatedHeartRateBpm = const Value.absent(),
                required HeartRateSource heartRateSource,
                Value<double?> faceColorFeature = const Value.absent(),
                Value<int?> selfCondition = const Value.absent(),
                Value<double?> bodyTemperatureC = const Value.absent(),
                required TemperatureSource temperatureSource,
                Value<String?> reportText = const Value.absent(),
                Value<ReportMode?> aiMode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HealthRecordsCompanion.insert(
                id: id,
                measuredAt: measuredAt,
                elapsedMicros: elapsedMicros,
                faceDetected: faceDetected,
                quality: quality,
                estimatedHeartRateBpm: estimatedHeartRateBpm,
                heartRateSource: heartRateSource,
                faceColorFeature: faceColorFeature,
                selfCondition: selfCondition,
                bodyTemperatureC: bodyTemperatureC,
                temperatureSource: temperatureSource,
                reportText: reportText,
                aiMode: aiMode,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HealthRecordsTable, HealthRecord>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $HealthRecordsTable,
                    HealthRecord
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HealthRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HealthRecordsTable,
      HealthRecord,
      $$HealthRecordsTableFilterComposer,
      $$HealthRecordsTableOrderingComposer,
      $$HealthRecordsTableAnnotationComposer,
      $$HealthRecordsTableCreateCompanionBuilder,
      $$HealthRecordsTableUpdateCompanionBuilder,
      (
        HealthRecord,
        BaseReferences<_$AppDatabase, $HealthRecordsTable, HealthRecord>,
      ),
      HealthRecord,
      PrefetchHooks Function()
    >;
typedef $$ReminderPreferencesTableCreateCompanionBuilder =
    ReminderPreferencesCompanion Function({
      Value<int> id,
      required bool enabled,
      required int hour,
      required int minute,
    });
typedef $$ReminderPreferencesTableUpdateCompanionBuilder =
    ReminderPreferencesCompanion Function({
      Value<int> id,
      Value<bool> enabled,
      Value<int> hour,
      Value<int> minute,
    });

class $$ReminderPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $ReminderPreferencesTable> {
  $$ReminderPreferencesTableFilterComposer({
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

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hour => $composableBuilder(
    column: $table.hour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReminderPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReminderPreferencesTable> {
  $$ReminderPreferencesTableOrderingComposer({
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

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hour => $composableBuilder(
    column: $table.hour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReminderPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReminderPreferencesTable> {
  $$ReminderPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get hour =>
      $composableBuilder(column: $table.hour, builder: (column) => column);

  GeneratedColumn<int> get minute =>
      $composableBuilder(column: $table.minute, builder: (column) => column);
}

class $$ReminderPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReminderPreferencesTable,
          ReminderPreference,
          $$ReminderPreferencesTableFilterComposer,
          $$ReminderPreferencesTableOrderingComposer,
          $$ReminderPreferencesTableAnnotationComposer,
          $$ReminderPreferencesTableCreateCompanionBuilder,
          $$ReminderPreferencesTableUpdateCompanionBuilder,
          (
            ReminderPreference,
            BaseReferences<
              _$AppDatabase,
              $ReminderPreferencesTable,
              ReminderPreference
            >,
          ),
          ReminderPreference,
          PrefetchHooks Function()
        > {
  $$ReminderPreferencesTableTableManager(
    _$AppDatabase db,
    $ReminderPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReminderPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReminderPreferencesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ReminderPreferencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> hour = const Value.absent(),
                Value<int> minute = const Value.absent(),
              }) => ReminderPreferencesCompanion(
                id: id,
                enabled: enabled,
                hour: hour,
                minute: minute,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required bool enabled,
                required int hour,
                required int minute,
              }) => ReminderPreferencesCompanion.insert(
                id: id,
                enabled: enabled,
                hour: hour,
                minute: minute,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReminderPreferencesTable, ReminderPreference>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $ReminderPreferencesTable,
                    ReminderPreference
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReminderPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReminderPreferencesTable,
      ReminderPreference,
      $$ReminderPreferencesTableFilterComposer,
      $$ReminderPreferencesTableOrderingComposer,
      $$ReminderPreferencesTableAnnotationComposer,
      $$ReminderPreferencesTableCreateCompanionBuilder,
      $$ReminderPreferencesTableUpdateCompanionBuilder,
      (
        ReminderPreference,
        BaseReferences<
          _$AppDatabase,
          $ReminderPreferencesTable,
          ReminderPreference
        >,
      ),
      ReminderPreference,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$OnboardingCompletionsTableTableManager get onboardingCompletions =>
      $$OnboardingCompletionsTableTableManager(_db, _db.onboardingCompletions);
  $$HealthRecordsTableTableManager get healthRecords =>
      $$HealthRecordsTableTableManager(_db, _db.healthRecords);
  $$ReminderPreferencesTableTableManager get reminderPreferences =>
      $$ReminderPreferencesTableTableManager(_db, _db.reminderPreferences);
}
