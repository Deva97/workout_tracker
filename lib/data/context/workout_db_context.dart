import '../../domain/models/daily_record.dart';
import '../../domain/models/daily_workout_entry.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/weight_record.dart';
import '../orm/excel_context.dart';
import '../orm/excel_query.dart';
import '../orm/excel_table.dart';

/// RDBMS mutation type in write-ahead log.
enum DbMutationType { add, update, delete }

/// Represents an individual mutation entry in the in-memory write-ahead log.
class DbMutationEntry {
  final DbMutationType type;
  final DailyRecord record;
  final DailyRecord? previousRecord;
  final DateTime timestamp;

  DbMutationEntry({
    required this.type,
    required this.record,
    this.previousRecord,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Strongly-typed Database Context for Workout Tracker app spreadsheets.
class WorkoutDbContext extends ExcelContext {
  ExcelTable<Exercise> _exercises;
  ExcelTable<DailyRecord> _dailyRecords;

  // High-performance O(1) in-memory lookup indexes (RDBMS Principles)
  final Map<String, Exercise> _exerciseGuidIndex = {};
  final Map<int, List<DailyRecord>> _recordsByDateKey = {};
  final Map<String, DailyRecord> _recordsByIdIndex = {};
  final Map<String, List<DailyRecord>> _recordsByWorkoutIdIndex = {};

  // In-memory Write-Ahead Log (WAL) / Mutation Journal
  final List<DbMutationEntry> _mutationJournal = [];

  /// Read-only view of in-memory mutation journal.
  List<DbMutationEntry> get mutationJournal => List.unmodifiable(_mutationJournal);

  /// Clears in-memory mutation journal entries.
  void clearMutationJournal() => _mutationJournal.clear();

  static int _dateKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  void _rebuildExerciseIndex() {
    _exerciseGuidIndex.clear();
    for (final ex in _exercises) {
      _exerciseGuidIndex[ex.guid] = ex;
    }
  }

  void _rebuildDailyRecordIndex() {
    _recordsByIdIndex.clear();
    _recordsByDateKey.clear();
    _recordsByWorkoutIdIndex.clear();

    for (final rec in _dailyRecords) {
      if (_dailyRecords.isTombstoned(rec.id)) continue;

      _recordsByIdIndex[rec.id] = rec;

      final key = _dateKey(rec.date);
      _recordsByDateKey.putIfAbsent(key, () => []).add(rec);

      _recordsByWorkoutIdIndex.putIfAbsent(rec.workoutId, () => []).add(rec);
    }
    for (final list in _recordsByDateKey.values) {
      list.sort((a, b) => a.set.compareTo(b.set));
    }
    for (final list in _recordsByWorkoutIdIndex.values) {
      list.sort((a, b) => a.date.compareTo(b.date));
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

  /// Point lookup by Primary Key ID in O(1) time.
  DailyRecord? getDailyRecordById(String id) {
    if (_dailyRecords.isTombstoned(id)) return null;
    return _recordsByIdIndex[id];
  }

  /// Binary search lower-bound helper to locate cutoff index in a date-sorted list in O(log N) time.
  static int binarySearchLowerBound(List<DailyRecord> records, DateTime cutoff) {
    int low = 0;
    int high = records.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (records[mid].date.isBefore(cutoff)) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  /// Fast retrieval of exercise history using Foreign Key index in O(1) + O(log K) binary search range slice.
  List<DailyRecord> getRecordsForExercise(String workoutId, {DateTime? since}) {
    final records = _recordsByWorkoutIdIndex[workoutId];
    if (records == null || records.isEmpty) return [];

    if (since == null) {
      return List.unmodifiable(records);
    }

    final cutoff = DateTime(since.year, since.month, since.day);
    final startIndex = binarySearchLowerBound(records, cutoff);
    if (startIndex >= records.length) return [];
    return records.sublist(startIndex);
  }

  /// Adds [record] to the daily record table with incremental O(1) index updates and WAL entry.
  void addDailyRecord(DailyRecord record) {
    _dailyRecords.add(record);
    _recordsByIdIndex[record.id] = record;

    final key = _dateKey(record.date);
    final dateList = _recordsByDateKey.putIfAbsent(key, () => []);
    dateList.add(record);
    dateList.sort((a, b) => a.set.compareTo(b.set));

    final workoutList = _recordsByWorkoutIdIndex.putIfAbsent(record.workoutId, () => []);
    workoutList.add(record);
    workoutList.sort((a, b) => a.date.compareTo(b.date));

    _mutationJournal.add(DbMutationEntry(type: DbMutationType.add, record: record));
  }

  /// Replaces the daily record table with [replacement].
  void replaceDailyRecords(Iterable<DailyRecord> replacement) {
    final entities = replacement.toList();
    _dailyRecords
      ..clear()
      ..clearTombstones()
      ..addAll(entities);
    _rebuildDailyRecordIndex();
  }

  /// Updates the first daily record matching [matches] using incremental index updates.
  bool updateDailyRecord(
    DailyRecord record,
    bool Function(DailyRecord existing) matches,
  ) {
    final oldRecord = _recordsByIdIndex[record.id];
    final updated = _dailyRecords.update(record, matches);
    if (updated) {
      if (oldRecord != null) {
        // Incremental index eviction of old entry
        final oldKey = _dateKey(oldRecord.date);
        _recordsByDateKey[oldKey]?.removeWhere((r) => r.id == oldRecord.id);
        _recordsByWorkoutIdIndex[oldRecord.workoutId]?.removeWhere((r) => r.id == oldRecord.id);
      }

      _recordsByIdIndex[record.id] = record;

      final newKey = _dateKey(record.date);
      final dateList = _recordsByDateKey.putIfAbsent(newKey, () => []);
      dateList.add(record);
      dateList.sort((a, b) => a.set.compareTo(b.set));

      final workoutList = _recordsByWorkoutIdIndex.putIfAbsent(record.workoutId, () => []);
      workoutList.add(record);
      workoutList.sort((a, b) => a.date.compareTo(b.date));

      _mutationJournal.add(DbMutationEntry(
        type: DbMutationType.update,
        record: record,
        previousRecord: oldRecord,
      ));
    }
    return updated;
  }

  /// Deletes daily records matching [matches] and updates indexes incrementally.
  int deleteDailyRecordsWhere(bool Function(DailyRecord record) matches) {
    final toDelete = _dailyRecords.where(matches).toList();
    if (toDelete.isEmpty) return 0;

    final count = _dailyRecords.deleteWhere(matches);
    for (final rec in toDelete) {
      _recordsByIdIndex.remove(rec.id);
      final key = _dateKey(rec.date);
      _recordsByDateKey[key]?.removeWhere((r) => r.id == rec.id);
      _recordsByWorkoutIdIndex[rec.workoutId]?.removeWhere((r) => r.id == rec.id);

      _mutationJournal.add(DbMutationEntry(type: DbMutationType.delete, record: rec));
    }
    return count;
  }

  /// Deletes a daily record by ID with optional soft deletion (tombstone) in O(1) time.
  bool deleteDailyRecordById(String id, {bool soft = false}) {
    final record = _recordsByIdIndex[id];
    if (record == null) return false;

    if (soft) {
      _dailyRecords.markTombstone(id);
      _recordsByIdIndex.remove(id);
      final key = _dateKey(record.date);
      _recordsByDateKey[key]?.removeWhere((r) => r.id == id);
      _recordsByWorkoutIdIndex[record.workoutId]?.removeWhere((r) => r.id == id);
      _mutationJournal.add(DbMutationEntry(type: DbMutationType.delete, record: record));
      return true;
    } else {
      return deleteDailyRecordsWhere((r) => r.id == id) > 0;
    }
  }

  /// Purges all tombstoned daily records physically from the table set.
  int vacuumDailyRecords() {
    return _dailyRecords.vacuum((r) => r.id);
  }

  /// Rolls back the most recent mutation from the in-memory write-ahead log.
  bool rollbackLastMutation() {
    if (_mutationJournal.isEmpty) return false;
    final last = _mutationJournal.removeLast();
    switch (last.type) {
      case DbMutationType.add:
        _dailyRecords.deleteWhere((r) => r.id == last.record.id);
        _recordsByIdIndex.remove(last.record.id);
        _recordsByDateKey[_dateKey(last.record.date)]?.removeWhere((r) => r.id == last.record.id);
        _recordsByWorkoutIdIndex[last.record.workoutId]?.removeWhere((r) => r.id == last.record.id);
        return true;
      case DbMutationType.update:
        if (last.previousRecord != null) {
          updateDailyRecord(last.previousRecord!, (r) => r.id == last.record.id);
          _mutationJournal.removeLast(); // pop recursive update journal entry
        }
        return true;
      case DbMutationType.delete:
        addDailyRecord(last.record);
        _mutationJournal.removeLast(); // pop recursive add journal entry
        return true;
    }
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

  /// Save daily records table to [Daily_record.xlsx] byte stream with physical date-clustered ordering.
  List<int> saveDailyRecordToBytes({bool sortClustered = true}) {
    vacuumDailyRecords();
    if (sortClustered && _dailyRecords.isNotEmpty) {
      final sortedList = _dailyRecords.toList()..sort((a, b) {
        final dateComp = a.date.compareTo(b.date);
        if (dateComp != 0) return dateComp;
        return a.set.compareTo(b.set);
      });
      _dailyRecords = ExcelTable<DailyRecord>(
        sheetName: _dailyRecords.sheetName,
        mapper: DailyRecord.excelMapper,
        initialEntities: sortedList,
      );
    }
    return saveTableToBytes<DailyRecord>(_dailyRecords);
  }

  /// Encodes daily records into multi-sheet partitioned Excel workbook bytes.
  /// Records are partitioned across sheets (e.g. Active vs Archive_YYYY).
  List<int> savePartitionedDailyRecordToBytes({bool sortClustered = true}) {
    vacuumDailyRecords();
    if (_dailyRecords.isEmpty) {
      return saveDailyRecordToBytes(sortClustered: sortClustered);
    }

    final currentYear = DateTime.now().year;
    final partitions = <String, List<DailyRecord>>{};

    for (final rec in _dailyRecords) {
      final year = rec.date.year;
      final sheetName = (year == currentYear) ? 'Sheet1' : 'Archive_$year';
      partitions.putIfAbsent(sheetName, () => []).add(rec);
    }

    final tablePartitions = <String, ExcelTable<DailyRecord>>{};
    for (final entry in partitions.entries) {
      if (sortClustered) {
        entry.value.sort((a, b) {
          final c = a.date.compareTo(b.date);
          if (c != 0) return c;
          return a.set.compareTo(b.set);
        });
      }
      tablePartitions[entry.key] = ExcelTable<DailyRecord>(
        sheetName: entry.key,
        mapper: DailyRecord.excelMapper,
        initialEntities: entry.value,
      );
    }

    return savePartitionedTablesToBytes<DailyRecord>(tablePartitions);
  }

  /// Loads daily records from partitioned Excel workbook bytes.
  /// Transparently falls back to single-sheet parsing if file is non-partitioned.
  void loadPartitionedDailyRecordsFromBytes(List<int> bytes, {DateTime? since}) {
    final partitioned = loadPartitionedTablesFromBytes<DailyRecord>(
      bytes: bytes,
      mapper: DailyRecord.excelMapper,
    );

    final allRecords = <DailyRecord>[];
    for (final table in partitioned.values) {
      allRecords.addAll(table);
    }

    if (since != null) {
      final earliestDate = DateTime(since.year, since.month, since.day);
      _dailyRecords = ExcelTable<DailyRecord>(
        sheetName: 'Sheet1',
        mapper: DailyRecord.excelMapper,
        initialEntities: allRecords.where((r) => !r.date.isBefore(earliestDate)).toList(),
      );
    } else {
      _dailyRecords = ExcelTable<DailyRecord>(
        sheetName: 'Sheet1',
        mapper: DailyRecord.excelMapper,
        initialEntities: allRecords,
      );
    }
    _rebuildDailyRecordIndex();
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

  /// Create default initial empty [Body_weight.xlsx] file bytes.
  List<int> createDefaultBodyWeightBytes() {
    final emptyTable = ExcelTable<WeightRecord>(
      sheetName: 'Sheet1',
      mapper: WeightRecord.excelMapper,
    );
    return saveTableToBytes<WeightRecord>(emptyTable);
  }
}
