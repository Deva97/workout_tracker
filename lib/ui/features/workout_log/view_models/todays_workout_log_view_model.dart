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

  ValueListenable<SyncState> get syncStateListenable => _workoutRepository.syncStateListenable;

  bool isPersonalRecord(DailyWorkoutEntry entry) {
    return _prRecordIds.contains(entry.record.id);
  }

  /// Returns the most recently logged set for this exercise (from today or recent cache)
  DailyRecord? getLastRecordedSet(String exerciseGuid) {
    final matches = _todaysEntries.where((e) => e.exercise.guid == exerciseGuid).toList();
    if (matches.isNotEmpty) {
      matches.sort((a, b) => a.record.set.compareTo(b.record.set));
      return matches.last.record;
    }
    return _lastRecordedCache[exerciseGuid];
  }

  Future<void> loadTodaysWorkoutLog() async {
    // 1. Immediately render cached data if present for zero-latency screen load
    final cachedExercises = _exercisesUseCase.getCachedExercises();
    final cachedEntries = _getTodaysWorkoutUseCase.getCachedEntries();
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
      final workoutData = await _getTodaysWorkoutUseCase.execute();
      _availableExercises = _exercisesUseCase.getCachedExercises();
      if (_availableExercises.isEmpty) {
        _availableExercises = await _exercisesUseCase.getExercises();
      }
      _todaysEntries = workoutData.entries;
      _recalculatePersonalRecords();

      // Warm up historical cache for previous set lookups
      final weeklyRecords = await _workoutRepository.getWeeklyDailyRecords();
      for (final rec in weeklyRecords) {
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

  Future<void> saveSet(DailyRecord record) async {
    await _manageSetUseCase.addSet(record);
    _lastRecordedCache[record.workoutId] = record;
    _todaysEntries = _getTodaysWorkoutUseCase.getCachedEntries();
    _recalculatePersonalRecords();
    notifyListeners();
  }

  Future<void> editSet(DailyRecord record) async {
    await _manageSetUseCase.editSet(record);
    _lastRecordedCache[record.workoutId] = record;
    _todaysEntries = _getTodaysWorkoutUseCase.getCachedEntries();
    _recalculatePersonalRecords();
    notifyListeners();
  }

  Future<void> deleteSet(DailyWorkoutEntry entry) async {
    await _manageSetUseCase.deleteSet(entry.record.id);
    _todaysEntries = _getTodaysWorkoutUseCase.getCachedEntries();
    _recalculatePersonalRecords();
    notifyListeners();
  }

  Future<void> restoreSet(DailyRecord record) async {
    await _manageSetUseCase.addSet(record);
    _lastRecordedCache[record.workoutId] = record;
    _todaysEntries = _getTodaysWorkoutUseCase.getCachedEntries();
    _recalculatePersonalRecords();
    notifyListeners();
  }

  Future<SyncState> manualSync() async {
    return _workoutRepository.manualSyncToExcel();
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
