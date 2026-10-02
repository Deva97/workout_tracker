import 'package:flutter/foundation.dart';
import '../models/daily_record.dart';
import '../models/daily_workout_entry.dart';
import 'auth_repository.dart' show SyncState;

abstract class WorkoutRepository {
  Future<List<DailyWorkoutEntry>> getTodaysWorkoutEntries([DateTime? date]);
  Future<List<DailyRecord>> getDailyRecords();
  Future<List<DailyRecord>> getWeeklyDailyRecords([DateTime? referenceDate]);
  Future<DailyRecord> addDailyRecord(DailyRecord record);
  Future<DailyRecord> editDailyRecord(DailyRecord record);
  Future<void> deleteDailyRecord(String id);
  Future<List<DailyRecord>> queryExerciseHistory(String workoutId, {int daysLimit = 30});
  Future<void> syncDailyRecordsFromDrive();
  Future<void> syncDailyRecordsToDrive(List<DailyRecord> todayRecords);
  List<DailyWorkoutEntry> getCachedTodaysWorkoutEntries([DateTime? date]);
  Future<SyncState> manualSyncToExcel();
  ValueListenable<SyncState> get syncStateListenable;
}
