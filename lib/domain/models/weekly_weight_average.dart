import 'package:intl/intl.dart';

class WeeklyWeightAverage {
  final DateTime weekStart;
  final DateTime weekEnd;
  final double averageWeight;
  final int entryCount;
  final double minWeight;
  final double maxWeight;

  const WeeklyWeightAverage({
    required this.weekStart,
    required this.weekEnd,
    required this.averageWeight,
    required this.entryCount,
    required this.minWeight,
    required this.maxWeight,
  });

  String get formattedRange {
    final startStr = DateFormat('MMM d').format(weekStart);
    final endStr = DateFormat('MMM d').format(weekEnd);
    return '$startStr - $endStr';
  }

  String get shortLabel {
    return DateFormat('M/d').format(weekStart);
  }

  @override
  String toString() =>
      'WeeklyWeightAverage(range: $formattedRange, avg: ${averageWeight.toStringAsFixed(1)} kg, count: $entryCount)';
}
