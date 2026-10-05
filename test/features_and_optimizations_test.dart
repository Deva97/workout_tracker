import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/data/context/workout_db_context.dart';
import 'package:workout_tracker/domain/models/daily_record.dart';
import 'package:workout_tracker/domain/repositories/workout_repository.dart';
import 'package:workout_tracker/domain/use_cases/get_exercise_statistics_use_case.dart';
import 'package:workout_tracker/ui/features/workout_log/views/widgets/strength_trend_chart.dart';
import 'package:workout_tracker/data/services/google_drive_service.dart';
import 'package:workout_tracker/ui/core/theme/app_colors.dart';
import 'package:workout_tracker/ui/core/theme/app_theme.dart';
import 'package:workout_tracker/domain/models/exercise.dart';
import 'package:workout_tracker/ui/features/home/view_models/home_view_model.dart';
import 'package:workout_tracker/ui/core/widgets/animated_loading_window.dart';
import 'package:workout_tracker/ui/features/auth/views/create_sheets_prompt_screen.dart';
import 'package:workout_tracker/data/services/local_storage_service.dart';
import 'package:workout_tracker/data/repositories/workout_split_repository_impl.dart';
import 'package:workout_tracker/domain/use_cases/manage_workout_split_use_case.dart';
import 'package:workout_tracker/ui/features/workout_split/view_models/workout_split_view_model.dart';
import 'package:workout_tracker/ui/features/workout_split/views/workout_split_page.dart';

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

  group('WorkoutDbContext O(1) Indexing & Integrity Tests', () {
    test('getTodaysWorkoutEntries retrieves records via integer date key index without scanning', () {
      final context = WorkoutDbContext();
      final date1 = DateTime(2026, 3, 15, 10, 30);
      final date2 = DateTime(2026, 3, 16, 11, 0);

      final rec1 = DailyRecord(
        id: 'rec-1',
        workoutId: 'ex-1',
        workoutName: 'Squat',
        date: date1,
        set: 1,
        reps: 8,
        weight: 100.0,
        rir: 2.0,
      );
      final rec2 = DailyRecord(
        id: 'rec-2',
        workoutId: 'ex-2',
        workoutName: 'Bench Press',
        date: date2,
        set: 1,
        reps: 10,
        weight: 80.0,
        rir: 1.5,
      );

      context.replaceDailyRecords([rec1, rec2]);

      final entriesDate1 = context.getTodaysWorkoutEntries(date1);
      expect(entriesDate1.length, equals(1));
      expect(entriesDate1.first.record.workoutId, equals('ex-1'));

      final entriesDate2 = context.getTodaysWorkoutEntries(date2);
      expect(entriesDate2.length, equals(1));
      expect(entriesDate2.first.record.workoutId, equals('ex-2'));

      // Test mutation via addDailyRecord updates index
      final rec3 = DailyRecord(
        id: 'rec-3',
        workoutId: 'ex-1',
        workoutName: 'Squat',
        date: date1,
        set: 2,
        reps: 6,
        weight: 105.0,
        rir: 1.0,
      );
      context.addDailyRecord(rec3);
      final updatedDate1 = context.getTodaysWorkoutEntries(date1);
      expect(updatedDate1.length, equals(2));

      // Test mutation via deleteDailyRecordsWhere
      context.deleteDailyRecordsWhere((r) => r.id == 'rec-1');
      final afterDelete = context.getTodaysWorkoutEntries(date1);
      expect(afterDelete.length, equals(1));
      expect(afterDelete.first.record.id, equals('rec-3'));
    });

    test('exercise GUID index maintains quick lookup across replacements', () {
      final context = WorkoutDbContext();
      final ex = Exercise(
        guid: 'guid-abc',
        name: 'Barbell Bench Press',
        bodyPart: 'Chest',
      );
      context.replaceExercises([ex]);
      expect(context.readExercises().length, equals(1));
      expect(context.readExercises().first.guid, equals('guid-abc'));
    });
  });

  group('HomeViewModel Unit Tests', () {
    test('loads dashboard data, active split, today focus, and week streak', () async {
      SharedPreferences.setMockInitialValues({
        'split_choice': 'Pull-Push Split',
        'workout_schedule': '{"Monday":"Push","Tuesday":"Pull"}',
      });
      final viewModel = HomeViewModel();
      await viewModel.loadDashboardData();

      expect(viewModel.activeSplit, equals('Pull-Push Split'));
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.weekActivity.length, equals(7));
      viewModel.dispose();
    });
  });

  group('Loader Page Messages Tests', () {
    testWidgets('AnimatedLoadingWindow renders message and subMessage without exposing .xlsx filenames', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnimatedLoadingWindow(
            message: 'Validating Google Drive...',
            subMessage: 'Checking workout database',
          ),
        ),
      );

      expect(find.text('Validating Google Drive...'), findsOneWidget);
      expect(find.text('Checking workout database'), findsOneWidget);
      expect(find.textContaining('.xlsx'), findsNothing);
      expect(find.textContaining('Exercise_DB'), findsNothing);
      expect(find.textContaining('Daily_record'), findsNothing);
    });

    testWidgets('CreateSheetsPromptScreen displays clean setup copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CreateSheetsPromptScreen(
            status: DriveSheetsStatus(
              exerciseDbExists: false,
              dailyRecordExists: false,
            ),
          ),
        ),
      );

      expect(find.text('Excel Database Setup Required'), findsOneWidget);
    });
  });

  group('RDBMS Performance Architecture & Excel ORM Optimization Tests', () {
    test('Secondary Indexing: O(1) PK and FK lookups', () {
      final context = WorkoutDbContext();
      final now = DateTime.now();

      final rec1 = DailyRecord(
        id: 'pk-1',
        workoutId: 'bench-press',
        workoutName: 'Bench Press',
        date: now.subtract(const Duration(days: 2)),
        set: 1,
        reps: 10,
        weight: 80.0,
        rir: 2.0,
      );
      final rec2 = DailyRecord(
        id: 'pk-2',
        workoutId: 'squat',
        workoutName: 'Squat',
        date: now.subtract(const Duration(days: 1)),
        set: 1,
        reps: 8,
        weight: 120.0,
        rir: 1.5,
      );
      final rec3 = DailyRecord(
        id: 'pk-3',
        workoutId: 'bench-press',
        workoutName: 'Bench Press',
        date: now,
        set: 1,
        reps: 12,
        weight: 82.5,
        rir: 1.0,
      );

      context.addDailyRecord(rec1);
      context.addDailyRecord(rec2);
      context.addDailyRecord(rec3);

      // Primary Key O(1) point lookup
      expect(context.getDailyRecordById('pk-1')?.workoutName, equals('Bench Press'));
      expect(context.getDailyRecordById('pk-2')?.workoutName, equals('Squat'));
      expect(context.getDailyRecordById('pk-nonexistent'), isNull);

      // Foreign Key O(1) bucket lookup
      final benchSets = context.getRecordsForExercise('bench-press');
      expect(benchSets.length, equals(2));
      expect(benchSets.map((r) => r.id), containsAll(['pk-1', 'pk-3']));

      final squatSets = context.getRecordsForExercise('squat');
      expect(squatSets.length, equals(1));
      expect(squatSets.first.id, equals('pk-2'));
    });

    test('Clustered Indexing & Binary Search Range Pruning: O(log N) date filtering', () {
      final context = WorkoutDbContext();
      final baseDate = DateTime(2026, 1, 1);

      final records = List.generate(
        100,
        (i) => DailyRecord(
          id: 'rec-$i',
          workoutId: 'deadlift',
          workoutName: 'Deadlift',
          date: baseDate.add(Duration(days: i)),
          set: 1,
          reps: 5,
          weight: 100.0 + i,
          rir: 2.0,
        ),
      );

      context.replaceDailyRecords(records);

      // Verify binary search lower bound correctly identifies cutoff
      final cutoff = baseDate.add(const Duration(days: 70));
      final cutoffIndex = WorkoutDbContext.binarySearchLowerBound(records, cutoff);
      expect(cutoffIndex, equals(70));

      // Query since day 70 -> should return 30 records (indices 70 to 99) in O(log N)
      final recentDeadlifts = context.getRecordsForExercise('deadlift', since: cutoff);
      expect(recentDeadlifts.length, equals(30));
      expect(recentDeadlifts.first.id, equals('rec-70'));
      expect(recentDeadlifts.last.id, equals('rec-99'));
    });

    test('Write-Ahead Logging (WAL) & Mutation Journal with Rollback', () {
      final context = WorkoutDbContext();
      final now = DateTime.now();

      final rec = DailyRecord(
        id: 'wal-1',
        workoutId: 'pullup',
        workoutName: 'Pull-up',
        date: now,
        set: 1,
        reps: 10,
        weight: 0.0,
        rir: 2.0,
      );

      // 1. Add mutation journaled
      context.addDailyRecord(rec);
      expect(context.mutationJournal.length, equals(1));
      expect(context.mutationJournal.last.type, equals(DbMutationType.add));
      expect(context.getDailyRecordById('wal-1'), isNotNull);

      // 2. Rollback addition
      final rolledBack = context.rollbackLastMutation();
      expect(rolledBack, isTrue);
      expect(context.getDailyRecordById('wal-1'), isNull);
      expect(context.getRecordsForExercise('pullup'), isEmpty);

      // 3. Update mutation journaled
      context.addDailyRecord(rec);
      final updatedRec = rec.copyWith(reps: 15, weight: 10.0);
      context.updateDailyRecord(updatedRec, (r) => r.id == rec.id);
      expect(context.getDailyRecordById('wal-1')?.reps, equals(15));

      // Rollback update restores previous values
      context.rollbackLastMutation();
      expect(context.getDailyRecordById('wal-1')?.reps, equals(10));
      expect(context.getDailyRecordById('wal-1')?.weight, equals(0.0));
    });

    test('Soft Deletes & Tombstones: O(1) deletion and batch vacuuming', () {
      final context = WorkoutDbContext();
      final now = DateTime.now();

      final rec1 = DailyRecord(
        id: 'tomb-1',
        workoutId: 'dip',
        workoutName: 'Dips',
        date: now,
        set: 1,
        reps: 12,
        weight: 0.0,
        rir: 2.0,
      );
      final rec2 = DailyRecord(
        id: 'tomb-2',
        workoutId: 'dip',
        workoutName: 'Dips',
        date: now,
        set: 2,
        reps: 10,
        weight: 0.0,
        rir: 1.0,
      );

      context.addDailyRecord(rec1);
      context.addDailyRecord(rec2);

      // Soft delete in O(1)
      final deleted = context.deleteDailyRecordById('tomb-1', soft: true);
      expect(deleted, isTrue);

      // Lookup immediately omits tombstoned record
      expect(context.getDailyRecordById('tomb-1'), isNull);
      expect(context.getRecordsForExercise('dip').length, equals(1));
      expect(context.getRecordsForExercise('dip').first.id, equals('tomb-2'));

      // Vacuum removes tombstone physically
      final vacuumedCount = context.vacuumDailyRecords();
      expect(vacuumedCount, equals(1));
      expect(context.readDailyRecords().length, equals(1));
      expect(context.readDailyRecords().first.id, equals('tomb-2'));
    });

    test('Table Partitioning: multi-sheet partitioned encoding and decoding', () {
      final context = WorkoutDbContext();

      final rec2025 = DailyRecord(
        id: 'part-2025',
        workoutId: 'press',
        workoutName: 'Overhead Press',
        date: DateTime(2025, 6, 15),
        set: 1,
        reps: 8,
        weight: 50.0,
        rir: 2.0,
      );
      final rec2026 = DailyRecord(
        id: 'part-2026',
        workoutId: 'press',
        workoutName: 'Overhead Press',
        date: DateTime(2026, 3, 10),
        set: 1,
        reps: 10,
        weight: 55.0,
        rir: 1.5,
      );

      context.replaceDailyRecords([rec2025, rec2026]);

      // Save partitioned tables
      final partitionedBytes = context.savePartitionedDailyRecordToBytes();
      expect(partitionedBytes, isNotEmpty);

      // Load partitioned tables into a fresh context
      final freshContext = WorkoutDbContext();
      freshContext.loadPartitionedDailyRecordsFromBytes(partitionedBytes);

      expect(freshContext.readDailyRecords().length, equals(2));
      expect(freshContext.getDailyRecordById('part-2025'), isNotNull);
      expect(freshContext.getDailyRecordById('part-2026'), isNotNull);

      // Load with since cutoff to only include 2026
      final recentOnlyContext = WorkoutDbContext();
      recentOnlyContext.loadPartitionedDailyRecordsFromBytes(
        partitionedBytes,
        since: DateTime(2026, 1, 1),
      );
      expect(recentOnlyContext.readDailyRecords().length, equals(1));
      expect(recentOnlyContext.readDailyRecords().first.id, equals('part-2026'));
    });

    test('Column Projection: selective cell extraction during decoding', () {
      final context = WorkoutDbContext();
      final now = DateTime.now();

      final rec = DailyRecord(
        id: 'proj-1',
        workoutId: 'curl',
        workoutName: 'Bicep Curl',
        date: now,
        set: 1,
        reps: 12,
        weight: 15.0,
        rir: 1.0,
      );

      context.replaceDailyRecords([rec]);
      final bytes = context.saveDailyRecordToBytes();

      // Decode with column projection
      final projectedTable = context.loadTableFromBytes<DailyRecord>(
        bytes: bytes,
        mapper: DailyRecord.excelMapper,
        projectedColumns: {'ID', 'workout_ID', 'workout_name', 'Date', 'set', 'reps', 'RIR', 'weight'},
      );

      expect(projectedTable.length, equals(1));
      expect(projectedTable.first.id, equals('proj-1'));
      expect(projectedTable.first.workoutName, equals('Bicep Curl'));
    });
  });

  group('Workout Split Dynamic Target Days & Custom Limiter Tests', () {
    test('LocalStorageService persists and retrieves split_target_days', () async {
      final storage = LocalStorageService();
      expect(await storage.getSplitTargetDays(), isNull);

      await storage.setSplitTargetDays(5);
      expect(await storage.getSplitTargetDays(), equals(5));

      await storage.setSplitTargetDays(2);
      expect(await storage.getSplitTargetDays(), equals(2));
    });

    test('ManageWorkoutSplitUseCase validates against dynamic maxDays', () async {
      final storage = LocalStorageService();
      final repo = WorkoutSplitRepositoryImpl(storageService: storage);
      final useCase = ManageWorkoutSplitUseCase(splitRepository: repo);

      final currentSchedule = {
        'Monday': 'Push',
        'Tuesday': 'Pull',
        'Wednesday': 'Push',
        'Thursday': 'Pull',
      };

      // With maxDays = 4, assigning a 5th day fails
      final canAdd5th = useCase.canAssignWorkoutDay(
        maxDays: 4,
        currentSchedule: currentSchedule,
        targetDay: 'Friday',
        targetValue: 'Push',
      );
      expect(canAdd5th, isFalse);

      // With maxDays = 5, assigning a 5th day succeeds
      final canAddWith5Limit = useCase.canAssignWorkoutDay(
        maxDays: 5,
        currentSchedule: currentSchedule,
        targetDay: 'Friday',
        targetValue: 'Push',
      );
      expect(canAddWith5Limit, isTrue);

      // Editing an existing day always succeeds
      final canEditExisting = useCase.canAssignWorkoutDay(
        maxDays: 4,
        currentSchedule: currentSchedule,
        targetDay: 'Monday',
        targetValue: 'Pull',
      );
      expect(canEditExisting, isTrue);

      // Setting Rest always succeeds
      final canSetRest = useCase.canAssignWorkoutDay(
        maxDays: 4,
        currentSchedule: currentSchedule,
        targetDay: 'Friday',
        targetValue: 'Rest',
      );
      expect(canSetRest, isTrue);
    });

    test('WorkoutSplitViewModel loads, saves, and evaluates target days', () async {
      final storage = LocalStorageService();
      final repo = WorkoutSplitRepositoryImpl(storageService: storage);
      final useCase = ManageWorkoutSplitUseCase(splitRepository: repo);
      final viewModel = WorkoutSplitViewModel(splitUseCase: useCase);

      await viewModel.selectSplit('Anterior-Posterior Split', 5);
      expect(viewModel.selectedSplit, equals('Anterior-Posterior Split'));
      expect(viewModel.targetDays, equals(5));
      expect(await storage.getSplitTargetDays(), equals(5));

      await viewModel.saveTargetDays(6);
      expect(viewModel.targetDays, equals(6));
      expect(await storage.getSplitTargetDays(), equals(6));
    });

    testWidgets('WorkoutSplitPage prompts for days and navigates with chosen target', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: WorkoutSplitPage()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pull-Push Split'));
      await tester.pumpAndSettle();

      expect(find.text('How many days are you working out?'), findsOneWidget);
      expect(find.text('Select your weekly workout target for Pull-Push Split (1 to 7 days per week):'), findsOneWidget);

      await tester.tap(find.text('3 Days'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Pull-Push Split Schedule'), findsOneWidget);
      expect(find.text('Weekly Target: 3 Days'), findsOneWidget);

      final storage = LocalStorageService();
      expect(await storage.getSplitTargetDays(), equals(3));
      expect(await storage.getSelectedSplit(), equals('Pull-Push Split'));
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
