import 'package:flutter/foundation.dart';
import '../../../../data/repositories/exercise_repository_impl.dart';
import '../../../../data/repositories/workout_repository_impl.dart';
import '../../../../data/repositories/workout_split_repository_impl.dart';
import 'package:workout_tracker/domain/models/daily_record.dart';
import 'package:workout_tracker/domain/models/daily_workout_entry.dart';
import 'package:workout_tracker/domain/models/exercise.dart';
import '../../../../domain/repositories/auth_repository.dart' show SyncState;
import '../../../../domain/repositories/workout_repository.dart';
import '../../../../domain/use_cases/get_todays_workout_use_case.dart';
import '../../../../domain/use_cases/manage_exercises_use_case.dart';
import '../../../../domain/use_cases/manage_workout_set_use_case.dart';

class TodaysWorkoutLogViewModel extends ChangeNotifier {
  final GetTodaysWorkoutUseCase _getTodaysWorkoutUseCase;
  final ManageWorkoutSetUseCase _manageSetUseCase;
  final ManageExercisesUseCase _exercisesUseCase;
  final WorkoutRepository _workoutRepository;

  TodaysWorkoutLogViewModel({
    GetTodaysWorkoutUseCase? getTodaysWorkoutUseCase,
    ManageWorkoutSetUseCase? manageSetUseCase,
    ManageExercisesUseCase? exercisesUseCase,
    WorkoutRepository? workoutRepository,
  })  : _workoutRepository = workoutRepository ?? WorkoutRepositoryImpl(),
        _getTodaysWorkoutUseCase = getTodaysWorkoutUseCase ??
            GetTodaysWorkoutUseCase(
              workoutRepository: workoutRepository ?? WorkoutRepositoryImpl(),
              splitRepository: WorkoutSplitRepositoryImpl(),
            ),
        _manageSetUseCase = manageSetUseCase ??
            ManageWorkoutSetUseCase(workoutRepository: workoutRepository ?? WorkoutRepositoryImpl()),
        _exercisesUseCase = exercisesUseCase ??
            ManageExercisesUseCase(exerciseRepository: ExerciseRepositoryImpl());

  DateTime _selectedDate = _normalizeDate(DateTime.now());
  DateTime get selectedDate => _selectedDate;

  List<DateTime> _availableDates = [_normalizeDate(DateTime.now())];
  List<DateTime> get availableDates => List.unmodifiable(_availableDates);

  List<DailyWorkoutEntry> _todaysEntries = [];
  List<DailyWorkoutEntry> get todaysEntries => _todaysEntries;

  List<Exercise> _availableExercises = [];
  List<Exercise> get availableExercises => _availableExercises;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  // Set of record IDs that represent personal records (peak 1RM for that exercise)
  final Set<String> _prRecordIds = {};

  // In-memory cache for previous logged set per exercise
  final Map<String, DailyRecord> _lastRecordedCache = {};

  // Token tracking the latest requested date to discard superseded background fetches
  DateTime? _activeBackgroundFetchDate;

  ValueListenable<SyncState> get syncStateListenable => _workoutRepository.syncStateListenable;

  static DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool get isViewingToday => isSameDay(_selectedDate, DateTime.now());

  int get currentDateIndex => _availableDates.indexWhere((d) => isSameDay(d, _selectedDate));

  /// True if there is an older workout record session before the currently viewed date.
  bool get canGoPrevious {
    final idx = currentDateIndex;
    return idx >= 0 && idx < _availableDates.length - 1;
  }

  /// True if there is a newer workout record session after the currently viewed date.
  bool get canGoNext {
    final idx = currentDateIndex;
    return idx > 0;
  }

  bool isPersonalRecord(DailyWorkoutEntry entry) {
    return _prRecordIds.contains(entry.record.id);
  }

  /// Returns the most recently logged set for this exercise (from current date or recent cache)
  DailyRecord? getLastRecordedSet(String exerciseGuid) {
    final matches = _todaysEntries.where((e) => e.exercise.guid == exerciseGuid).toList();
    if (matches.isNotEmpty) {
      matches.sort((a, b) => a.record.set.compareTo(b.record.set));
      return matches.last.record;
    }
    return _lastRecordedCache[exerciseGuid];
  }

  /// Synchronously returns cached entries for a given date from memory.
  List<DailyWorkoutEntry> getEntriesForDate(DateTime date) {
    return _getTodaysWorkoutUseCase.getCachedEntries(date);
  }

  void _rebuildAvailableDates(List<DailyRecord> records) {
    final today = _normalizeDate(DateTime.now());
    final set = <DateTime>{today, _selectedDate};
    for (final r in records) {
      set.add(_normalizeDate(r.date));
    }
    _availableDates = set.toList()..sort((a, b) => b.compareTo(a)); // Descending: today first, then past
  }

