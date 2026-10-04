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

  // High-performance O(1) in-memory lookup indexes
  final Map<String, Exercise> _exerciseGuidIndex = {};
  final Map<int, List<DailyRecord>> _recordsByDateKey = {};

  static int _dateKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  void _rebuildExerciseIndex() {
    _exerciseGuidIndex.clear();
    for (final ex in _exercises) {
      _exerciseGuidIndex[ex.guid] = ex;
    }
  }

  void _rebuildDailyRecordIndex() {
    _recordsByDateKey.clear();
    for (final rec in _dailyRecords) {
      final key = _dateKey(rec.date);
      _recordsByDateKey.putIfAbsent(key, () => []).add(rec);
    }
    for (final list in _recordsByDateKey.values) {
      list.sort((a, b) => a.set.compareTo(b.set));
    }
  }

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
            ) {
    _rebuildExerciseIndex();
    _rebuildDailyRecordIndex();
  }

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
  void addExercise(Exercise exercise) {
    _exercises.add(exercise);
    _exerciseGuidIndex[exercise.guid] = exercise;
  }

  /// Replaces the exercise table with [replacement].
  void replaceExercises(Iterable<Exercise> replacement) {
    final entities = replacement.toList();
    _exercises
      ..clear()
      ..addAll(entities);
    _rebuildExerciseIndex();
  }

  /// Updates the first exercise matching [matches] and reports whether it was found.
  bool updateExercise(
    Exercise exercise,
    bool Function(Exercise existing) matches,
  ) {
    final updated = _exercises.update(exercise, matches);
    if (updated) {
      _rebuildExerciseIndex();
    }
    return updated;
  }

  /// Deletes exercises matching [matches] and returns the number removed.
  int deleteExercisesWhere(bool Function(Exercise exercise) matches) {
    final count = _exercises.deleteWhere(matches);
    if (count > 0) {
      _rebuildExerciseIndex();
    }
    return count;
  }

  /// Adds [record] to the daily record table.
  void addDailyRecord(DailyRecord record) {
    _dailyRecords.add(record);
    final key = _dateKey(record.date);
    final list = _recordsByDateKey.putIfAbsent(key, () => []);
    list.add(record);
    list.sort((a, b) => a.set.compareTo(b.set));
  }

  /// Replaces the daily record table with [replacement].
  void replaceDailyRecords(Iterable<DailyRecord> replacement) {
    final entities = replacement.toList();
    _dailyRecords
      ..clear()
      ..addAll(entities);
    _rebuildDailyRecordIndex();
  }

  /// Updates the first daily record matching [matches] and reports whether it was found.
  bool updateDailyRecord(
    DailyRecord record,
    bool Function(DailyRecord existing) matches,
  ) {
    final updated = _dailyRecords.update(record, matches);
    if (updated) {
      _rebuildDailyRecordIndex();
    }
    return updated;
  }

  /// Deletes daily records matching [matches] and returns the number removed.
  int deleteDailyRecordsWhere(bool Function(DailyRecord record) matches) {
    final count = _dailyRecords.deleteWhere(matches);
    if (count > 0) {
      _rebuildDailyRecordIndex();
    }
    return count;
  }

  /// Load exercises table from [Exercise_DB.xlsx] byte stream.
  void loadExerciseDbFromBytes(List<int> bytes) {
    _exercises = loadTableFromBytes<Exercise>(
      bytes: bytes,
      mapper: Exercise.excelMapper,
      sheetName: 'Sheet1',
    );
    _rebuildExerciseIndex();
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
    _rebuildDailyRecordIndex();
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
    _rebuildDailyRecordIndex();
  }

  /// Save daily records table to [Daily_record.xlsx] byte stream.
  List<int> saveDailyRecordToBytes() {
    return saveTableToBytes<DailyRecord>(_dailyRecords);
  }

  /// Query workout entries for a specific day (default: today) resolved with associated parent [Exercise] entity.
  /// Uses single index map lookup (O(1)) without linear table scanning.
  List<DailyWorkoutEntry> getTodaysWorkoutEntries([DateTime? date]) {
    final targetDate = date ?? DateTime.now();
    final key = _dateKey(targetDate);
    final records = _recordsByDateKey[key];

    if (records == null || records.isEmpty) return [];

    return records.map((record) {
      final exercise = _exerciseGuidIndex[record.workoutId] ??
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
