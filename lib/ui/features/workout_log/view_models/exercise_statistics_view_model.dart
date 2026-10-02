import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../../data/repositories/exercise_repository_impl.dart';
import '../../../../data/repositories/workout_repository_impl.dart';
import 'package:workout_tracker/domain/models/daily_record.dart';
import 'package:workout_tracker/domain/models/exercise.dart';
import '../../../../domain/use_cases/get_exercise_statistics_use_case.dart';
import '../../../../domain/use_cases/manage_exercises_use_case.dart';
import '../views/widgets/strength_trend_chart.dart';

enum StatsViewMode {
  graph,
  details,
}

class TimeFrameOption {
  final String label;
  final int days;

  const TimeFrameOption({required this.label, required this.days});
}

class ExerciseStatsCacheEntry {
  final List<DailyRecord> rawHistoryRecords;
  final List<StrengthChartPoint> chartPoints;
  final double peakScore;
  final int totalSetsInPeriod;
  final int totalSessionsInPeriod;
  final double trendPercentage;

  const ExerciseStatsCacheEntry({
    required this.rawHistoryRecords,
    required this.chartPoints,
    required this.peakScore,
    required this.totalSetsInPeriod,
    required this.totalSessionsInPeriod,
    required this.trendPercentage,
  });
}

class ExerciseStatisticsViewModel extends ChangeNotifier {
  final ManageExercisesUseCase _exercisesUseCase;
  final GetExerciseStatisticsUseCase _statisticsUseCase;

  static const List<TimeFrameOption> timeFrames = [
    TimeFrameOption(label: '1 Month', days: 30),
    TimeFrameOption(label: '2 Months', days: 60),
    TimeFrameOption(label: '3 Months', days: 90),
    TimeFrameOption(label: '6 Months', days: 180),
    TimeFrameOption(label: '1 Year', days: 365),
  ];

  ExerciseStatisticsViewModel({
    ManageExercisesUseCase? exercisesUseCase,
    GetExerciseStatisticsUseCase? statisticsUseCase,
  })  : _exercisesUseCase = exercisesUseCase ??
            ManageExercisesUseCase(exerciseRepository: ExerciseRepositoryImpl()),
        _statisticsUseCase = statisticsUseCase ??
            GetExerciseStatisticsUseCase(workoutRepository: WorkoutRepositoryImpl());

  List<Exercise> _availableExercises = [];
  List<Exercise> get availableExercises => _availableExercises;

  Exercise? _selectedExercise;
  Exercise? get selectedExercise => _selectedExercise;

  StatsViewMode _currentViewMode = StatsViewMode.graph;
  StatsViewMode get currentViewMode => _currentViewMode;

  TimeFrameOption _selectedTimeFrame = timeFrames.first;
  TimeFrameOption get selectedTimeFrame => _selectedTimeFrame;

  ChartMetricType _selectedMetric = ChartMetricType.estimated1RM;
  ChartMetricType get selectedMetric => _selectedMetric;

  List<StrengthChartPoint> _chartPoints = [];
  List<StrengthChartPoint> get chartPoints => _chartPoints;

  List<DailyRecord> _rawHistoryRecords = [];
  List<DailyRecord> get rawHistoryRecords => _rawHistoryRecords;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  double _peakScore = 0.0;
  double get peakScore => _peakScore;

  int _totalSetsInPeriod = 0;
  int get totalSetsInPeriod => _totalSetsInPeriod;

  int _totalSessionsInPeriod = 0;
  int get totalSessionsInPeriod => _totalSessionsInPeriod;

  double _trendPercentage = 0.0;
  double get trendPercentage => _trendPercentage;

  int get selectedDays => _selectedTimeFrame.days;

  // In-memory cache for computed exercise statistics keyed by exerciseGuid_days
  final Map<String, ExerciseStatsCacheEntry> _statsCache = {};

