import 'daily_record.dart';
import 'exercise.dart';

/// Relational DTO connecting a [DailyRecord] set entry to its resolved parent [Exercise] entity.
class DailyWorkoutEntry {
  final DailyRecord record;
  final Exercise exercise;

  DailyWorkoutEntry({
    required this.record,
    required this.exercise,
  });

  @override
  String toString() => 'DailyWorkoutEntry(record: ${record.id}, exercise: ${exercise.name})';
}
