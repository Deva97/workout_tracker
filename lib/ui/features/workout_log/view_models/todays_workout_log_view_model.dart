import 'package:flutter/foundation.dart';
import '../../../../data/repositories/exercise_repository_impl.dart';
import '../../../../data/repositories/workout_repository_impl.dart';
import '../../../../data/repositories/workout_split_repository_impl.dart';
import 'package:workout_tracker/domain/models/daily_record.dart';
import 'package:workout_tracker/domain/models/daily_workout_entry.dart';
import 'package:workout_tracker/domain/models/exercise.dart';
import '../../../../domain/use_cases/get_todays_workout_use_case.dart';
import '../../../../domain/use_cases/manage_exercises_use_case.dart';
import '../../../../domain/use_cases/manage_workout_set_use_case.dart';

class TodaysWorkoutLogViewModel extends ChangeNotifier {
  final GetTodaysWorkoutUseCase _getTodaysWorkoutUseCase;
  final ManageWorkoutSetUseCase _manageSetUseCase;
  final ManageExercisesUseCase _exercisesUseCase;

  TodaysWorkoutLogViewModel({
    GetTodaysWorkoutUseCase? getTodaysWorkoutUseCase,
    ManageWorkoutSetUseCase? manageSetUseCase,
    ManageExercisesUseCase? exercisesUseCase,
  })  : _getTodaysWorkoutUseCase = getTodaysWorkoutUseCase ??
            GetTodaysWorkoutUseCase(
              workoutRepository: WorkoutRepositoryImpl(),
              splitRepository: WorkoutSplitRepositoryImpl(),
            ),
        _manageSetUseCase = manageSetUseCase ??
            ManageWorkoutSetUseCase(workoutRepository: WorkoutRepositoryImpl()),
        _exercisesUseCase = exercisesUseCase ??
            ManageExercisesUseCase(exerciseRepository: ExerciseRepositoryImpl());

  List<DailyWorkoutEntry> _todaysEntries = [];
  List<DailyWorkoutEntry> get todaysEntries => _todaysEntries;

  List<Exercise> _availableExercises = [];
  List<Exercise> get availableExercises => _availableExercises;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _showRestTimer = false;
  bool get showRestTimer => _showRestTimer;

  void setShowRestTimer(bool show) {
    _showRestTimer = show;
    notifyListeners();
  }

  Future<void> loadTodaysWorkoutLog() async {
    _isLoading = true;
    notifyListeners();

    try {
      _availableExercises = await _exercisesUseCase.getExercises();
      final workoutData = await _getTodaysWorkoutUseCase.execute();
      _todaysEntries = workoutData.entries;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveSet(DailyRecord record) async {
    await _manageSetUseCase.addSet(record);
    _todaysEntries = _getTodaysWorkoutUseCase.getCachedEntries();
    _showRestTimer = true;
    notifyListeners();
  }

  Future<void> editSet(DailyRecord record) async {
    await _manageSetUseCase.editSet(record);
    _todaysEntries = _getTodaysWorkoutUseCase.getCachedEntries();
    notifyListeners();
  }

  Future<void> deleteSet(DailyWorkoutEntry entry) async {
    await _manageSetUseCase.deleteSet(entry.record.id);
    _todaysEntries = _getTodaysWorkoutUseCase.getCachedEntries();
    notifyListeners();
  }

  Future<void> restoreSet(DailyRecord record) async {
    await _manageSetUseCase.addSet(record);
    _todaysEntries = _getTodaysWorkoutUseCase.getCachedEntries();
    notifyListeners();
  }
}