  Future<void> init(String? initialExerciseGuid) async {
    _isLoading = true;
    notifyListeners();

    try {
      _availableExercises = _exercisesUseCase.getCachedExercises();
      if (_availableExercises.isEmpty) {
        _availableExercises = await _exercisesUseCase.getExercises();
      }
      if (_availableExercises.isNotEmpty) {
        if (initialExerciseGuid != null) {
          _selectedExercise = _availableExercises.firstWhere(
            (e) => e.guid == initialExerciseGuid,
            orElse: () => _availableExercises.first,
          );
        } else {
          _selectedExercise = _availableExercises.first;
        }
        await loadStatsForSelectedExercise();
      } else {
        _isLoading = false;
        notifyListeners();
      }
    } catch (_) {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setViewMode(StatsViewMode mode) {
    if (_currentViewMode != mode) {
      _currentViewMode = mode;
      notifyListeners();
    }
  }

  void setSelectedMetric(ChartMetricType metric) {
    if (_selectedMetric != metric) {
      _selectedMetric = metric;
      notifyListeners();
    }
  }

  Future<void> selectExercise(Exercise exercise) async {
    if (_selectedExercise?.guid == exercise.guid) return;
    _selectedExercise = exercise;
    await loadStatsForSelectedExercise();
  }

  Future<void> selectTimeFrame(TimeFrameOption timeFrame) async {
    if (_selectedTimeFrame.label == timeFrame.label) return;
    _selectedTimeFrame = timeFrame;
    await loadStatsForSelectedExercise();
  }

  Future<void> selectDays(int days) async {
    final matched = timeFrames.firstWhere(
      (tf) => tf.days == days,
      orElse: () => TimeFrameOption(label: '$days Days', days: days),
    );
    await selectTimeFrame(matched);
  }

  Future<void> loadStatsForSelectedExercise() async {
    if (_selectedExercise == null) {
      _chartPoints = [];
      _rawHistoryRecords = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    final cacheKey = '${_selectedExercise!.guid}_${_selectedTimeFrame.days}';
    final cached = _statsCache[cacheKey];
    if (cached != null) {
      _rawHistoryRecords = cached.rawHistoryRecords;
      _chartPoints = cached.chartPoints;
      _peakScore = cached.peakScore;
      _totalSetsInPeriod = cached.totalSetsInPeriod;
      _totalSessionsInPeriod = cached.totalSessionsInPeriod;
      _trendPercentage = cached.trendPercentage;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final summary = await _statisticsUseCase.execute(
        _selectedExercise!.guid,
        days: _selectedTimeFrame.days,
      );

      final history = summary.records;

      // Group records by calendar date without creating DateFormat objects in loop
      final Map<String, List<DailyRecord>> groupedByDate = {};
      for (final r in history) {
        final key =
            '${r.date.year}-${r.date.month.toString().padLeft(2, '0')}-${r.date.day.toString().padLeft(2, '0')}';
        groupedByDate.putIfAbsent(key, () => []).add(r);
      }

      final List<StrengthChartPoint> points = [];
      int totalSets = 0;
      double maxScore = 0.0;

      for (final entry in groupedByDate.entries) {
        final dateRecords = entry.value;
        final sessionDate = dateRecords.first.date;
        final sessionSets = dateRecords.length;
        final sessionReps = dateRecords.fold<int>(0, (sum, r) => sum + r.reps);

        double sessionMaxScore = 0.0;
        double sessionMaxWeight = 0.0;
        double sessionTotalVolume = 0.0;
        int sessionMaxReps = 0;

        for (final r in dateRecords) {
          final rirBonus = max(0.0, 10.0 - r.rir) * 0.5;
          final setScore = r.weight > 0
              ? r.weight * (1.0 + (r.reps + rirBonus) / 30.0)
              : r.reps + rirBonus;
          if (setScore > sessionMaxScore) {
            sessionMaxScore = setScore;
          }
          if (r.weight > sessionMaxWeight) {
            sessionMaxWeight = r.weight;
          }
          sessionTotalVolume += (r.weight * r.reps);
          if (r.reps > sessionMaxReps) {
            sessionMaxReps = r.reps;
          }
        }

        if (sessionMaxScore > maxScore) {
          maxScore = sessionMaxScore;
        }
        totalSets += sessionSets;

        points.add(StrengthChartPoint(
          date: sessionDate,
          score: sessionMaxScore,
          totalSets: sessionSets,
          totalReps: sessionReps,
          maxWeight: sessionMaxWeight,
          totalVolume: sessionTotalVolume,
          maxReps: sessionMaxReps,
        ));
      }

      // Sort points chronologically
      points.sort((a, b) => a.date.compareTo(b.date));

      // Compute trend percentage change
      double trend = 0.0;
      if (points.length >= 2) {
        final first = points.first.score;
        final last = points.last.score;
        if (first > 0) {
          trend = ((last - first) / first) * 100.0;
        }
      }

      final cacheEntry = ExerciseStatsCacheEntry(
        rawHistoryRecords: history,
        chartPoints: points,
        peakScore: maxScore,
        totalSetsInPeriod: totalSets,
        totalSessionsInPeriod: points.length,
        trendPercentage: trend,
      );
      _statsCache[cacheKey] = cacheEntry;

      _rawHistoryRecords = history;
      _chartPoints = points;
      _peakScore = maxScore;
      _totalSetsInPeriod = totalSets;
      _totalSessionsInPeriod = points.length;
      _trendPercentage = trend;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
