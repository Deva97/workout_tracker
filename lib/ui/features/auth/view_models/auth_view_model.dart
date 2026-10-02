import 'package:flutter/foundation.dart';
import '../../../../data/repositories/auth_repository_impl.dart';
import '../../../../domain/repositories/auth_repository.dart';
import '../../../../domain/use_cases/auth_and_sync_use_case.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthAndSyncUseCase _authUseCase;

  AuthViewModel({AuthAndSyncUseCase? authUseCase})
      : _authUseCase = authUseCase ??
            AuthAndSyncUseCase(authRepository: AuthRepositoryImpl());

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _statusMessage = 'Initializing Workout Tracker...';
  String get statusMessage => _statusMessage;

  String? _subMessage = 'Checking session state';
  String? get subMessage => _subMessage;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  DriveSheetsStatus? _sheetsStatus;
  DriveSheetsStatus? get sheetsStatus => _sheetsStatus;

  ValueNotifier<SyncState> get syncStateNotifier => _authUseCase.syncStateNotifier;

  void updateStatus(String message, [String? subMessage]) {
    _statusMessage = message;
    _subMessage = subMessage;
    notifyListeners();
  }

  Future<bool> initializeIfSignedIn() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final signedIn = await _authUseCase.initializeIfSignedIn();
      return signedIn;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<DriveSheetsStatus?> checkSheetsExistence() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _sheetsStatus = await _authUseCase.checkSheetsExistence();
      return _sheetsStatus;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createMissingSheets({
    required bool createExerciseDb,
    required bool createDailyRecord,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authUseCase.createMissingSheets(
        createExerciseDb: createExerciseDb,
        createDailyRecord: createDailyRecord,
      );
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signIn() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final account = await _authUseCase.signIn();
      return account != null;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authUseCase.signOut();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<SyncState> manualSync() => _authUseCase.manualSync();
}
