import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../../data/repositories/workout_repository_impl.dart';
import '../../../../data/repositories/workout_split_repository_impl.dart';
import '../../../../domain/repositories/workout_repository.dart';
import '../../../../domain/use_cases/get_todays_workout_use_case.dart';
import '../../../../domain/use_cases/manage_workout_split_use_case.dart';

class HomeViewModel extends ChangeNotifier {
  final GetTodaysWorkoutUseCase _getTodaysWorkoutUseCase;
  final ManageWorkoutSplitUseCase _splitUseCase;
  final WorkoutRepository _workoutRepository;

  HomeViewModel({
    GetTodaysWorkoutUseCase? getTodaysWorkoutUseCase,
    ManageWorkoutSplitUseCase? splitUseCase,
    WorkoutRepository? workoutRepository,
  })  : _workoutRepository = workoutRepository ?? WorkoutRepositoryImpl(),
        _splitUseCase = splitUseCase ??
            ManageWorkoutSplitUseCase(splitRepository: WorkoutSplitRepositoryImpl()),
        _getTodaysWorkoutUseCase = getTodaysWorkoutUseCase ??
            GetTodaysWorkoutUseCase(
              workoutRepository: workoutRepository ?? WorkoutRepositoryImpl(),
              splitRepository: WorkoutSplitRepositoryImpl(),
            );

  String _todaysWorkout = 'Rest';
  String get todaysWorkout => _todaysWorkout;

  String _activeSplit = 'Bro Split';
  String get activeSplit => _activeSplit;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  Map<String, bool> _weekActivity = {};
  Map<String, bool> get weekActivity => _weekActivity;

  int _streakCount = 0;
  int get streakCount => _streakCount;

  Future<void> loadDashboardData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final savedSplit = await _splitUseCase.getSelectedSplit();
      final workoutData = await _getTodaysWorkoutUseCase.execute();
      final todaysFocus = workoutData.todaysFocus;

      // Load weekly activity for streak widget
      final records = await _workoutRepository.getDailyRecords();
      final Map<String, bool> activity = {};
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: (now.weekday - 1) % 7));

      for (int i = 0; i < 7; i++) {
        final dayDate = startOfWeek.add(Duration(days: i));
        final dayName = DateFormat('E', 'en_US').format(dayDate);
        final hasLog = records.any((r) =>
            r.date.year == dayDate.year &&
            r.date.month == dayDate.month &&
            r.date.day == dayDate.day);
        activity[dayName] = hasLog;
      }

      final activeDaysCount = activity.values.where((v) => v).length;

      _todaysWorkout = todaysFocus;
      _activeSplit = savedSplit;
      _weekActivity = activity;
      _streakCount = activeDaysCount;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
