import 'package:flutter/foundation.dart';
import '../../domain/models/daily_record.dart';
import '../../domain/models/daily_workout_entry.dart';
import '../../domain/repositories/workout_repository.dart';
import '../services/google_drive_service.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  final GoogleDriveService _driveService;

  WorkoutRepositoryImpl({GoogleDriveService? driveService})
      : _driveService = driveService ?? GoogleDriveService();

  @override
  Future<List<DailyWorkoutEntry>> getTodaysWorkoutEntries([DateTime? date]) {
    return _driveService.getTodaysWorkoutEntries(date);
  }

  @override
  Future<List<DailyRecord>> getDailyRecords() {
    return _driveService.getDailyRecords();
  }

  @override
  Future<List<DailyRecord>> getWeeklyDailyRecords([DateTime? referenceDate]) {
    return _driveService.getWeeklyDailyRecords(referenceDate);
  }

  @override
  Future<DailyRecord> addDailyRecord(DailyRecord record) {
    return _driveService.addDailyRecordOptimistic(record);
  }

  @override
  Future<DailyRecord> editDailyRecord(DailyRecord record) {
    return _driveService.editDailyRecordOptimistic(record);
  }

  @override
  Future<void> deleteDailyRecord(String id) {
    return _driveService.deleteDailyRecordOptimistic(id);
  }

  @override
  Future<List<DailyRecord>> queryExerciseHistory(String workoutId, {int daysLimit = 30}) {
    return _driveService.queryExerciseHistory(workoutId, daysLimit: daysLimit);
  }

  @override
  Future<void> syncDailyRecordsFromDrive() {
    return _driveService.syncDailyRecordsFromDrive();
  }

  @override
  Future<void> syncDailyRecordsToDrive(List<DailyRecord> todayRecords) {
    return _driveService.syncDailyRecordsToDrive(todayRecords);
  }

  @override
  List<DailyWorkoutEntry> getCachedTodaysWorkoutEntries([DateTime? date]) {
    return _driveService.dbContext.getTodaysWorkoutEntries(date);
  }

  @override
  Future<SyncState> manualSyncToExcel() {
    return _driveService.manualSyncToExcel();
  }

  @override
  ValueListenable<SyncState> get syncStateListenable => _driveService.syncStateNotifier;
}
