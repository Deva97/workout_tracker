import 'package:flutter/foundation.dart';

enum SyncState {
  synced,
  syncing,
  error,
}

class DriveSheetsStatus {
  final bool exerciseDbExists;
  final bool dailyRecordExists;

  const DriveSheetsStatus({
    required this.exerciseDbExists,
    required this.dailyRecordExists,
  });

  bool get allExist => exerciseDbExists && dailyRecordExists;
}

abstract class AuthRepository {
  Future<bool> isSignedIn();
  Future<dynamic> signIn();
  Future<void> signOut();
  Future<bool> initializeIfSignedIn();
  Future<DriveSheetsStatus> checkSheetsExistence();
  Future<void> createMissingSheets({
    required bool createExerciseDb,
    required bool createDailyRecord,
  });
  ValueNotifier<SyncState> get syncStateNotifier;
  Future<SyncState> manualSyncToExcel();
}
