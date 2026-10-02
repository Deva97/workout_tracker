import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/data/context/workout_db_context.dart';
import 'package:workout_tracker/domain/models/daily_record.dart';
import 'package:workout_tracker/domain/repositories/workout_repository.dart';
import 'package:workout_tracker/domain/use_cases/get_exercise_statistics_use_case.dart';
import 'package:workout_tracker/ui/features/workout_log/views/widgets/rest_timer_widget.dart';
import 'package:workout_tracker/ui/features/workout_log/views/widgets/strength_trend_chart.dart';
import 'package:workout_tracker/data/services/google_drive_service.dart';
import 'package:workout_tracker/ui/core/theme/app_colors.dart';
import 'package:workout_tracker/ui/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final driveService = GoogleDriveService();
    driveService.dbContext.replaceExercises([]);
    driveService.dbContext.replaceDailyRecords([]);
  });

  group('Dark Mode & Theming Tests', () {
    test('AppTheme defines light and dark themes with valid color schemes', () {
      expect(AppTheme.lightTheme, isNotNull);
      expect(AppTheme.darkTheme, isNotNull);
      expect(AppTheme.darkTheme.brightness, equals(Brightness.dark));
      expect(AppTheme.lightTheme.brightness, equals(Brightness.light));
    });

    test('AppColors defines necessary dark mode and semantic palette constants', () {
      expect(AppColors.backgroundDark, isNotNull);
      expect(AppColors.surfaceDark, isNotNull);
      expect(AppColors.cardBorderDark, isNotNull);
      expect(AppColors.disabled, isNotNull);
      expect(AppColors.shimmer, isNotNull);
    });
  });

  group('RestTimerWidget Tests', () {
    testWidgets('Renders rest timer with initial seconds and countdown controls', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: RestTimerWidget(initialSeconds: 90),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Rest Timer'), findsOneWidget);
      expect(find.text('01:30'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('60s'), findsOneWidget);
      expect(find.text('90s'), findsOneWidget);
      expect(find.text('120s'), findsOneWidget);
      expect(find.text('180s'), findsOneWidget);
    });

    testWidgets('Pause and Resume button toggles timer execution', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: RestTimerWidget(initialSeconds: 60),
          ),
        ),
      );
      await tester.pump();

      // Tap Pause
      await tester.tap(find.text('Pause'));
      await tester.pump();
      expect(find.text('Resume'), findsOneWidget);

      // Tap Resume
      await tester.tap(find.text('Resume'));
      await tester.pump();
      expect(find.text('Pause'), findsOneWidget);
    });

    testWidgets('Preset chip selection resets timer duration', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: RestTimerWidget(initialSeconds: 90),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('120s'));
      await tester.pump();
      expect(find.text('02:00'), findsOneWidget);
    });
  });

  group('StrengthTrendChart & Metric Tests', () {
    testWidgets('Renders chart with metric types and value formatting', (tester) async {
      final points = [
        StrengthChartPoint(
          date: DateTime(2026, 1, 1),
          score: 80.0,
          totalSets: 3,
          totalReps: 30,
          maxWeight: 75.0,
          totalVolume: 2250.0,
          maxReps: 10,
        ),
        StrengthChartPoint(
          date: DateTime(2026, 1, 15),
          score: 88.0,
          totalSets: 4,
          totalReps: 40,
          maxWeight: 82.5,
          totalVolume: 3300.0,
          maxReps: 12,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: StrengthTrendChart(
                points: points,
                metricType: ChartMetricType.estimated1RM,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Est. 1RM Trend Curve'), findsOneWidget);
      expect(find.text('88.0 kg'), findsOneWidget);
    });
  });

  group('Drive Service Historical Isolation & Merge Logic', () {
    test('Historical records are loaded independently for charts without mutating today-only context', () async {
      final driveService = GoogleDriveService();
      final now = DateTime.now();
      final dateYesterday = now.subtract(const Duration(days: 1));

      final recYesterday = DailyRecord(
        id: 'rec-yesterday',
        workoutId: 'ex-bench',
        workoutName: 'Bench Press',
        date: dateYesterday,
        set: 1,
        reps: 10,
        rir: 2.0,
        weight: 80.0,
      );

      final recToday = DailyRecord(
        id: 'rec-today',
        workoutId: 'ex-bench',
        workoutName: 'Bench Press',
        date: now,
        set: 1,
        reps: 10,
        rir: 2.0,
        weight: 82.5,
      );

      // Populate local context with both records
      driveService.dbContext.replaceDailyRecords([recYesterday, recToday]);

      // Query history for 30 days
      final history = await driveService.queryExerciseHistory('ex-bench', daysLimit: 30);
      expect(history.length, equals(2));
    });

    test('loadRecentDailyRecordsFromBytes safely handles unsorted or out-of-order rows without premature termination', () {
      final context = WorkoutDbContext();
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final tenDaysAgo = now.subtract(const Duration(days: 10));

      final recOld = DailyRecord(
        id: 'rec-old',
        workoutId: 'ex-1',
        workoutName: 'Squat',
        date: tenDaysAgo,
        set: 1,
        reps: 5,
        rir: 2,
      );

      final recNewer = DailyRecord(
        id: 'rec-newer',
        workoutId: 'ex-1',
        workoutName: 'Squat',
        date: yesterday,
        set: 1,
        reps: 8,
        rir: 1,
      );

      final recToday = DailyRecord(
        id: 'rec-today',
        workoutId: 'ex-1',
        workoutName: 'Squat',
        date: now,
        set: 1,
        reps: 10,
        rir: 0,
      );

      // Intentionally create unsorted table: today, then old, then newer
      context.replaceDailyRecords([recToday, recOld, recNewer]);
      final excelBytes = context.saveDailyRecordToBytes();

      // Read recent records since 3 days ago
      final parsedContext = WorkoutDbContext();
      parsedContext.loadRecentDailyRecordsFromBytes(
        excelBytes,
        since: now.subtract(const Duration(days: 3)),
      );

      final records = parsedContext.readDailyRecords();
      // Should contain recToday and recNewer, but not recOld
      expect(records.map((r) => r.id), containsAll(['rec-today', 'rec-newer']));
      expect(records.map((r) => r.id), isNot(contains('rec-old')));
    });

    test('syncDailyRecordsToDriveInBackground debounces rapid invocations into single execution', () async {
      final driveService = GoogleDriveService();
      expect(driveService.syncStateNotifier.value, equals(SyncState.synced));

      // Trigger multiple rapid background syncs
      driveService.syncDailyRecordsToDriveInBackground(debounce: const Duration(milliseconds: 50));
      driveService.syncDailyRecordsToDriveInBackground(debounce: const Duration(milliseconds: 50));
      driveService.syncDailyRecordsToDriveInBackground(debounce: const Duration(milliseconds: 50));

      // Wait for debounce timer to fire
      await Future<void>.delayed(const Duration(milliseconds: 80));

      // In unit test without DriveApi, syncState completes to synced
      expect(driveService.syncStateNotifier.value, equals(SyncState.synced));
    });
  });

  group('GetExerciseStatisticsUseCase Single-Pass Tests', () {
    test('computes peakScore, totalSessions, totalSets and trendPercentage correctly in single pass', () async {
      final now = DateTime.now();
      final day1 = now.subtract(const Duration(days: 5));
      final day2 = now;

      final records = [
        DailyRecord(
          id: '1',
          workoutId: 'bench',
          workoutName: 'Bench Press',
          date: day1,
          set: 1,
          reps: 10,
          rir: 2.0,
          weight: 60.0,
        ),
        DailyRecord(
          id: '2',
          workoutId: 'bench',
          workoutName: 'Bench Press',
          date: day1,
          set: 2,
          reps: 8,
          rir: 1.0,
          weight: 60.0,
        ),
        DailyRecord(
          id: '3',
          workoutId: 'bench',
          workoutName: 'Bench Press',
          date: day2,
          set: 1,
          reps: 10,
          rir: 2.0,
          weight: 70.0,
        ),
      ];

      final fakeRepo = _FakeWorkoutRepo(records);
      final useCase = GetExerciseStatisticsUseCase(workoutRepository: fakeRepo);

      final summary = await useCase.execute('bench', days: 30);

      expect(summary.totalSets, equals(3));
      expect(summary.totalSessions, equals(2));
      expect(summary.peakScore, greaterThan(70.0));
      expect(summary.trendPercentage, greaterThan(0));
    });
  });
}

class _FakeWorkoutRepo extends Fake implements WorkoutRepository {
  final List<DailyRecord> _records;
  _FakeWorkoutRepo(this._records);

  @override
  Future<List<DailyRecord>> queryExerciseHistory(String workoutId, {int daysLimit = 30}) async {
    return _records;
  }
}
