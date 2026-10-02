import 'package:flutter/foundation.dart';
import '../repositories/auth_repository.dart';

class AuthAndSyncUseCase {
  final AuthRepository _authRepository;

  AuthAndSyncUseCase({
    required this._authRepository,
  });

  ValueNotifier<SyncState> get syncStateNotifier => _authRepository.syncStateNotifier;

  Future<bool> initializeIfSignedIn() => _authRepository.initializeIfSignedIn();

  Future<bool> isSignedIn() => _authRepository.isSignedIn();

  Future<dynamic> signIn() => _authRepository.signIn();

  Future<void> signOut() => _authRepository.signOut();

  Future<DriveSheetsStatus> checkSheetsExistence() => _authRepository.checkSheetsExistence();

  Future<void> createMissingSheets({
    required bool createExerciseDb,
    required bool createDailyRecord,
  }) =>
      _authRepository.createMissingSheets(
        createExerciseDb: createExerciseDb,
        createDailyRecord: createDailyRecord,
      );

  Future<SyncState> manualSync() => _authRepository.manualSyncToExcel();
}
