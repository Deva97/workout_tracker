import '../../domain/models/daily_record.dart';
import '../../domain/models/daily_workout_entry.dart';
import '../../domain/models/exercise.dart';
import '../orm/excel_context.dart';
import '../orm/excel_table.dart';

/// Strongly-typed Database Context for Workout Tracker app spreadsheets.
class WorkoutDbContext extends ExcelContext {
  ExcelTable<Exercise> exercises;
  ExcelTable<DailyRecord> dailyRecords;

  WorkoutDbContext({
    ExcelTable<Exercise>? exercises,
    ExcelTable<DailyRecord>? dailyRecords,
  })  : exercises = exercises ??
            ExcelTable<Exercise>(
              sheetName: 'Sheet1',
              mapper: Exercise.excelMapper,
            ),
        dailyRecords = dailyRecords ??
            ExcelTable<DailyRecord>(
              sheetName: 'Sheet1',
              mapper: DailyRecord.excelMapper,
            );

  /// Load exercises table from [Exercise_DB.xlsx] byte stream.
  void loadExerciseDbFromBytes(List<int> bytes) {
    exercises = loadTableFromBytes<Exercise>(
      bytes: bytes,
      mapper: Exercise.excelMapper,
      sheetName: 'Sheet1',
    );
  }

  /// Save exercises table to [Exercise_DB.xlsx] byte stream.
  List<int> saveExerciseDbToBytes() {
    return saveTableToBytes<Exercise>(exercises);
  }

  /// Load daily records table from [Daily_record.xlsx] byte stream.
  void loadDailyRecordFromBytes(List<int> bytes) {
    dailyRecords = loadTableFromBytes<DailyRecord>(
      bytes: bytes,
      mapper: DailyRecord.excelMapper,
      sheetName: 'Sheet1',
    );
  }

  /// Save daily records table to [Daily_record.xlsx] byte stream.
  List<int> saveDailyRecordToBytes() {
    return saveTableToBytes<DailyRecord>(dailyRecords);
  }

  /// Query workout entries for a specific day (default: today) resolved with associated parent [Exercise] entity.
  /// Uses single index map lookup (r.workoutId == exercise.guid) to prevent N+1 queries.
  List<DailyWorkoutEntry> getTodaysWorkoutEntries([DateTime? date]) {
    final targetDate = date ?? DateTime.now();

    // 1. Filter daily records matching target date using ExcelORM query
    final todaysRecords = dailyRecords.whereQuery((r) {
      return r.date.year == targetDate.year &&
          r.date.month == targetDate.month &&
          r.date.day == targetDate.day;
    }).orderBy((r) => r.set).toList();

    if (todaysRecords.isEmpty) return [];

    // 2. Build index of exercises by GUID to resolve relationship efficiently (0 N+1 queries)
    final exerciseMap = <String, Exercise>{
      for (final exercise in exercises) exercise.guid: exercise,
    };

    // 3. Construct relational DTO entries
    return todaysRecords.map((record) {
      final exercise = exerciseMap[record.workoutId] ??
          Exercise(
            guid: record.workoutId,
            name: record.workoutName.isNotEmpty ? record.workoutName : 'Unknown Exercise',
            bodyPart: '',
          );
      return DailyWorkoutEntry(record: record, exercise: exercise);
    }).toList();
  }

  /// Create default initial empty [Exercise_DB.xlsx] file bytes.
  List<int> createDefaultExerciseDbBytes() {
    final emptyTable = ExcelTable<Exercise>(
      sheetName: 'Sheet1',
      mapper: Exercise.excelMapper,
    );
    return saveTableToBytes<Exercise>(emptyTable);
  }

  /// Create default initial empty [Daily_record.xlsx] file bytes.
  List<int> createDefaultDailyRecordBytes() {
    final emptyTable = ExcelTable<DailyRecord>(
      sheetName: 'Sheet1',
      mapper: DailyRecord.excelMapper,
    );
    return saveTableToBytes<DailyRecord>(emptyTable);
  }
}
