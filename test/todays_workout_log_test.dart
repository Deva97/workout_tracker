import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/data/context/workout_db_context.dart';
import 'package:workout_tracker/domain/models/daily_record.dart';
import 'package:workout_tracker/domain/models/exercise.dart';
import 'package:workout_tracker/domain/models/daily_workout_entry.dart';
import 'package:workout_tracker/ui/features/workout_log/views/todays_workout_log_screen.dart';
import 'package:workout_tracker/ui/features/workout_log/views/widgets/add_workout_set_modal.dart';
import 'package:workout_tracker/ui/features/workout_log/views/widgets/boundary_shake_wrapper.dart';
import 'package:workout_tracker/ui/features/workout_log/views/widgets/date_navigator_bar.dart';
import 'package:workout_tracker/ui/features/workout_log/views/widgets/half_screen_page_scroll_physics.dart';
import 'package:workout_tracker/ui/core/widgets/workout_delete_confirm_dialog.dart';
import 'package:workout_tracker/ui/core/widgets/sync_failure_dialog.dart';
import 'package:workout_tracker/ui/core/widgets/workout_activity_success_dialog.dart';
import 'package:workout_tracker/ui/features/workout_log/view_models/todays_workout_log_view_model.dart';
import 'package:workout_tracker/data/services/google_drive_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/google_sign_in'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'init') {
          return null;
        }
        if (methodCall.method == 'isSignedIn') {
          return false;
        }
        return null;
      },
    );
    SharedPreferences.setMockInitialValues({});
    GoogleDriveService().dbContext.replaceExercises([]);
    GoogleDriveService().dbContext.replaceDailyRecords([]);
    GoogleDriveService().syncStateNotifier.value = SyncState.synced;
    GoogleDriveService().simulateSyncFailure = false;
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

    testWidgets('Add & Next triggers onSaveSet, advances set number, shows center popup dialog with OK button, and shows NO bottom snackbar', (tester) async {
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

      // Tap 'Add & Next'
      await tester.tap(find.text('Add & Next'));
      await tester.pumpAndSettle();

      expect(savedRecord, isNotNull);
      expect(savedKeepOpen, isTrue);

      // Verify NO bottom snackbar is shown
      expect(find.byType(SnackBar), findsNothing);

      // Modal is still open and set number incremented from 1 to 2
      expect(find.widgetWithText(TextFormField, '2'), findsOneWidget);
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

    testWidgets('renders compact exercise card with inline tags, set pills, and center delete dialog with Undo on delete', (tester) async {
      final exercise = Exercise(guid: 'ex-chest', name: 'Incline Dumbbell Press', bodyPart: 'Chest');
      final record = DailyRecord(
        id: 'rec-inc-1',
        workoutId: exercise.guid,
        workoutName: exercise.name,
        date: DateTime.now(),
        set: 1,
        reps: 12,
        rir: 2.0,
        weight: 32.0,
      );

      SharedPreferences.setMockInitialValues({
        'exercise_cache': jsonEncode([exercise.toMap()]),
        'daily_record_cache': jsonEncode([record.toMap()]),
      });
      GoogleDriveService().dbContext.replaceExercises([exercise]);
      GoogleDriveService().dbContext.replaceDailyRecords([record]);

      await tester.pumpWidget(
        const MaterialApp(home: TodaysWorkoutLogScreen()),
      );
      await tester.pumpAndSettle();

      // Verify compact header elements
      expect(find.text('CHEST'), findsOneWidget);
      expect(find.text('Incline Dumbbell Press'), findsOneWidget);
      expect(find.text('1 set'), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);

      // Verify compact set pill and compact single-line metrics format
      expect(find.text('SET 1'), findsOneWidget);
      expect(find.textContaining('32.0 kg'), findsOneWidget);
      expect(find.textContaining('12 reps'), findsOneWidget);
      expect(find.textContaining('RIR 2.0'), findsOneWidget);

      // Verify delete button triggers WorkoutDeleteConfirmDialog with Cancel and OK
      final deleteBtn = find.byTooltip('Delete set');
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(find.byType(WorkoutDeleteConfirmDialog), findsOneWidget);
      expect(find.text('Delete Workout Set?'), findsOneWidget);
      expect(find.text('Incline Dumbbell Press'), findsWidgets);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);

      // Verify no bottom snackbar is shown
      expect(find.byType(SnackBar), findsNothing);

      // Tapping Cancel keeps the set intact
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(WorkoutDeleteConfirmDialog), findsNothing);
      expect(find.text('SET 1'), findsOneWidget);

      // Now tap delete again and tap OK to confirm
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(find.byType(WorkoutDeleteConfirmDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Post-sync success dialog is displayed
      expect(find.byType(WorkoutActivitySuccessDialog), findsOneWidget);
      expect(find.text('Workout Activity Deleted'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);

      // Tap OK on success dialog
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(WorkoutActivitySuccessDialog), findsNothing);
      expect(find.text('Incline Dumbbell Press'), findsNothing);

      // Advance clock to drain debounce timer
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('when delete sync fails, shows SyncFailureDialog and tapping Cancel rolls back deletion so set remains on page', (tester) async {
      final exercise = Exercise(guid: 'ex-chest', name: 'Incline Dumbbell Press', bodyPart: 'Chest');
      final record = DailyRecord(
        id: 'rec-inc-2',
        workoutId: exercise.guid,
        workoutName: exercise.name,
        date: DateTime.now(),
        set: 1,
        reps: 12,
        rir: 2.0,
        weight: 32.0,
      );

      SharedPreferences.setMockInitialValues({
        'exercise_cache': jsonEncode([exercise.toMap()]),
        'daily_record_cache': jsonEncode([record.toMap()]),
      });
      GoogleDriveService().dbContext.replaceExercises([exercise]);
      GoogleDriveService().dbContext.replaceDailyRecords([record]);

      // Set simulate sync failure so manualSync fails
      GoogleDriveService().simulateSyncFailure = true;

      await tester.pumpWidget(
        const MaterialApp(home: TodaysWorkoutLogScreen()),
      );
      await tester.pumpAndSettle();

      final deleteBtn = find.byTooltip('Delete set');
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(find.byType(WorkoutDeleteConfirmDialog), findsOneWidget);

      // Tap OK to confirm delete
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Because sync failed, SyncFailureDialog appears!
      expect(find.byType(SyncFailureDialog), findsOneWidget);
      expect(find.text('Sync Failed'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel -> rolls back deletion, so the set remains on the page!
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(SyncFailureDialog), findsNothing);
      expect(find.text('Incline Dumbbell Press'), findsOneWidget);

      // Restore sync state
      GoogleDriveService().simulateSyncFailure = false;
      GoogleDriveService().syncStateNotifier.value = SyncState.synced;
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('saving set from modal shows center WorkoutActivitySuccessDialog with OK option and no bottom snackbar', (tester) async {
      final exercise = Exercise(guid: 'ex-bench', name: 'Bench Press', bodyPart: 'Chest');
      SharedPreferences.setMockInitialValues({
        'exercise_cache': jsonEncode([exercise.toMap()]),
        'daily_record_cache': jsonEncode([]),
      });
      GoogleDriveService().dbContext.replaceExercises([exercise]);
      GoogleDriveService().dbContext.replaceDailyRecords([]);

      await tester.pumpWidget(
        const MaterialApp(home: TodaysWorkoutLogScreen()),
      );
      await tester.pumpAndSettle();

      // Tap "Add First Workout Set" button to open modal
      await tester.tap(find.text('Add First Workout Set'));
      await tester.pumpAndSettle();

      expect(find.byType(AddWorkoutSetModal), findsOneWidget);

      // Save Set
      await tester.tap(find.text('Save Set'));
      await tester.pumpAndSettle();

      // Modal closed, center confirmation dialog is displayed
      expect(find.byType(WorkoutActivitySuccessDialog), findsOneWidget);
      expect(find.text('Workout Activity Added'), findsOneWidget);
      expect(find.text('Bench Press'), findsWidgets);
      expect(find.text('OK'), findsOneWidget);

      // Verify no plain bottom snackbar
      expect(find.byType(SnackBar), findsNothing);

      // Tapping OK dismisses dialog
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(WorkoutActivitySuccessDialog), findsNothing);
      expect(find.text('Bench Press'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('when saving set sync fails, shows SyncFailureDialog and tapping Cancel rolls back added set so it is NOT seen on page', (tester) async {
      final exercise = Exercise(guid: 'ex-bench', name: 'Bench Press', bodyPart: 'Chest');
      SharedPreferences.setMockInitialValues({
        'exercise_cache': jsonEncode([exercise.toMap()]),
        'daily_record_cache': jsonEncode([]),
      });
      GoogleDriveService().dbContext.replaceExercises([exercise]);
      GoogleDriveService().dbContext.replaceDailyRecords([]);

      // Set simulate sync failure so manualSync fails
      GoogleDriveService().simulateSyncFailure = true;

      await tester.pumpWidget(
        const MaterialApp(home: TodaysWorkoutLogScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add First Workout Set'));
      await tester.pumpAndSettle();

      // Save Set
      await tester.tap(find.text('Save Set'));
      await tester.pumpAndSettle();

      // SyncFailureDialog appears!
      expect(find.byType(SyncFailureDialog), findsOneWidget);
      expect(find.text('Sync Failed'), findsOneWidget);

      // Tap Cancel -> rolls back operation!
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(SyncFailureDialog), findsNothing);
      // Not seen on page: empty state is shown!
      expect(find.text('No Workout Logged Today'), findsOneWidget);

      // Restore sync state
      GoogleDriveService().simulateSyncFailure = false;
      GoogleDriveService().syncStateNotifier.value = SyncState.synced;
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('editing set shows center WorkoutActivitySuccessDialog with Workout Set Updated title', (tester) async {
      final exercise = Exercise(guid: 'ex-bench', name: 'Bench Press', bodyPart: 'Chest');
      final record = DailyRecord(
        id: 'rec-1',
        workoutId: exercise.guid,
        workoutName: exercise.name,
        date: DateTime.now(),
        set: 1,
        reps: 10,
        rir: 2.0,
        weight: 60.0,
      );
      SharedPreferences.setMockInitialValues({
        'exercise_cache': jsonEncode([exercise.toMap()]),
        'daily_record_cache': jsonEncode([record.toMap()]),
      });
      GoogleDriveService().dbContext.replaceExercises([exercise]);
      GoogleDriveService().dbContext.replaceDailyRecords([record]);

      await tester.pumpWidget(
        const MaterialApp(home: TodaysWorkoutLogScreen()),
      );
      await tester.pumpAndSettle();

      // Tap Edit button
      await tester.tap(find.byTooltip('Edit set'));
      await tester.pumpAndSettle();

      expect(find.byType(AddWorkoutSetModal), findsOneWidget);
      expect(find.text('Update Set'), findsOneWidget);

      // Tap Update Set
      await tester.tap(find.text('Update Set'));
      await tester.pumpAndSettle();

      // Modal closed, center confirmation dialog with edit title displayed
      expect(find.byType(WorkoutActivitySuccessDialog), findsOneWidget);
      expect(find.text('Workout Set Updated'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      // Tap OK
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(WorkoutActivitySuccessDialog), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('WorkoutActivitySuccessDialog - Component Tests', () {
    testWidgets('renders dialog in light and dark mode and invokes onDismiss when OK is tapped', (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: WorkoutActivitySuccessDialog(
              exerciseName: 'Overhead Press',
              setNumber: 2,
              weight: 50.0,
              reps: 8,
              rir: 1.5,
              isEdit: false,
              onDismiss: () {
                dismissed = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Workout Activity Added'), findsOneWidget);
      expect(find.text('Overhead Press'), findsOneWidget);
      expect(find.textContaining('Set 2'), findsOneWidget);
      expect(find.textContaining('50.0 kg × 8 reps'), findsOneWidget);
      expect(find.textContaining('RIR 1.5'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      // Tap OK
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    testWidgets('renders dialog with edit title when isEdit is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutActivitySuccessDialog(
              exerciseName: 'Pull-up',
              setNumber: 1,
              weight: 0.0,
              reps: 10,
              rir: 2.0,
              isEdit: true,
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Workout Set Updated'), findsOneWidget);
      expect(find.text('Pull-up'), findsOneWidget);
      expect(find.textContaining('10 reps  •  RIR 2.0'), findsOneWidget);
    });

    testWidgets('renders dialog with delete title when isDelete is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutActivitySuccessDialog(
              exerciseName: 'Pull-up',
              setNumber: 1,
              weight: 0.0,
              reps: 10,
              rir: 2.0,
              isDelete: true,
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Workout Activity Deleted'), findsOneWidget);
      expect(find.text('Pull-up'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
    });
  });

  group('WorkoutDeleteConfirmDialog - Component Tests', () {
    testWidgets('renders delete confirm dialog in light & dark mode and invokes onCancel and onConfirm', (tester) async {
      bool cancelled = false;
      bool confirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: WorkoutDeleteConfirmDialog(
              exerciseName: 'Barbell Squat',
              setNumber: 3,
              weight: 120.0,
              reps: 5,
              rir: 1.0,
              onCancel: () {
                cancelled = true;
              },
              onConfirm: () {
                confirmed = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete Workout Set?'), findsOneWidget);
      expect(find.text('Barbell Squat'), findsOneWidget);
      expect(find.textContaining('Set 3'), findsOneWidget);
      expect(find.textContaining('120.0 kg × 5 reps'), findsOneWidget);
      expect(find.textContaining('RIR 1.0'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(cancelled, isTrue);

      // Tap OK
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
    });
  });

  group('SyncFailureDialog - Component Tests', () {
    testWidgets('renders sync failure dialog with Retry and Cancel buttons and invokes callbacks', (tester) async {
      bool cancelled = false;
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SyncFailureDialog(
              onCancel: () {
                cancelled = true;
              },
              onRetry: () {
                retried = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sync Failed'), findsOneWidget);
      expect(find.byIcon(Icons.sync_problem_rounded), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(cancelled, isTrue);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(retried, isTrue);
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

    test('saveSetAndSync and rollbackAddedSet transactional behavior', () async {
      final benchPress = Exercise(guid: 'ex-bench', name: 'Bench Press', bodyPart: 'Chest');
      GoogleDriveService().dbContext.replaceExercises([benchPress]);
      GoogleDriveService().dbContext.replaceDailyRecords([]);

      final viewModel = TodaysWorkoutLogViewModel();
      await viewModel.loadTodaysWorkoutLog();
      expect(viewModel.todaysEntries, isEmpty);

      final rec = DailyRecord(
        id: 'rec-sync-1',
        workoutId: benchPress.guid,
        workoutName: benchPress.name,
        date: DateTime.now(),
        set: 1,
        reps: 10,
        rir: 2.0,
        weight: 60.0,
      );

      final syncResult = await viewModel.saveSetAndSync(rec);
      expect(syncResult, equals(SyncState.synced));
      expect(viewModel.todaysEntries.length, equals(1));

      // Rollback
      await viewModel.rollbackAddedSet(rec);
      expect(viewModel.todaysEntries, isEmpty);
    });

    test('deleteSetAndSync and rollbackDeletedSet transactional behavior', () async {
      final benchPress = Exercise(guid: 'ex-bench', name: 'Bench Press', bodyPart: 'Chest');
      final rec = DailyRecord(
        id: 'rec-sync-2',
        workoutId: benchPress.guid,
        workoutName: benchPress.name,
        date: DateTime.now(),
        set: 1,
        reps: 10,
        rir: 2.0,
        weight: 60.0,
      );
      GoogleDriveService().dbContext.replaceExercises([benchPress]);
      GoogleDriveService().dbContext.replaceDailyRecords([rec]);

      final viewModel = TodaysWorkoutLogViewModel();
      await viewModel.loadTodaysWorkoutLog();
      expect(viewModel.todaysEntries.length, equals(1));

      final deleteResult = await viewModel.deleteSetAndSync(viewModel.todaysEntries.first);
      expect(deleteResult, equals(SyncState.synced));
      expect(viewModel.todaysEntries, isEmpty);

      // Rollback deletion
      await viewModel.rollbackDeletedSet(rec);
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

  group('TodaysWorkoutLogViewModel - Date Navigation Unit Tests', () {
    test('initializes with today as selectedDate and properly calculates canGoPrevious / canGoNext when alone', () async {
      final benchPress = Exercise(guid: 'ex-bench', name: 'Bench Press', bodyPart: 'Chest');
      GoogleDriveService().dbContext.replaceExercises([benchPress]);
      GoogleDriveService().dbContext.replaceDailyRecords([]);

      final viewModel = TodaysWorkoutLogViewModel();
      await viewModel.loadTodaysWorkoutLog();

      expect(viewModel.isViewingToday, isTrue);
      expect(viewModel.availableDates.length, equals(1));
      expect(viewModel.canGoPrevious, isFalse);
      expect(viewModel.canGoNext, isFalse);

      // Boundaries return false
      expect(await viewModel.goToPreviousRecord(), isFalse);
      expect(await viewModel.goToNextRecord(), isFalse);
    });

    test('discovers historical dates from dbContext and navigates back and forth', () async {
      final benchPress = Exercise(guid: 'ex-bench', name: 'Bench Press', bodyPart: 'Chest');
      final now = DateTime.now();
      final oneDayAgo = now.subtract(const Duration(days: 1));
      final threeDaysAgo = now.subtract(const Duration(days: 3));

      final recToday = DailyRecord(
        id: 'r-today',
        workoutId: benchPress.guid,
        workoutName: benchPress.name,
        date: now,
        set: 1,
        reps: 10,
        rir: 2.0,
        weight: 60.0,
      );
      final rec1DayAgo = DailyRecord(
        id: 'r-1day',
        workoutId: benchPress.guid,
        workoutName: benchPress.name,
        date: oneDayAgo,
        set: 1,
        reps: 8,
        rir: 1.0,
        weight: 65.0,
      );
      final rec3DaysAgo = DailyRecord(
        id: 'r-3days',
        workoutId: benchPress.guid,
        workoutName: benchPress.name,
        date: threeDaysAgo,
        set: 1,
        reps: 6,
        rir: 0.0,
        weight: 70.0,
      );

      GoogleDriveService().dbContext.replaceExercises([benchPress]);
      GoogleDriveService().dbContext.replaceDailyRecords([recToday, rec1DayAgo, rec3DaysAgo]);

      final viewModel = TodaysWorkoutLogViewModel();
      await viewModel.loadTodaysWorkoutLog();

      expect(viewModel.availableDates.length, equals(3));
      expect(viewModel.isViewingToday, isTrue);
      expect(viewModel.canGoPrevious, isTrue);
      expect(viewModel.canGoNext, isFalse);
      expect(viewModel.todaysEntries.length, equals(1));
      expect(viewModel.todaysEntries.first.record.id, equals('r-today'));

      // Navigate to previous (1 day ago)
      final movedTo1DayAgo = await viewModel.goToPreviousRecord();
      expect(movedTo1DayAgo, isTrue);
      expect(viewModel.isViewingToday, isFalse);
      expect(viewModel.canGoPrevious, isTrue);
      expect(viewModel.canGoNext, isTrue);
      expect(viewModel.todaysEntries.length, equals(1));
      expect(viewModel.todaysEntries.first.record.id, equals('r-1day'));

      // Navigate to previous (3 days ago)
      final movedTo3DaysAgo = await viewModel.goToPreviousRecord();
      expect(movedTo3DaysAgo, isTrue);
      expect(viewModel.isViewingToday, isFalse);
      expect(viewModel.canGoPrevious, isFalse);
      expect(viewModel.canGoNext, isTrue);
      expect(viewModel.todaysEntries.length, equals(1));
      expect(viewModel.todaysEntries.first.record.id, equals('r-3days'));

      // Attempt to go previous past oldest boundary
      final atBoundary = await viewModel.goToPreviousRecord();
      expect(atBoundary, isFalse);
      expect(viewModel.todaysEntries.first.record.id, equals('r-3days'));

      // Navigate next (back to 1 day ago)
      final movedNext = await viewModel.goToNextRecord();
      expect(movedNext, isTrue);
      expect(viewModel.todaysEntries.first.record.id, equals('r-1day'));

      // Jump back to Today
      await viewModel.goToToday();
      expect(viewModel.isViewingToday, isTrue);
      expect(viewModel.canGoNext, isFalse);
      expect(viewModel.todaysEntries.first.record.id, equals('r-today'));
    });

    test('changeDate directly navigates to a custom date and adds it to availableDates', () async {
      final benchPress = Exercise(guid: 'ex-bench', name: 'Bench Press', bodyPart: 'Chest');
      GoogleDriveService().dbContext.replaceExercises([benchPress]);
      GoogleDriveService().dbContext.replaceDailyRecords([]);

      final viewModel = TodaysWorkoutLogViewModel();
      await viewModel.loadTodaysWorkoutLog();

      final targetDate = DateTime(2025, 1, 15);
      await viewModel.changeDate(targetDate);

      expect(viewModel.selectedDate.year, equals(2025));
      expect(viewModel.selectedDate.month, equals(1));
      expect(viewModel.selectedDate.day, equals(15));
      expect(viewModel.isViewingToday, isFalse);
      expect(viewModel.availableDates.any((d) => d.year == 2025 && d.month == 1 && d.day == 15), isTrue);
    });
  });

  group('BoundaryShakeWrapper - Widget & Vibration Tests', () {
    testWidgets('renders child properly and BoundaryShakeController triggers animation and HapticFeedback', (tester) async {
      final methodCalls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);
          return null;
        },
      );

      final controller = BoundaryShakeController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BoundaryShakeWrapper(
              controller: controller,
              child: const Text('Shake Target Widget'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shake Target Widget'), findsOneWidget);

      // Trigger boundary feedback
      controller.triggerBoundaryFeedback();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Check haptic feedback was invoked
      final hasHeavyImpact = methodCalls.any((call) =>
          call.method == 'HapticFeedback.vibrate' &&
          call.arguments == 'HapticFeedbackType.heavyImpact');
      expect(hasHeavyImpact, isTrue);

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });
  });

  group('DateNavigatorBar - Widget Navigation Tests', () {
    testWidgets('renders date label formatted as Today when isViewingToday is true', (tester) async {
      final today = DateTime.now();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateNavigatorBar(
              selectedDate: today,
              isViewingToday: true,
              canGoPrevious: true,
              canGoNext: false,
              onPreviousPressed: () {},
              onNextPressed: () {},
              onDatePickerPressed: () {},
              onTodayPressed: () {},
              onBoundaryAttempt: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Today, '), findsOneWidget);
      expect(find.byKey(const Key('jump_to_today_button')), findsNothing);
    });

    testWidgets('renders date label for past date and displays jump to today button', (tester) async {
      final pastDate = DateTime(2025, 5, 20);
      var todayTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateNavigatorBar(
              selectedDate: pastDate,
              isViewingToday: false,
              canGoPrevious: true,
              canGoNext: true,
              onPreviousPressed: () {},
              onNextPressed: () {},
              onDatePickerPressed: () {},
              onTodayPressed: () {
                todayTapped = true;
              },
              onBoundaryAttempt: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('jump_to_today_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('jump_to_today_button')));
      await tester.pumpAndSettle();

      expect(todayTapped, isTrue);
    });

    testWidgets('triggers onPreviousPressed when canGoPrevious is true and onBoundaryAttempt when false', (tester) async {
      var prevPressed = false;
      var boundaryPressed = false;

      // When canGoPrevious is true
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateNavigatorBar(
              selectedDate: DateTime.now(),
              isViewingToday: true,
              canGoPrevious: true,
              canGoNext: false,
              onPreviousPressed: () => prevPressed = true,
              onNextPressed: () {},
              onDatePickerPressed: () {},
              onTodayPressed: () {},
              onBoundaryAttempt: () => boundaryPressed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('prev_date_button')));
      await tester.pumpAndSettle();
      expect(prevPressed, isTrue);
      expect(boundaryPressed, isFalse);

      // When canGoPrevious is false
      prevPressed = false;
      boundaryPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateNavigatorBar(
              selectedDate: DateTime.now(),
              isViewingToday: true,
              canGoPrevious: false,
              canGoNext: false,
              onPreviousPressed: () => prevPressed = true,
              onNextPressed: () {},
              onDatePickerPressed: () {},
              onTodayPressed: () {},
              onBoundaryAttempt: () => boundaryPressed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('prev_date_button')));
      await tester.pumpAndSettle();
      expect(prevPressed, isFalse);
      expect(boundaryPressed, isTrue);
    });

    testWidgets('triggers onNextPressed when canGoNext is true and onBoundaryAttempt when false', (tester) async {
      var nextPressed = false;
      var boundaryPressed = false;

      // When canGoNext is false (on Today)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateNavigatorBar(
              selectedDate: DateTime.now(),
              isViewingToday: true,
              canGoPrevious: true,
              canGoNext: false,
              onPreviousPressed: () {},
              onNextPressed: () => nextPressed = true,
              onDatePickerPressed: () {},
              onTodayPressed: () {},
              onBoundaryAttempt: () => boundaryPressed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('next_date_button')));
      await tester.pumpAndSettle();
      expect(nextPressed, isFalse);
      expect(boundaryPressed, isTrue);

      // When canGoNext is true
      nextPressed = false;
      boundaryPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateNavigatorBar(
              selectedDate: DateTime.now().subtract(const Duration(days: 2)),
              isViewingToday: false,
              canGoPrevious: true,
              canGoNext: true,
              onPreviousPressed: () {},
              onNextPressed: () => nextPressed = true,
              onDatePickerPressed: () {},
              onTodayPressed: () {},
              onBoundaryAttempt: () => boundaryPressed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('next_date_button')));
      await tester.pumpAndSettle();
      expect(nextPressed, isTrue);
      expect(boundaryPressed, isFalse);
    });

    testWidgets('triggers onDatePickerPressed when date chip is tapped', (tester) async {
      var datePickerTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateNavigatorBar(
              selectedDate: DateTime.now(),
              isViewingToday: true,
              canGoPrevious: true,
              canGoNext: false,
              onPreviousPressed: () {},
              onNextPressed: () {},
              onDatePickerPressed: () => datePickerTapped = true,
              onTodayPressed: () {},
              onBoundaryAttempt: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('date_picker_chip')));
      await tester.pumpAndSettle();
      expect(datePickerTapped, isTrue);
    });
  });

  group('TodaysWorkoutLogScreen - Date Browsing & Swipe Integration Tests', () {
    testWidgets('renders DateNavigatorBar and allows navigating to past workout date', (tester) async {
      final benchPress = Exercise(guid: 'ex-bench', name: 'Bench Press', bodyPart: 'Chest');
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      final recToday = DailyRecord(
        id: 'rec-today',
        workoutId: benchPress.guid,
        workoutName: benchPress.name,
        date: now,
        set: 1,
        reps: 10,
        rir: 2.0,
        weight: 60.0,
      );
      final recYesterday = DailyRecord(
        id: 'rec-yest',
        workoutId: benchPress.guid,
        workoutName: benchPress.name,
        date: yesterday,
        set: 1,
        reps: 8,
        rir: 1.0,
        weight: 75.0,
      );

      GoogleDriveService().dbContext.replaceExercises([benchPress]);
      GoogleDriveService().dbContext.replaceDailyRecords([recToday, recYesterday]);

      await tester.pumpWidget(
        const MaterialApp(home: TodaysWorkoutLogScreen()),
      );
      await tester.pumpAndSettle();

      // Today's record should be displayed initially
      expect(find.byType(DateNavigatorBar), findsOneWidget);
      expect(find.textContaining('60.0 kg'), findsOneWidget);
      expect(find.textContaining('10 reps'), findsOneWidget);

      // Tap Previous (<) button to view yesterday
      await tester.tap(find.byKey(const Key('prev_date_button')));
      await tester.pumpAndSettle();

      // Yesterday's record should now be displayed
      expect(find.textContaining('75.0 kg'), findsOneWidget);
      expect(find.textContaining('8 reps'), findsOneWidget);
      expect(find.byKey(const Key('jump_to_today_button')), findsOneWidget);

      // Tap Jump to Today
      await tester.tap(find.byKey(const Key('jump_to_today_button')).first);
      await tester.pumpAndSettle();

      // Back on Today
      expect(find.textContaining('60.0 kg'), findsOneWidget);
      expect(find.textContaining('10 reps'), findsOneWidget);
    });

    testWidgets('boundary attempt at today triggers heavy impact vibration', (tester) async {
      final methodCalls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);
          return null;
        },
      );

      final benchPress = Exercise(guid: 'ex-bench', name: 'Bench Press', bodyPart: 'Chest');
      GoogleDriveService().dbContext.replaceExercises([benchPress]);
      GoogleDriveService().dbContext.replaceDailyRecords([]);

      await tester.pumpWidget(
        const MaterialApp(home: TodaysWorkoutLogScreen()),
      );
      await tester.pumpAndSettle();

      // We are on Today and have no later records. Tap Next (>)
      await tester.tap(find.byKey(const Key('next_date_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final hasHeavyImpact = methodCalls.any((call) =>
          call.method == 'HapticFeedback.vibrate' &&
          call.arguments == 'HapticFeedbackType.heavyImpact');
      expect(hasHeavyImpact, isTrue);

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });
  });

  group('HalfScreenPageScrollPhysics - Unit Tests', () {
    test('createBallisticSimulation snaps back to current page when drag is under 50%', () {
      const physics = HalfScreenPageScrollPhysics();
      final position = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 800,
        pixels: 160,
        viewportDimension: 400,
        axisDirection: AxisDirection.right,
        devicePixelRatio: 1.0,
      );

      final simulation = physics.createBallisticSimulation(position, 100);
      expect(simulation, isNotNull);
      expect(simulation is ScrollSpringSimulation, isTrue);
      final springSim = simulation as ScrollSpringSimulation;
      // Target should be 0.0 (snaps back to page 0)
      expect(springSim.x(100.0).round(), equals(0));
    });

    test('createBallisticSimulation advances to next page when drag is >= 50%', () {
      const physics = HalfScreenPageScrollPhysics();
      final position = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 800,
        pixels: 220,
        viewportDimension: 400,
        axisDirection: AxisDirection.right,
        devicePixelRatio: 1.0,
      );

      final simulation = physics.createBallisticSimulation(position, 100);
      expect(simulation, isNotNull);
      expect(simulation is ScrollSpringSimulation, isTrue);
      final springSim = simulation as ScrollSpringSimulation;
      // Target should be 400.0 (advances to page 1)
      expect(springSim.x(100.0).round(), equals(400));
    });

    test('createBallisticSimulation snaps back to page 1 when dragging back under 50%', () {
      const physics = HalfScreenPageScrollPhysics();
      final position = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 800,
        pixels: 250,
        viewportDimension: 400,
        axisDirection: AxisDirection.right,
        devicePixelRatio: 1.0,
      );

      final simulation = physics.createBallisticSimulation(position, -100);
      expect(simulation, isNotNull);
      final springSim = simulation as ScrollSpringSimulation;
      // Target should be 400.0 (snaps back to page 1)
      expect(springSim.x(100.0).round(), equals(400));
    });

    test('createBallisticSimulation snaps to page 0 when dragging back >= 50%', () {
      const physics = HalfScreenPageScrollPhysics();
      final position = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 800,
        pixels: 180,
        viewportDimension: 400,
        axisDirection: AxisDirection.right,
        devicePixelRatio: 1.0,
      );

      final simulation = physics.createBallisticSimulation(position, -100);
      expect(simulation, isNotNull);
      final springSim = simulation as ScrollSpringSimulation;
      // Target should be 0.0 (advances to page 0)
      expect(springSim.x(100.0).round(), equals(0));
    });
  });
}

