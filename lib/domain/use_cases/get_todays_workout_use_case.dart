import '../models/daily_workout_entry.dart';
import '../repositories/workout_repository.dart';
import '../repositories/workout_split_repository.dart';

class TodaysWorkoutData {
  final List<DailyWorkoutEntry> entries;
  final String todaysFocus;

  TodaysWorkoutData({
    required this.entries,
    required this.todaysFocus,
  });
}

class GetTodaysWorkoutUseCase {
  final WorkoutRepository _workoutRepository;
  final WorkoutSplitRepository _splitRepository;

  GetTodaysWorkoutUseCase({
    required this._workoutRepository,
    required this._splitRepository,
  });

  Future<TodaysWorkoutData> execute([DateTime? date]) async {
    final entries = await _workoutRepository.getTodaysWorkoutEntries(date);
    final focus = await _splitRepository.getTodaysFocus();
    return TodaysWorkoutData(entries: entries, todaysFocus: focus);
  }

  List<DailyWorkoutEntry> getCachedEntries([DateTime? date]) {
    return _workoutRepository.getCachedTodaysWorkoutEntries(date);
  }
}
