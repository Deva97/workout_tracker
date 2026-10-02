import 'package:flutter/foundation.dart';
import '../../../../data/repositories/exercise_repository_impl.dart';
import '../../../../data/repositories/workout_repository_impl.dart';
import 'package:workout_tracker/domain/models/daily_record.dart';
import 'package:workout_tracker/domain/models/exercise.dart';
import '../../../../domain/use_cases/get_exercise_statistics_use_case.dart';
import '../../../../domain/use_cases/manage_exercises_use_case.dart';

class ExerciseStatisticsViewModel extends ChangeNotifier {
  final ManageExercisesUseCase _exercisesUseCase;
  final GetExerciseStatisticsUseCase _statisticsUseCase;

  ExerciseStatisticsViewModel({
    ManageExercisesUseCase? exercisesUseCase,
    GetExerciseStatisticsUseCase? statisticsUseCase,
  })  : _exercisesUseCase = exercisesUseCase ??
            ManageExercisesUseCase(exerciseRepository: ExerciseRepositoryImpl()),
        _statisticsUseCase = statisticsUseCase ??
            GetExerciseStatisticsUseCase(workoutRepository: WorkoutRepositoryImpl());

  List<Exercise> _availableExercises = [];
  List<Exercise> get availableExercises => _availableExercises;

  Exercise? _selectedExercise;
  Exercise? get selectedExercise => _selectedExercise;

  List<DailyRecord> _rawHistoryRecords = [];
  List<DailyRecord> get rawHistoryRecords => _rawHistoryRecords;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  double _peakScore = 0.0;
  double get peakScore => _peakScore;

  int _totalSetsInPeriod = 0;
  int get totalSetsInPeriod => _totalSetsInPeriod;

  int _totalSessionsInPeriod = 0;
  int get totalSessionsInPeriod => _totalSessionsInPeriod;

  double _trendPercentage = 0.0;
  double get trendPercentage => _trendPercentage;

  int _selectedDays = 30;
  int get selectedDays => _selectedDays;

  Future<void> init(String? initialExerciseGuid) async {
    _isLoading = true;
    notifyListeners();

    try {
      _availableExercises = await _exercisesUseCase.getExercises();
      if (_availableExercises.isNotEmpty) {
        if (initialExerciseGuid != null) {
          _selectedExercise = _availableExercises.firstWhere(
            (e) => e.guid == initialExerciseGuid,
            orElse: () => _availableExercises.first,
          );
        } else {
          _selectedExercise = _availableExercises.first;
        }
        await loadStatsForSelectedExercise();
      } else {
        _isLoading = false;
        notifyListeners();
      }
    } catch (_) {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectExercise(Exercise exercise) async {
    _selectedExercise = exercise;
    await loadStatsForSelectedExercise();
  }

  Future<void> selectDays(int days) async {
    _selectedDays = days;
    await loadStatsForSelectedExercise();
  }

  Future<void> loadStatsForSelectedExercise() async {
    if (_selectedExercise == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final summary = await _statisticsUseCase.execute(
        _selectedExercise!.guid,
        days: _selectedDays,
      );

      _rawHistoryRecords = summary.records;
      _peakScore = summary.peakScore;
      _totalSetsInPeriod = summary.totalSets;
      _totalSessionsInPeriod = summary.totalSessions;
      _trendPercentage = summary.trendPercentage;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
