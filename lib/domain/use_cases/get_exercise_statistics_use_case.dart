import 'dart:math';
import '../models/daily_record.dart';
import '../repositories/workout_repository.dart';

class ExerciseStatsSummary {
  final List<DailyRecord> records;
  final double peakScore;
  final int totalSets;
  final int totalSessions;
  final double trendPercentage;

  ExerciseStatsSummary({
    required this.records,
    required this.peakScore,
    required this.totalSets,
    required this.totalSessions,
    required this.trendPercentage,
  });
}

class GetExerciseStatisticsUseCase {
  final WorkoutRepository _workoutRepository;

  GetExerciseStatisticsUseCase({
    required this._workoutRepository,
  });

  Future<ExerciseStatsSummary> execute(String workoutId, {int days = 30}) async {
    final records = await _workoutRepository.queryExerciseHistory(workoutId, daysLimit: days);

    if (records.isEmpty) {
      return ExerciseStatsSummary(
        records: [],
        peakScore: 0.0,
        totalSets: 0,
        totalSessions: 0,
        trendPercentage: 0.0,
      );
    }

    double peak1RM = 0.0;
    for (final r in records) {
      final oneRM = _calculateEstimated1RM(r.weight, r.reps);
      if (oneRM > peak1RM) peak1RM = oneRM;
    }

    final sessionDates = records.map((r) => '${r.date.year}-${r.date.month}-${r.date.day}').toSet();
    final totalSessions = sessionDates.length;

    // Group records by day to calculate chronological trend
    final Map<String, List<DailyRecord>> groupedByDay = {};
    for (final r in records) {
      final key = '${r.date.year}-${r.date.month.toString().padLeft(2, '0')}-${r.date.day.toString().padLeft(2, '0')}';
      groupedByDay.putIfAbsent(key, () => []).add(r);
    }

    final sortedDayKeys = groupedByDay.keys.toList()..sort();
    double trendPercentage = 0.0;

    if (sortedDayKeys.length >= 2) {
      final firstDayRecords = groupedByDay[sortedDayKeys.first]!;
      final lastDayRecords = groupedByDay[sortedDayKeys.last]!;

      final firstDayMax1RM = firstDayRecords.map((r) => _calculateEstimated1RM(r.weight, r.reps)).reduce(max);
      final lastDayMax1RM = lastDayRecords.map((r) => _calculateEstimated1RM(r.weight, r.reps)).reduce(max);

      if (firstDayMax1RM > 0) {
        trendPercentage = ((lastDayMax1RM - firstDayMax1RM) / firstDayMax1RM) * 100.0;
      }
    }

    return ExerciseStatsSummary(
      records: records,
      peakScore: peak1RM,
      totalSets: records.length,
      totalSessions: totalSessions,
      trendPercentage: trendPercentage,
    );
  }

  double _calculateEstimated1RM(double weight, int reps) {
    if (weight <= 0 || reps <= 0) return 0.0;
    return weight * (1.0 + reps / 30.0);
  }
}
