import '../models/daily_record.dart';
import '../models/daily_workout_entry.dart';

abstract class WorkoutRepository {
  Future<List<DailyWorkoutEntry>> getTodaysWorkoutEntries([DateTime? date]);
  Future<List<DailyRecord>> getDailyRecords();
  Future<DailyRecord> addDailyRecord(DailyRecord record);
  Future<DailyRecord> editDailyRecord(DailyRecord record);
  Future<void> deleteDailyRecord(String id);
  Future<List<DailyRecord>> queryExerciseHistory(String workoutId, {int daysLimit = 30});
  Future<void> syncDailyRecordsFromDrive();
  Future<void> syncDailyRecordsToDrive(List<DailyRecord> todayRecords);
  List<DailyWorkoutEntry> getCachedTodaysWorkoutEntries([DateTime? date]);
}
