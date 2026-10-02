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
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectSplit(String split) async {
    _selectedSplit = split;
    await _splitUseCase.saveSelectedSplit(split);
    notifyListeners();
  }

  Future<void> loadSchedule() async {
    _isLoading = true;
    notifyListeners();

    try {
      _schedule = await _splitUseCase.getWeeklySchedule();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool canAssignDay(String split, String targetDay, String targetValue) {
    return _splitUseCase.canAssignWorkoutDay(
      split: split,
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
