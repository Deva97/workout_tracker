import '../models/weight_record.dart';

abstract class WeightRepository {
  /// Checks whether Body_weight.xlsx exists in Google Drive
  Future<bool> checkWeightSheetExists();

  /// Creates Body_weight.xlsx with schema headers in Google Drive
  Future<void> createWeightSheet();

  /// Loads all weight records (from local cache and Drive)
  Future<List<WeightRecord>> getWeightRecords();

  /// Retrieves today's weight record if logged, or null
  Future<WeightRecord?> getTodayWeightRecord();

  /// Saves or updates a weight record locally and syncs to Drive
  Future<void> saveWeightRecord(WeightRecord record);

  /// Deletes a weight record by ID locally and syncs to Drive
  Future<void> deleteWeightRecord(String id);
}
