import 'package:flutter/foundation.dart';
import '../../../../data/repositories/workout_repository_impl.dart';
import '../../../../data/repositories/workout_split_repository_impl.dart';
import '../../../../domain/repositories/workout_repository.dart';
import '../../../../domain/use_cases/get_todays_workout_use_case.dart';
import '../../../../domain/use_cases/manage_workout_split_use_case.dart';
import '../../weekly_activity/view_models/weekly_activity_view_model.dart';

class HomeViewModel extends ChangeNotifier {
  final GetTodaysWorkoutUseCase _getTodaysWorkoutUseCase;
  final ManageWorkoutSplitUseCase _splitUseCase;
  final WeeklyActivityViewModel _weeklyActivityViewModel;

  HomeViewModel({
    GetTodaysWorkoutUseCase? getTodaysWorkoutUseCase,
    ManageWorkoutSplitUseCase? splitUseCase,
    WorkoutRepository? workoutRepository,
    WeeklyActivityViewModel? weeklyActivityViewModel,
  })  : _weeklyActivityViewModel = weeklyActivityViewModel ?? WeeklyActivityViewModel(),
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

  Map<String, bool> get weekActivity => _weeklyActivityViewModel.weekActivity;

  int get streakCount => _weeklyActivityViewModel.streakCount;

  Future<void> loadDashboardData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final savedSplit = await _splitUseCase.getSelectedSplit();
      final workoutData = await _getTodaysWorkoutUseCase.execute();
      final todaysFocus = workoutData.todaysFocus;

      await _weeklyActivityViewModel.loadWeeklyActivity();

      _todaysWorkout = todaysFocus;
      _activeSplit = savedSplit;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _weeklyActivityViewModel.dispose();
    super.dispose();
  }
}
