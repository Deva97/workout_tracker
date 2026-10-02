import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../../data/repositories/workout_repository_impl.dart';
import '../../../../domain/repositories/workout_repository.dart';

class WeeklyActivityViewModel extends ChangeNotifier {
  WeeklyActivityViewModel({WorkoutRepository? workoutRepository})
    : _workoutRepository = workoutRepository ?? WorkoutRepositoryImpl();

  final WorkoutRepository _workoutRepository;

  Map<String, bool> _weekActivity = const {};
  Map<String, bool> get weekActivity => _weekActivity;

  int _streakCount = 0;
  int get streakCount => _streakCount;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _notifyListenersIfActive() {
    if (!_isDisposed) notifyListeners();
  }

  Future<void> loadWeeklyActivity() async {
    if (_weekActivity.isEmpty) {
      _isLoading = true;
      _notifyListenersIfActive();
    }

    try {
      final records = await _workoutRepository.getWeeklyDailyRecords();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final monday = today.subtract(Duration(days: now.weekday - 1));
      final recordedDays = records
          .map(
            (record) => DateTime(
              record.date.year,
              record.date.month,
              record.date.day,
            ).toIso8601String(),
          )
          .toSet();
      final activity = <String, bool>{};

      for (var index = 0; index < 7; index++) {
        final day = monday.add(Duration(days: index));
        final dayName = DateFormat('E', 'en_US').format(day);
        activity[dayName] = recordedDays.contains(day.toIso8601String());
      }

      _weekActivity = Map.unmodifiable(activity);
      _streakCount = activity.values.where((isActive) => isActive).length;
    } finally {
      _isLoading = false;
      _notifyListenersIfActive();
    }
  }
}
