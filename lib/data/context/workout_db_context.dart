import '../../domain/models/daily_record.dart';
import '../../domain/models/daily_workout_entry.dart';
import '../../domain/models/exercise.dart';
import '../orm/excel_context.dart';
import '../orm/excel_query.dart';
import '../orm/excel_table.dart';

/// Strongly-typed Database Context for Workout Tracker app spreadsheets.
class WorkoutDbContext extends ExcelContext {
  ExcelTable<Exercise> _exercises;
  ExcelTable<DailyRecord> _dailyRecords;

  WorkoutDbContext({
    ExcelTable<Exercise>? exercises,
    ExcelTable<DailyRecord>? dailyRecords,
  })  : _exercises = exercises ??
            ExcelTable<Exercise>(
              sheetName: 'Sheet1',
              mapper: Exercise.excelMapper,
            ),
        _dailyRecords = dailyRecords ??
            ExcelTable<DailyRecord>(
              sheetName: 'Sheet1',
              mapper: DailyRecord.excelMapper,
            );

        /// Reads all exercises from the context.
        List<Exercise> readExercises() => _exercises.toList();

        /// Creates a query over the exercise table.
        ExcelQuery<Exercise> queryExercises() => _exercises.query();

        /// Returns the first exercise matching [predicate], or `null` if none match.
        Exercise? firstExerciseOrDefault([bool Function(Exercise exercise)? predicate]) =>
          _exercises.firstOrDefault(predicate);

        /// Reads all daily records from the context.
        List<DailyRecord> readDailyRecords() => _dailyRecords.toList();

        /// Creates a query over the daily record table.
        ExcelQuery<DailyRecord> queryDailyRecords() => _dailyRecords.query();

        /// Returns the first daily record matching [predicate], or `null` if none match.
        DailyRecord? firstDailyRecordOrDefault([bool Function(DailyRecord record)? predicate]) =>
          _dailyRecords.firstOrDefault(predicate);

  /// Adds [exercise] to the exercise table.
  void addExercise(Exercise exercise) => _exercises.add(exercise);

  /// Replaces the exercise table with [replacement].
  void replaceExercises(Iterable<Exercise> replacement) {
    final entities = replacement.toList();
    _exercises
      ..clear()
      ..addAll(entities);
  }

  /// Updates the first exercise matching [matches] and reports whether it was found.
  bool updateExercise(
    Exercise exercise,
    bool Function(Exercise existing) matches,
  ) =>
      _exercises.update(exercise, matches);

  /// Deletes exercises matching [matches] and returns the number removed.
  int deleteExercisesWhere(bool Function(Exercise exercise) matches) =>
      _exercises.deleteWhere(matches);

  /// Adds [record] to the daily record table.
  void addDailyRecord(DailyRecord record) => _dailyRecords.add(record);

  /// Replaces the daily record table with [replacement].
  void replaceDailyRecords(Iterable<DailyRecord> replacement) {
    final entities = replacement.toList();
    _dailyRecords
      ..clear()
      ..addAll(entities);
  }

  /// Updates the first daily record matching [matches] and reports whether it was found.
  bool updateDailyRecord(
    DailyRecord record,
    bool Function(DailyRecord existing) matches,
  ) =>
      _dailyRecords.update(record, matches);

  /// Deletes daily records matching [matches] and returns the number removed.
  int deleteDailyRecordsWhere(bool Function(DailyRecord record) matches) =>
      _dailyRecords.deleteWhere(matches);

  /// Load exercises table from [Exercise_DB.xlsx] byte stream.
  void loadExerciseDbFromBytes(List<int> bytes) {
    _exercises = loadTableFromBytes<Exercise>(
      bytes: bytes,
      mapper: Exercise.excelMapper,
      sheetName: 'Sheet1',
    );
  }

  /// Save exercises table to [Exercise_DB.xlsx] byte stream.
  List<int> saveExerciseDbToBytes() {
    return saveTableToBytes<Exercise>(_exercises);
  }

  /// Load daily records table from [Daily_record.xlsx] byte stream.
  void loadDailyRecordFromBytes(List<int> bytes) {
    _dailyRecords = loadTableFromBytes<DailyRecord>(
      bytes: bytes,
      mapper: DailyRecord.excelMapper,
      sheetName: 'Sheet1',
    );
  }

  /// Loads daily records from [Daily_record.xlsx] byte stream, retaining entries since [since].
  /// Filters rows without early termination to guard against out-of-order rows in manually edited sheets.
  void loadRecentDailyRecordsFromBytes(List<int> bytes, {required DateTime since}) {
    final earliestDate = DateTime(since.year, since.month, since.day);
    final allTable = loadTableFromBytes<DailyRecord>(
      bytes: bytes,
      mapper: DailyRecord.excelMapper,
      sheetName: 'Sheet1',
    );
    _dailyRecords = ExcelTable<DailyRecord>(
      sheetName: allTable.sheetName,
      mapper: DailyRecord.excelMapper,
      initialEntities: allTable.where((record) {
        final recordDate = DateTime(
          record.date.year,
          record.date.month,
          record.date.day,
        );
        return !recordDate.isBefore(earliestDate);
      }).toList(),
    );
  }

  /// Save daily records table to [Daily_record.xlsx] byte stream.
  List<int> saveDailyRecordToBytes() {
    return saveTableToBytes<DailyRecord>(_dailyRecords);
  }

  /// Query workout entries for a specific day (default: today) resolved with associated parent [Exercise] entity.
  /// Uses single index map lookup (r.workoutId == exercise.guid) to prevent N+1 queries.
  List<DailyWorkoutEntry> getTodaysWorkoutEntries([DateTime? date]) {
    final targetDate = date ?? DateTime.now();

    // 1. Filter daily records matching target date using ExcelORM query
    final todaysRecords = _dailyRecords.whereQuery((r) {
      return r.date.year == targetDate.year &&
          r.date.month == targetDate.month &&
          r.date.day == targetDate.day;
    }).orderBy((r) => r.set).toList();

    if (todaysRecords.isEmpty) return [];

    // 2. Build index of exercises by GUID to resolve relationship efficiently (0 N+1 queries)
    final exerciseMap = <String, Exercise>{
      for (final exercise in _exercises) exercise.guid: exercise,
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
