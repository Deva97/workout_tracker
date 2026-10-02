import 'package:intl/intl.dart';
import '../../domain/repositories/workout_split_repository.dart';
import '../services/local_storage_service.dart';

class WorkoutSplitRepositoryImpl implements WorkoutSplitRepository {
  final LocalStorageService _storageService;

  WorkoutSplitRepositoryImpl({LocalStorageService? storageService})
      : _storageService = storageService ?? LocalStorageService();

  @override
  Future<String> getSelectedSplit() {
    return _storageService.getSelectedSplit();
  }

  @override
  Future<void> saveSelectedSplit(String split) {
    return _storageService.setSelectedSplit(split);
  }

  @override
  Future<Map<String, String>> getWeeklySchedule() {
    return _storageService.getWeeklySchedule();
  }

  @override
  Future<void> saveWeeklySchedule(Map<String, String> schedule) {
    return _storageService.setWorkoutSchedule(schedule);
  }

  @override
  Future<String> getTodaysFocus() async {
    final schedule = await _storageService.getWorkoutSchedule();
    if (schedule.isEmpty) return 'Rest';
    final todayWeekday = DateFormat('EEEE', 'en_US').format(DateTime.now());
    return schedule[todayWeekday] ?? 'Rest';
  }
}
