import 'package:flutter/foundation.dart';
import '../../../../data/repositories/auth_repository_impl.dart';
import '../../../../data/repositories/exercise_repository_impl.dart';
import 'package:workout_tracker/domain/models/exercise.dart';
import '../../../../domain/use_cases/auth_and_sync_use_case.dart';
import '../../../../domain/use_cases/manage_exercises_use_case.dart';

class ExerciseInfoViewModel extends ChangeNotifier {
  final ManageExercisesUseCase _exercisesUseCase;
  final AuthAndSyncUseCase _authUseCase;

  ExerciseInfoViewModel({
    ManageExercisesUseCase? exercisesUseCase,
    AuthAndSyncUseCase? authUseCase,
  })  : _exercisesUseCase = exercisesUseCase ??
            ManageExercisesUseCase(exerciseRepository: ExerciseRepositoryImpl()),
        _authUseCase = authUseCase ??
            AuthAndSyncUseCase(authRepository: AuthRepositoryImpl());

  List<Exercise> _filteredExercises = [];
  List<Exercise> get filteredExercises => _filteredExercises;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isSignedIn = false;
  bool get isSignedIn => _isSignedIn;

  String _selectedCategory = 'All';
  String get selectedCategory => _selectedCategory;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  Future<void> checkAuthAndLoadExercises() async {
    _isLoading = true;
    notifyListeners();

    try {
      _isSignedIn = await _authUseCase.isSignedIn();
      if (_isSignedIn) {
        await _exercisesUseCase.syncFromDrive();
      }
      await _exercisesUseCase.getExercises();
      _applyFilters();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _applyFilters() {
    _filteredExercises = _exercisesUseCase.queryExercises(
      category: _selectedCategory,
      searchQuery: _searchQuery,
    );
  }

  void selectCategory(String category) {
    _selectedCategory = category;
    _applyFilters();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  Future<Exercise> addExercise(String name, String bodyPart) async {
    final exercise = await _exercisesUseCase.addExercise(name, bodyPart);
    _applyFilters();
    notifyListeners();
    return exercise;
  }

  Future<void> deleteExercise(String guid) async {
    await _exercisesUseCase.deleteExercise(guid);
    _applyFilters();
    notifyListeners();
  }
}
