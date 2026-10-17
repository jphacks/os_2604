/// B's normalized analysis input, independent of the camera's shared models.
///
/// Each element represents one record. The repository is responsible for
/// deduplicating records before calling [calculateHistoryBaseline].
typedef BaselineObservation = ({
  DateTime measuredAt,
  bool isValid,
  int? selfCondition,
});

/// Descriptive baseline values, without medical interpretation.
class HistoryBaseline {
  const HistoryBaseline({
    required this.validRecordCount,
    required this.selfConditionCount,
    required this.selfConditionMedian,
  });

  final int validRecordCount;

  /// Number of valid records with a self-reported value in the range 1..5.
  final int selfConditionCount;

  /// Null until at least three eligible self-reported values are available.
  final double? selfConditionMedian;

  bool get isAccumulating => selfConditionMedian == null;
}

/// Summarizes valid records from the seven local calendar days before today.
///
/// [referenceDate] and observation timestamps are converted to device local
/// time. The interval includes midnight seven days ago and excludes midnight
/// today. Calendar construction preserves boundaries across daylight changes.
/// Records are counted individually; null and out-of-range values are omitted
/// only from the self-condition calculation. The input is never modified.
HistoryBaseline calculateHistoryBaseline(
  Iterable<BaselineObservation> observations, {
  required DateTime referenceDate,
}) {
  final localReference = referenceDate.toLocal();
  final today = DateTime(
    localReference.year,
    localReference.month,
    localReference.day,
  );
  final start = DateTime(today.year, today.month, today.day - 7);
  var validRecordCount = 0;
  final selfConditions = <int>[];

  for (final observation in observations) {
    final measuredAt = observation.measuredAt.toLocal();
    if (!observation.isValid ||
        measuredAt.isBefore(start) ||
        !measuredAt.isBefore(today)) {
      continue;
    }
    validRecordCount++;
    final selfCondition = observation.selfCondition;
    if (selfCondition != null && selfCondition >= 1 && selfCondition <= 5) {
      selfConditions.add(selfCondition);
    }
  }

  double? median;
  if (validRecordCount >= 3 && selfConditions.length >= 3) {
    selfConditions.sort();
    final middle = selfConditions.length ~/ 2;
    median = selfConditions.length.isOdd
        ? selfConditions[middle].toDouble()
        : (selfConditions[middle - 1] + selfConditions[middle]) / 2;
  }

  return HistoryBaseline(
    validRecordCount: validRecordCount,
    selfConditionCount: selfConditions.length,
    selfConditionMedian: median,
  );
}
