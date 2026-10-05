import '../models/workout_split.dart';
import '../repositories/workout_split_repository.dart';

class ManageWorkoutSplitUseCase {
  final WorkoutSplitRepository _splitRepository;

  ManageWorkoutSplitUseCase({
    required this._splitRepository,
  });

  Future<String> getSelectedSplit() => _splitRepository.getSelectedSplit();

  Future<void> saveSelectedSplit(String split) => _splitRepository.saveSelectedSplit(split);

  Future<int?> getSplitTargetDays() => _splitRepository.getSplitTargetDays();

  Future<void> saveSplitTargetDays(int days) => _splitRepository.saveSplitTargetDays(days);

  Future<Map<String, String>> getWeeklySchedule() => _splitRepository.getWeeklySchedule();

  Future<void> saveWeeklySchedule(Map<String, String> schedule) =>
      _splitRepository.saveWeeklySchedule(schedule);

  Future<String> getTodaysFocus() => _splitRepository.getTodaysFocus();

  List<String> getWorkoutOptions(String split) => WorkoutSplit.getWorkoutOptions(split);

  int? getMaximumWorkoutDays(String split) => WorkoutSplit.getMaximumWorkoutDays(split);

  /// Validates whether assigning a workout day violates weekly workout limits.
  /// If [maxDays] is provided, it is enforced as the authoritative limit.
  /// Otherwise, falls back to legacy [split] rules if available.
  bool canAssignWorkoutDay({
    String? split,
    int? maxDays,
    required Map<String, String> currentSchedule,
    required String targetDay,
    required String targetValue,
  }) {
    if (targetValue.isEmpty || targetValue == 'Rest') return true;

    final effectiveMaxDays = maxDays ?? (split != null ? WorkoutSplit.getMaximumWorkoutDays(split) : null);
    if (effectiveMaxDays == null) return true;

    final candidateSchedule = Map<String, String>.from(currentSchedule);
    candidateSchedule[targetDay] = targetValue;

    final activeDaysCount = candidateSchedule.values
        .where((workout) => workout.isNotEmpty && workout != 'Rest')
        .length;

    return activeDaysCount <= effectiveMaxDays;
  }
}
