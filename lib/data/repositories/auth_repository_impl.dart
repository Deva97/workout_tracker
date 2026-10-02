import 'package:flutter/foundation.dart';
import '../../domain/repositories/auth_repository.dart';
import '../services/google_drive_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final GoogleDriveService _driveService;

  AuthRepositoryImpl({GoogleDriveService? driveService})
      : _driveService = driveService ?? GoogleDriveService();

  @override
  Future<bool> isSignedIn() => _driveService.isSignedIn();

  @override
  Future<dynamic> signIn() => _driveService.signIn();

  @override
  Future<void> signOut() => _driveService.signOut();

  @override
  Future<bool> initializeIfSignedIn() => _driveService.initializeIfSignedIn();

  @override
  Future<DriveSheetsStatus> checkSheetsExistence() => _driveService.checkSheetsExistence();

  @override
  Future<void> createMissingSheets({
    required bool createExerciseDb,
    required bool createDailyRecord,
  }) =>
      _driveService.createMissingSheets(
        createExerciseDb: createExerciseDb,
        createDailyRecord: createDailyRecord,
      );

  @override
  ValueNotifier<SyncState> get syncStateNotifier => _driveService.syncStateNotifier;

  @override
  Future<SyncState> manualSyncToExcel() => _driveService.manualSyncToExcel();
}