  Future<void> loadTodaysWorkoutLog() async {
    // 1. Immediately render cached data if present for zero-latency screen load
    final cachedExercises = _exercisesUseCase.getCachedExercises();
    final cachedEntries = _getTodaysWorkoutUseCase.getCachedEntries(_selectedDate);
    final cachedDailyRecords = _workoutRepository.getCachedDailyRecords();
    _rebuildAvailableDates(cachedDailyRecords);

    for (final rec in cachedDailyRecords) {
      final existing = _lastRecordedCache[rec.workoutId];
      if (existing == null ||
          rec.date.isAfter(existing.date) ||
          (rec.date.isAtSameMomentAs(existing.date) && rec.set > existing.set)) {
        _lastRecordedCache[rec.workoutId] = rec;
      }
    }

    if (cachedExercises.isNotEmpty || cachedEntries.isNotEmpty) {
      _availableExercises = cachedExercises;
      _todaysEntries = cachedEntries;
      _isLoading = false;
      _recalculatePersonalRecords();
      notifyListeners();
    } else {
      _isLoading = true;
      notifyListeners();
    }

    // 2. Fetch fresh entries from Drive / background sync without blocking initial display
    try {
      final workoutData = await _getTodaysWorkoutUseCase.execute(_selectedDate);
      _availableExercises = _exercisesUseCase.getCachedExercises();
      if (_availableExercises.isEmpty) {
        _availableExercises = await _exercisesUseCase.getExercises();
      }
      _todaysEntries = workoutData.entries;
      _recalculatePersonalRecords();

      // Warm up historical cache & available dates
      final weeklyRecords = await _workoutRepository.getWeeklyDailyRecords();
      final allRecords = <DailyRecord>{
        ..._workoutRepository.getCachedDailyRecords(),
        ...weeklyRecords,
      }.toList();
      _rebuildAvailableDates(allRecords);

      for (final rec in allRecords) {
        final existing = _lastRecordedCache[rec.workoutId];
        if (existing == null ||
            rec.date.isAfter(existing.date) ||
            (rec.date.isAtSameMomentAs(existing.date) && rec.set > existing.set)) {
          _lastRecordedCache[rec.workoutId] = rec;
        }
      }
    } catch (_) {
      // Background sync errors don't crash display of cached data
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Switch to a new date, loading cached entries instantly, then refreshing in background.
  Future<void> changeDate(DateTime newDate) async {
    final normalized = _normalizeDate(newDate);
    if (isSameDay(_selectedDate, normalized) && !_isLoading) return;

    _selectedDate = normalized;
    if (!_availableDates.any((d) => isSameDay(d, _selectedDate))) {
      _availableDates.add(_selectedDate);
      _availableDates.sort((a, b) => b.compareTo(a));
    }

    // Instant local render
    _todaysEntries = _getTodaysWorkoutUseCase.getCachedEntries(_selectedDate);
    _recalculatePersonalRecords();
    notifyListeners();

    final fetchTarget = normalized;
    _activeBackgroundFetchDate = fetchTarget;

    // Background fresh fetch for the date (aborts if superseded by a subsequent swipe)
    try {
      final workoutData = await _getTodaysWorkoutUseCase.execute(fetchTarget);
      if (_activeBackgroundFetchDate != fetchTarget) return; // Superseded
      _todaysEntries = workoutData.entries;
      _recalculatePersonalRecords();

      final weeklyRecords = await _workoutRepository.getWeeklyDailyRecords();
      if (_activeBackgroundFetchDate != fetchTarget) return; // Superseded
      final allRecords = <DailyRecord>{
        ..._workoutRepository.getCachedDailyRecords(),
        ...weeklyRecords,
      }.toList();
      _rebuildAvailableDates(allRecords);
    } catch (_) {
      // Ignore background errors
    } finally {
      if (_activeBackgroundFetchDate == fetchTarget) {
        notifyListeners();
      }
    }
  }

  /// Navigate to previous (older) workout record date. Returns false if at oldest boundary.
  Future<bool> goToPreviousRecord() async {
    if (!canGoPrevious) return false;
    final targetIndex = currentDateIndex + 1;
    await changeDate(_availableDates[targetIndex]);
    return true;
  }

  /// Navigate to next (newer) workout record date. Returns false if at newest boundary (Today).
  Future<bool> goToNextRecord() async {
    if (!canGoNext) return false;
    final targetIndex = currentDateIndex - 1;
    await changeDate(_availableDates[targetIndex]);
    return true;
  }

  /// Quickly jump back to Today.
  Future<void> goToToday() async {
    await changeDate(DateTime.now());
  }

  Future<void> saveSet(DailyRecord record) async {
    await _manageSetUseCase.addSet(record);
    _lastRecordedCache[record.workoutId] = record;
    final recDate = _normalizeDate(record.date);
    if (!_availableDates.any((d) => isSameDay(d, recDate))) {
      _availableDates.add(recDate);
      _availableDates.sort((a, b) => b.compareTo(a));
    }
    _todaysEntries = _getTodaysWorkoutUseCase.getCachedEntries(_selectedDate);
    _recalculatePersonalRecords();
    notifyListeners();
  }

  Future<void> editSet(DailyRecord record) async {
    await _manageSetUseCase.editSet(record);
    _lastRecordedCache[record.workoutId] = record;
    _todaysEntries = _getTodaysWorkoutUseCase.getCachedEntries(_selectedDate);
    _recalculatePersonalRecords();
    notifyListeners();
  }

  Future<void> deleteSet(DailyWorkoutEntry entry) async {
    await _manageSetUseCase.deleteSet(entry.record.id);
    _todaysEntries = _getTodaysWorkoutUseCase.getCachedEntries(_selectedDate);
    _recalculatePersonalRecords();
    notifyListeners();
  }

  Future<void> restoreSet(DailyRecord record) async {
    await _manageSetUseCase.addSet(record);
    _lastRecordedCache[record.workoutId] = record;
    _todaysEntries = _getTodaysWorkoutUseCase.getCachedEntries(_selectedDate);
    _recalculatePersonalRecords();
    notifyListeners();
  }

  Future<SyncState> manualSync() async {
    return _workoutRepository.manualSyncToExcel();
  }

  /// Add a set and immediately await synchronization with Google Drive Excel.
  Future<SyncState> saveSetAndSync(DailyRecord record) async {
    await saveSet(record);
    return manualSync();
  }

  /// Roll back an added set if sync fails and the user cancels.
  Future<void> rollbackAddedSet(DailyRecord record) async {
    await _manageSetUseCase.deleteSet(record.id);
    _todaysEntries = _getTodaysWorkoutUseCase.getCachedEntries(_selectedDate);
    _recalculatePersonalRecords();

    final hasRecords = _getTodaysWorkoutUseCase.getCachedEntries(_selectedDate).isNotEmpty;
    final isToday = isSameDay(_selectedDate, DateTime.now());
    if (!hasRecords && !isToday) {
      _availableDates.removeWhere((d) => isSameDay(d, _selectedDate));
      if (_availableDates.isEmpty) {
        _availableDates.add(_normalizeDate(DateTime.now()));
      }
      _selectedDate = _availableDates.first;
      _todaysEntries = _getTodaysWorkoutUseCase.getCachedEntries(_selectedDate);
    }

    notifyListeners();
  }

  /// Edit a set and immediately await synchronization with Google Drive Excel.
  Future<SyncState> editSetAndSync(DailyRecord record) async {
    await editSet(record);
    return manualSync();
  }

  /// Roll back an edited set if sync fails and the user cancels.
  Future<void> rollbackEditedSet(DailyRecord previousRecord) async {
    await _manageSetUseCase.editSet(previousRecord);
    _todaysEntries = _getTodaysWorkoutUseCase.getCachedEntries(_selectedDate);
    _recalculatePersonalRecords();
    notifyListeners();
  }

  /// Delete a set and immediately await synchronization with Google Drive Excel.
  Future<SyncState> deleteSetAndSync(DailyWorkoutEntry entry) async {
    await deleteSet(entry);
    return manualSync();
  }

  /// Roll back a deleted set if sync fails and the user cancels.
  Future<void> rollbackDeletedSet(DailyRecord record) async {
    await restoreSet(record);
  }

  /// Re-attempt synchronization with Google Drive Excel.
  Future<SyncState> retrySync() async {
    return manualSync();
  }

  void _recalculatePersonalRecords() {
    _prRecordIds.clear();
    final Map<String, List<DailyWorkoutEntry>> byExercise = {};
    for (final entry in _todaysEntries) {
      byExercise.putIfAbsent(entry.exercise.guid, () => []).add(entry);
    }

    for (final entries in byExercise.values) {
      if (entries.isEmpty) continue;
      double peakScore = 0.0;
      DailyWorkoutEntry? bestEntry;
      for (final entry in entries) {
        final weight = entry.record.weight;
        final reps = entry.record.reps;
        if (reps <= 0) continue;
        final score = weight > 0 ? weight * (1.0 + reps / 30.0) : reps.toDouble();
        if (score > peakScore) {
          peakScore = score;
          bestEntry = entry;
        }
      }
      if (bestEntry != null) {
        _prRecordIds.add(bestEntry.record.id);
      }
    }
  }
}
