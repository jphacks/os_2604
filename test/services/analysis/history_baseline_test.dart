import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/services/analysis/history_baseline.dart';

BaselineObservation observation(
  DateTime measuredAt, {
  bool isValid = true,
  int? selfCondition = 3,
}) => (measuredAt: measuredAt, isValid: isValid, selfCondition: selfCondition);

void main() {
  final reference = DateTime(2026, 10, 17, 12);

  HistoryBaseline calculate(Iterable<BaselineObservation> records) =>
      calculateHistoryBaseline(records, referenceDate: reference);

  test(
    'includes seven-days-ago midnight but excludes today, future and older',
    () {
      final result = calculate([
        observation(DateTime(2026, 10, 10), selfCondition: 1),
        observation(DateTime(2026, 10, 12), selfCondition: 3),
        observation(
          DateTime(2026, 10, 16, 23, 59, 59, 999, 999),
          selfCondition: 5,
        ),
        observation(DateTime(2026, 10, 9, 23, 59, 59, 999, 999)),
        observation(DateTime(2026, 10, 17)),
        observation(DateTime(2026, 10, 18)),
        observation(DateTime(2026, 10, 12), isValid: false),
      ]);
      expect(result.validRecordCount, 3);
      expect(result.selfConditionCount, 3);
      expect(result.selfConditionMedian, 3.0);
      expect(result.isAccumulating, isFalse);
    },
  );

  test('empty or fewer than three valid records accumulates', () {
    expect(calculate([]).validRecordCount, 0);
    expect(calculate([]).isAccumulating, isTrue);
    final result = calculate([
      observation(DateTime(2026, 10, 11)),
      observation(DateTime(2026, 10, 12)),
    ]);
    expect(result.validRecordCount, 2);
    expect(result.selfConditionMedian, isNull);
    expect(result.isAccumulating, isTrue);
  });

  test(
    'null and out-of-range values count as records but not self-reports',
    () {
      final result = calculate([
        for (final value in <int?>[null, 0, -1, 6, 1, 5])
          observation(DateTime(2026, 10, 11), selfCondition: value),
      ]);
      expect(result.validRecordCount, 6);
      expect(result.selfConditionCount, 2);
      expect(result.selfConditionMedian, isNull);
      expect(result.isAccumulating, isTrue);
    },
  );

  test('odd median ignores missing values and does not mutate the input', () {
    final records = List<BaselineObservation>.unmodifiable([
      observation(DateTime(2026, 10, 11), selfCondition: 5),
      observation(DateTime(2026, 10, 12), selfCondition: null),
      observation(DateTime(2026, 10, 13), selfCondition: 1),
      observation(DateTime(2026, 10, 14), selfCondition: 4),
    ]);
    final original = List<BaselineObservation>.of(records);
    final result = calculate(records);
    expect(result.validRecordCount, 4);
    expect(result.selfConditionCount, 3);
    expect(result.selfConditionMedian, 4.0);
    expect(records, original);
  });

  test(
    'even median averages the middle pair and counts records on same day',
    () {
      final result = calculate([
        for (final value in [5, 1, 4, 1])
          observation(DateTime(2026, 10, 11), selfCondition: value),
      ]);
      expect(result.validRecordCount, 4);
      expect(result.selfConditionMedian, 2.5);
    },
  );

  test('calendar window crosses month and year boundaries', () {
    final result = calculateHistoryBaseline([
      observation(DateTime(2025, 12, 27)),
      observation(DateTime(2025, 12, 31)),
      observation(DateTime(2026, 1, 2)),
      observation(DateTime(2025, 12, 26, 23, 59, 59)),
      observation(DateTime(2026, 1, 3)),
    ], referenceDate: DateTime(2026, 1, 3, 15));
    expect(result.validRecordCount, 3);
    expect(result.selfConditionMedian, 3.0);
  });

  test('UTC timestamps use the same device-local calendar boundaries', () {
    final localReference = DateTime(2026, 10, 17, 12);
    final records = [
      observation(DateTime(2026, 10, 10).toUtc()),
      observation(DateTime(2026, 10, 11).toUtc()),
      observation(DateTime(2026, 10, 16, 23, 59).toUtc()),
      observation(DateTime(2026, 10, 17).toUtc()),
    ];
    final result = calculateHistoryBaseline(
      records,
      referenceDate: localReference.toUtc(),
    );
    expect(result.validRecordCount, 3);
    expect(result.selfConditionMedian, 3.0);
  });
}
