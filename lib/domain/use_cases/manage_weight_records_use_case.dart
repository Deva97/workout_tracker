import 'package:intl/intl.dart';
import '../models/weight_record.dart';
import '../models/weekly_weight_average.dart';
import '../repositories/weight_repository.dart';

class ManageWeightRecordsUseCase {
  final WeightRepository repository;

  ManageWeightRecordsUseCase({required this.repository});

  Future<bool> checkWeightSheetExists() => repository.checkWeightSheetExists();

  Future<void> createWeightSheet() => repository.createWeightSheet();

  Future<List<WeightRecord>> getWeightRecords() async {
    final records = await repository.getWeightRecords();
    records.sort((a, b) => a.date.compareTo(b.date));
    return records;
  }

  Future<WeightRecord?> getTodayWeightRecord() => repository.getTodayWeightRecord();

  Future<void> saveTodayWeight(double weight, {String notes = '', String unit = 'kg'}) async {
    final now = DateTime.now();
    final dateKey = DateFormat('yyyy-MM-dd').format(now);
    final record = WeightRecord(
      id: 'wt_$dateKey',
      date: now,
      weight: weight,
      unit: unit,
      notes: notes,
    );
    await repository.saveWeightRecord(record);
  }

  Future<void> deleteWeightRecord(String id) => repository.deleteWeightRecord(id);

  /// Computes weekly average weight records grouped by calendar week (Monday to Sunday)
  List<WeeklyWeightAverage> computeWeeklyAverages(List<WeightRecord> records) {
    if (records.isEmpty) return [];

    final Map<int, List<WeightRecord>> recordsByWeek = {};
    final Map<int, DateTime> weekStartDates = {};

    for (final record in records) {
      // Find the Monday of the record's week
      final weekday = record.date.weekday; // 1 = Monday, 7 = Sunday
      final monday = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      ).subtract(Duration(days: weekday - 1));

      final weekKey = monday.year * 10000 + monday.month * 100 + monday.day;
      recordsByWeek.putIfAbsent(weekKey, () => []).add(record);
      weekStartDates[weekKey] = monday;
    }

    final sortedKeys = recordsByWeek.keys.toList()..sort();
    final List<WeeklyWeightAverage> weeklyAverages = [];

    for (final key in sortedKeys) {
      final weekRecords = recordsByWeek[key]!;
      final weekStart = weekStartDates[key]!;
      final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

      double sum = 0.0;
      double min = double.infinity;
      double max = -double.infinity;

      for (final r in weekRecords) {
        sum += r.weight;
        if (r.weight < min) min = r.weight;
        if (r.weight > max) max = r.weight;
      }

      final average = sum / weekRecords.length;

      weeklyAverages.add(
        WeeklyWeightAverage(
          weekStart: weekStart,
          weekEnd: weekEnd,
          averageWeight: double.parse(average.toStringAsFixed(2)),
          entryCount: weekRecords.length,
          minWeight: min,
          maxWeight: max,
        ),
      );
    }

    return weeklyAverages;
  }

  /// Calculates the difference between the most recent week and previous week average
  double? computeWeeklyDelta(List<WeeklyWeightAverage> averages) {
    if (averages.length < 2) return null;
    final latest = averages.last.averageWeight;
    final previous = averages[averages.length - 2].averageWeight;
    return double.parse((latest - previous).toStringAsFixed(2));
  }
}
