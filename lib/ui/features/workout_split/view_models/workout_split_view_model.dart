import 'package:flutter/foundation.dart';
import '../../../../data/repositories/workout_split_repository_impl.dart';
import '../../../../domain/models/workout_split.dart';
import '../../../../domain/use_cases/manage_workout_split_use_case.dart';

class WorkoutSplitViewModel extends ChangeNotifier {
  final ManageWorkoutSplitUseCase _splitUseCase;

  WorkoutSplitViewModel({
    ManageWorkoutSplitUseCase? splitUseCase,
  }) : _splitUseCase = splitUseCase ??
            ManageWorkoutSplitUseCase(splitRepository: WorkoutSplitRepositoryImpl());

  String? _selectedSplit;
  String? get selectedSplit => _selectedSplit;

  int? _targetDays;
  int? get targetDays => _targetDays;

  Map<String, String> _schedule = {};
  Map<String, String> get schedule => _schedule;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  Future<void> loadSelectedSplit() async {
    _isLoading = true;
    notifyListeners();

    try {
      final savedSplit = await _splitUseCase.getSelectedSplit();
      _selectedSplit = WorkoutSplit.splitOptions.contains(savedSplit) ? savedSplit : null;
      _targetDays = await _splitUseCase.getSplitTargetDays();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectSplit(String split, [int? targetDays]) async {
    _selectedSplit = split;
    await _splitUseCase.saveSelectedSplit(split);
    if (targetDays != null) {
      _targetDays = targetDays;
      await _splitUseCase.saveSplitTargetDays(targetDays);
    }
    notifyListeners();
  }

  Future<void> loadTargetDays() async {
    _targetDays = await _splitUseCase.getSplitTargetDays();
    notifyListeners();
  }

  Future<void> saveTargetDays(int days) async {
    _targetDays = days;
    await _splitUseCase.saveSplitTargetDays(days);
    notifyListeners();
  }

  Future<void> loadSchedule() async {
    _isLoading = true;
    notifyListeners();

    try {
      _schedule = await _splitUseCase.getWeeklySchedule();
      _targetDays = await _splitUseCase.getSplitTargetDays();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool canAssignDay(String split, String targetDay, String targetValue, {int? maxDays}) {
    return _splitUseCase.canAssignWorkoutDay(
      split: split,
      maxDays: maxDays ?? _targetDays,
      currentSchedule: _schedule,
      targetDay: targetDay,
      targetValue: targetValue,
    );
  }

  Future<void> assignWorkoutDay(String day, String workout) async {
    _schedule[day] = workout;
    await _splitUseCase.saveWeeklySchedule(_schedule);
    notifyListeners();
  }
}
