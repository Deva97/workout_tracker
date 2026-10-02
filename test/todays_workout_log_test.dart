import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/data/context/workout_db_context.dart';
import 'package:workout_tracker/domain/models/daily_record.dart';
import 'package:workout_tracker/domain/models/exercise.dart';
import 'package:workout_tracker/domain/models/daily_workout_entry.dart';
import 'package:workout_tracker/ui/features/workout_log/views/todays_workout_log_screen.dart';
import 'package:workout_tracker/ui/features/workout_log/views/widgets/add_workout_set_modal.dart';
import 'package:workout_tracker/ui/features/workout_log/view_models/todays_workout_log_view_model.dart';
import 'package:workout_tracker/data/services/google_drive_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleDriveService().dbContext.replaceExercises([]);
    GoogleDriveService().dbContext.replaceDailyRecords([]);
    GoogleDriveService().syncStateNotifier.value = SyncState.synced;
  });

  group('Today Workout Log - ORM & Relational Query Tests', () {
    test('WorkoutDbContext resolves Exercise foreign key references efficiently', () {
      final context = WorkoutDbContext();
      final benchPress = Exercise(guid: 'ex-bench-101', name: 'Bench Press', bodyPart: 'Chest');
      final squat = Exercise(guid: 'ex-squat-102', name: 'Barbell Squat', bodyPart: 'Legs');

      context.replaceExercises([benchPress, squat]);

      final today = DateTime.now();
      context.replaceDailyRecords([
        DailyRecord(
          id: 'rec-1',
          workoutId: 'ex-bench-101',
          workoutName: 'Bench Press',
          date: today,
          set: 1,
          reps: 10,
          rir: 2.0,
        ),
        DailyRecord(
          id: 'rec-2',
          workoutId: 'ex-bench-101',
          workoutName: 'Bench Press',
          date: today,
          set: 2,
          reps: 8,
          rir: 1.0,
        ),
        DailyRecord(
          id: 'rec-3',
          workoutId: 'ex-squat-102',
          workoutName: 'Barbell Squat',
          date: today,
          set: 1,
          reps: 8,
          rir: 2.0,
        ),
      ]);

      final todaysEntries = context.getTodaysWorkoutEntries(today);

      expect(todaysEntries.length, equals(3));
      expect(todaysEntries[0].exercise.guid, equals('ex-bench-101'));
      expect(todaysEntries[0].exercise.name, equals('Bench Press'));
      expect(todaysEntries[0].exercise.bodyPart, equals('Chest'));
      expect(todaysEntries[0].record.set, equals(1));
      expect(todaysEntries[1].record.set, equals(1));
      expect(todaysEntries[2].record.set, equals(2));
    });

    test('getTodaysWorkoutEntries returns empty list when no records match today', () {
      final context = WorkoutDbContext();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      context.addDailyRecord(
        DailyRecord(
          id: 'rec-old',
          workoutId: 'ex-1',
          workoutName: 'Bench Press',
          date: yesterday,
          set: 1,
          reps: 10,
          rir: 2.0,
        ),
      );

      final todaysEntries = context.getTodaysWorkoutEntries(DateTime.now());
      expect(todaysEntries, isEmpty);
    });

    test('GoogleDriveService cache eviction policy purges historical non-today records', () async {
      final driveService = GoogleDriveService();
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      final todayRecord = DailyRecord(
        id: 'today-1',
        workoutId: 'ex-1',
        workoutName: 'Bench Press',
        date: now,
        set: 1,
        reps: 10,
        rir: 2.0,
      );

      final historicalRecord = DailyRecord(
        id: 'hist-1',
        workoutId: 'ex-1',
        workoutName: 'Bench Press',
        date: yesterday,
        set: 1,
        reps: 10,
        rir: 2.0,
      );

      // Add historical and today record
      await driveService.addDailyRecord(todayRecord);
      await driveService.addDailyRecord(historicalRecord);

      // Fetch from local cache memory
      final cachedRecords = await driveService.getDailyRecords();

      // Verify historical record is evicted from cache memory
      expect(cachedRecords.length, equals(1));
      expect(cachedRecords.first.id, equals('today-1'));
    });

    test('addDailyRecordOptimistic updates local cache & memory instantly', () async {
      final driveService = GoogleDriveService();
      final record = DailyRecord(
        id: 'opt-1',
        workoutId: 'ex-bench-1',
        workoutName: 'Bench Press',
        date: DateTime.now(),
        set: 1,
        reps: 12,
        rir: 2.0,
      );

      await driveService.addDailyRecordOptimistic(record);

      expect(driveService.dbContext.readDailyRecords().length, equals(1));
      expect(driveService.dbContext.readDailyRecords().first.id, equals('opt-1'));
    });
  });

  group('AddWorkoutSetModal - Validation Tests', () {
    testWidgets('Modal validates exercise selection, reps, and RIR range', (tester) async {
      DailyRecord? savedRecord;
      bool? savedKeepOpen;

      final testExercise = Exercise(guid: 'ex-1', name: 'Incline Press', bodyPart: 'Chest');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddWorkoutSetModal(
              availableExercises: [testExercise],
              onSaveSet: (record, keepOpen) {
                savedRecord = record;
                savedKeepOpen = keepOpen;
              },
            ),
          ),
        ),
      );

      // Verify default initial form values
      expect(find.text('Incline Press'), findsOneWidget);
      expect(find.text('Set Number'), findsOneWidget);
      expect(find.text('Reps'), findsOneWidget);

      // Enter invalid reps (0)
      await tester.enterText(find.widgetWithText(TextFormField, '10'), '0');
      await tester.tap(find.text('Save Set'));
      await tester.pumpAndSettle();

      expect(find.text('Must be > 0'), findsOneWidget);
      expect(savedRecord, isNull);

      // Enter valid reps and save set with slider value
      await tester.enterText(find.widgetWithText(TextFormField, '0'), '10');
      await tester.tap(find.text('Save Set'));
      await tester.pumpAndSettle();

      expect(savedRecord, isNotNull);
      expect(savedRecord!.workoutId, equals('ex-1'));
      expect(savedRecord!.reps, equals(10));
      expect(savedRecord!.rir, equals(2.0));
      expect(savedKeepOpen, isFalse);
    });
  });

  group('TodaysWorkoutLogScreen - Widget UI Tests', () {
    testWidgets('set metrics wrap without overflowing on a narrow screen', (tester) async {
      final exercise = Exercise(guid: 'ex-row', name: 'Upper Back Rowing', bodyPart: 'Back');
      final record = DailyRecord(
        id: 'record-row',
        workoutId: exercise.guid,
        workoutName: exercise.name,
        date: DateTime.now(),
        set: 1,
        reps: 8,
        rir: 2.0,
        weight: 120.0,
      );
      SharedPreferences.setMockInitialValues({
        'exercise_cache': jsonEncode([exercise.toMap()]),
        'daily_record_cache': jsonEncode([record.toMap()]),
      });
      tester.view.physicalSize = const Size(354, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: TodaysWorkoutLogScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Upper Back Rowing'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders empty state when 0 records exist for today', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TodaysWorkoutLogScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Today\'s Workout Log'), findsOneWidget);
      expect(find.text('No Workout Logged Today'), findsOneWidget);
      expect(find.text('Add First Workout Set'), findsOneWidget);
    });

    testWidgets('Renders CompactSyncButton with Sync label', (tester) async {
      GoogleDriveService().syncStateNotifier.value = SyncState.error;
      await tester.pumpWidget(
        const MaterialApp(
          home: TodaysWorkoutLogScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Sync'), findsOneWidget);
      expect(find.byType(CompactSyncButton), findsOneWidget);
    });

    testWidgets('Renders CompactSyncButton when sync state is error', (tester) async {
      GoogleDriveService().syncStateNotifier.value = SyncState.error;

      await tester.pumpWidget(
        const MaterialApp(
          home: TodaysWorkoutLogScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Sync'), findsOneWidget);
      expect(find.byType(CompactSyncButton), findsOneWidget);
    });

    testWidgets('renders PR 🏆 badge for the set with highest estimated 1RM', (tester) async {
      final exercise = Exercise(guid: 'ex-press', name: 'Overhead Press', bodyPart: 'Shoulders');
      final rec1 = DailyRecord(
        id: 'r-1',
        workoutId: exercise.guid,
        workoutName: exercise.name,
        date: DateTime.now(),
        set: 1,
        reps: 10,
        rir: 2.0,
        weight: 40.0,
      );
      final rec2 = DailyRecord(
        id: 'r-2',
        workoutId: exercise.guid,
        workoutName: exercise.name,
        date: DateTime.now(),
        set: 2,
        reps: 8,
        rir: 1.0,
        weight: 50.0,
      );

      SharedPreferences.setMockInitialValues({
        'exercise_cache': jsonEncode([exercise.toMap()]),
        'daily_record_cache': jsonEncode([rec1.toMap(), rec2.toMap()]),
      });
      GoogleDriveService().dbContext.replaceExercises([exercise]);
      GoogleDriveService().dbContext.replaceDailyRecords([rec1, rec2]);

      await tester.pumpWidget(
        const MaterialApp(home: TodaysWorkoutLogScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('PR 🏆'), findsOneWidget);
    });
  });

  group('TodaysWorkoutLogViewModel - Unit Tests', () {
    test('identifies personal record set based on peak estimated 1RM', () async {
      final benchPress = Exercise(guid: 'ex-bench', name: 'Bench Press', bodyPart: 'Chest');
      final rec1 = DailyRecord(
        id: 'rec-1',
        workoutId: benchPress.guid,
        workoutName: benchPress.name,
        date: DateTime.now(),
        set: 1,
        reps: 10,
        rir: 2.0,
        weight: 60.0,
      );
      final rec2 = DailyRecord(
        id: 'rec-2',
        workoutId: benchPress.guid,
        workoutName: benchPress.name,
        date: DateTime.now(),
        set: 2,
        reps: 8,
        rir: 1.0,
        weight: 70.0,
      );

      final entry1 = DailyWorkoutEntry(record: rec1, exercise: benchPress);
      final entry2 = DailyWorkoutEntry(record: rec2, exercise: benchPress);

      GoogleDriveService().dbContext.replaceExercises([benchPress]);
      GoogleDriveService().dbContext.replaceDailyRecords([rec1, rec2]);

      final viewModel = TodaysWorkoutLogViewModel();
      await viewModel.loadTodaysWorkoutLog();

      expect(viewModel.isPersonalRecord(entry1), isFalse);
      expect(viewModel.isPersonalRecord(entry2), isTrue);
    });

    test('maintains last recorded set cache and retrieves it accurately', () async {
      final benchPress = Exercise(guid: 'ex-bench', name: 'Bench Press', bodyPart: 'Chest');
      final rec1 = DailyRecord(
        id: 'rec-1',
        workoutId: benchPress.guid,
        workoutName: benchPress.name,
        date: DateTime.now(),
        set: 1,
        reps: 10,
        rir: 2.0,
        weight: 60.0,
      );
      final rec2 = DailyRecord(
        id: 'rec-2',
        workoutId: benchPress.guid,
        workoutName: benchPress.name,
        date: DateTime.now(),
        set: 2,
        reps: 8,
        rir: 1.0,
        weight: 65.0,
      );

      GoogleDriveService().dbContext.replaceExercises([benchPress]);
      GoogleDriveService().dbContext.replaceDailyRecords([rec1, rec2]);

      final viewModel = TodaysWorkoutLogViewModel();
      await viewModel.loadTodaysWorkoutLog();

      final last = viewModel.getLastRecordedSet(benchPress.guid);
      expect(last, isNotNull);
      expect(last!.set, equals(2));
      expect(last.weight, equals(65.0));
      expect(last.reps, equals(8));
    });

    test('saveSet, editSet, deleteSet, restoreSet mutate state and notify listeners', () async {
      final benchPress = Exercise(guid: 'ex-bench', name: 'Bench Press', bodyPart: 'Chest');
      GoogleDriveService().dbContext.replaceExercises([benchPress]);
      GoogleDriveService().dbContext.replaceDailyRecords([]);

      final viewModel = TodaysWorkoutLogViewModel();
      await viewModel.loadTodaysWorkoutLog();
      expect(viewModel.todaysEntries, isEmpty);

      final rec1 = DailyRecord(
        id: 'rec-1',
        workoutId: benchPress.guid,
        workoutName: benchPress.name,
        date: DateTime.now(),
        set: 1,
        reps: 10,
        rir: 2.0,
        weight: 60.0,
      );

      // Save Set
      await viewModel.saveSet(rec1);
      expect(viewModel.todaysEntries.length, equals(1));
      expect(viewModel.showRestTimer, isTrue);

      // Edit Set
      final updatedRec1 = rec1.copyWith(weight: 65.0);
      await viewModel.editSet(updatedRec1);
      expect(viewModel.todaysEntries.first.record.weight, equals(65.0));

      // Delete Set
      await viewModel.deleteSet(viewModel.todaysEntries.first);
      expect(viewModel.todaysEntries, isEmpty);

      // Restore Set
      await viewModel.restoreSet(rec1);
      expect(viewModel.todaysEntries.length, equals(1));
    });
  });

  group('AddWorkoutSetModal - Memory & Dropdown Tests', () {
    testWidgets('pre-fills weight and reps from previousRecord and shows banner', (tester) async {
      final benchPress = Exercise(guid: 'ex-bench', name: 'Bench Press', bodyPart: 'Chest');
      final prevRecord = DailyRecord(
        id: 'prev-1',
        workoutId: benchPress.guid,
        workoutName: benchPress.name,
        date: DateTime.now().subtract(const Duration(days: 2)),
        set: 3,
        reps: 12,
        rir: 1.5,
        weight: 85.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddWorkoutSetModal(
              availableExercises: [benchPress],
              initialExercise: benchPress,
              initialSetNumber: 4,
              previousRecord: prevRecord,
              onSaveSet: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Last logged: Set 3 • 85.0 kg × 12 reps'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '85.0'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '12'), findsOneWidget);
    });

    testWidgets('dynamically updates previous record metrics when exercise changes in dropdown', (tester) async {
      final benchPress = Exercise(guid: 'ex-bench', name: 'Bench Press', bodyPart: 'Chest');
      final squat = Exercise(guid: 'ex-squat', name: 'Barbell Squat', bodyPart: 'Legs');

      final squatPrev = DailyRecord(
        id: 'prev-squat',
        workoutId: squat.guid,
        workoutName: squat.name,
        date: DateTime.now(),
        set: 2,
        reps: 6,
        rir: 2.0,
        weight: 120.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddWorkoutSetModal(
              availableExercises: [benchPress, squat],
              initialExercise: benchPress,
              getPreviousRecord: (guid) => guid == squat.guid ? squatPrev : null,
              onSaveSet: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially on Bench Press, no previous record
      expect(find.textContaining('Last logged:'), findsNothing);

      // Select Squat from dropdown
      await tester.tap(find.text('Bench Press').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Barbell Squat').last);
      await tester.pumpAndSettle();

      // Squat previous record should now be displayed and pre-filled!
      expect(find.textContaining('Last logged: Set 2 • 120.0 kg × 6 reps'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '120.0'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '6'), findsOneWidget);
    });
  });
}
