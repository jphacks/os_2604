import '../../models/health_check_result.dart';

abstract interface class HealthRecordStore {
  Future<void> insert(HealthCheckResult result);
  Future<bool> updateInputsAndReport(HealthCheckResult result);
  Future<List<HealthCheckResult>> loadAll();
  Stream<List<HealthCheckResult>> watchAll();
  Future<void> deleteOne(String id);
  Future<void> deleteAll();
}
