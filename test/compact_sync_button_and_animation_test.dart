import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/data/services/google_drive_service.dart';
import 'package:workout_tracker/ui/core/widgets/compact_sync_button.dart';
import 'package:workout_tracker/ui/features/exercise_info/views/exercise_info_page.dart';
import 'package:workout_tracker/ui/features/home/views/home_screen.dart';
import 'package:workout_tracker/ui/features/workout_log/views/exercise_statistics_screen.dart';
import 'package:workout_tracker/ui/features/workout_log/views/todays_workout_log_screen.dart';
import 'package:workout_tracker/ui/features/workout_split/views/workout_schedule_page.dart';
import 'package:workout_tracker/ui/features/workout_split/views/workout_split_page.dart';

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
    GoogleDriveService().syncStateNotifier.value = SyncState.synced;
    GoogleDriveService().simulateSyncFailure = false;
  });

  group('CompactSyncButton Unit and Widget Animation Tests', () {
    testWidgets('renders Synced state with cloud icon and static rotation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CompactSyncButton(syncState: SyncState.synced),
            ),
          ),
        ),
      );

      expect(find.text('Synced'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);

      final rotationFinder = find.descendant(
        of: find.byType(CompactSyncButton),
        matching: find.byType(RotationTransition),
      );
      expect(rotationFinder, findsOneWidget);

      final rotationTransition = tester.widget<RotationTransition>(rotationFinder);
      expect(rotationTransition.turns.value, equals(0.0));
    });

    testWidgets('renders Syncing state with rotating sync icon animation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CompactSyncButton(syncState: SyncState.syncing),
            ),
          ),
        ),
      );

      expect(find.text('Syncing...'), findsOneWidget);
      expect(find.byIcon(Icons.sync_rounded), findsOneWidget);

      final rotationFinder = find.descendant(
        of: find.byType(CompactSyncButton),
        matching: find.byType(RotationTransition),
      );
      final rotationTransition1 = tester.widget<RotationTransition>(rotationFinder);
      final initialTurns = rotationTransition1.turns.value;

      // Advance clock by 250 milliseconds
      await tester.pump(const Duration(milliseconds: 250));

      final rotationTransition2 = tester.widget<RotationTransition>(rotationFinder);
      final midTurns = rotationTransition2.turns.value;

      // Rotation should have advanced
      expect(midTurns, isNot(equals(initialTurns)));
    });

    testWidgets('renders Error state with Sync label and warning cloud icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CompactSyncButton(syncState: SyncState.error),
            ),
          ),
        ),
      );

      expect(find.text('Sync'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload_rounded), findsOneWidget);

      final rotationFinder = find.descendant(
        of: find.byType(CompactSyncButton),
        matching: find.byType(RotationTransition),
      );
      final rotationTransition = tester.widget<RotationTransition>(rotationFinder);
      expect(rotationTransition.turns.value, equals(0.0));
    });

    testWidgets('dynamically activates rotation when syncStateNotifier changes to syncing and stops on synced', (tester) async {
      final notifier = ValueNotifier<SyncState>(SyncState.synced);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CompactSyncButton(syncStateListenable: notifier),
            ),
          ),
        ),
      );

      expect(find.text('Synced'), findsOneWidget);

      // Trigger syncing state
      notifier.value = SyncState.syncing;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Syncing...'), findsOneWidget);

      final rotationFinder = find.descendant(
        of: find.byType(CompactSyncButton),
        matching: find.byType(RotationTransition),
      );
      final r1 = tester.widget<RotationTransition>(rotationFinder).turns.value;
      await tester.pump(const Duration(milliseconds: 200));
      final r2 = tester.widget<RotationTransition>(rotationFinder).turns.value;
      expect(r2, isNot(equals(r1)));

      // Transition to synced
      notifier.value = SyncState.synced;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Synced'), findsOneWidget);
      final r3 = tester.widget<RotationTransition>(rotationFinder).turns.value;
      expect(r3, equals(0.0));
    });

    testWidgets('defaults to listening to GoogleDriveService().syncStateNotifier', (tester) async {
      GoogleDriveService().syncStateNotifier.value = SyncState.synced;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CompactSyncButton(),
            ),
          ),
        ),
      );

      expect(find.text('Synced'), findsOneWidget);

      GoogleDriveService().syncStateNotifier.value = SyncState.syncing;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Syncing...'), findsOneWidget);

      GoogleDriveService().syncStateNotifier.value = SyncState.error;
      await tester.pump();

      expect(find.text('Sync'), findsOneWidget);
    });

    testWidgets('tapping calls custom onPressed or default manualSyncToExcel', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CompactSyncButton(
                syncState: SyncState.error,
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(CompactSyncButton));
      expect(tapped, isTrue);
    });
  });

  group('Top-Right Corner Sync Button Placement Across Pages', () {
    testWidgets('ExerciseInfoPage has CompactSyncButton in top right AppBar actions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ExerciseInfoPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final syncButton = find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(CompactSyncButton),
      );
      expect(syncButton, findsOneWidget);
    });

    testWidgets('TodaysWorkoutLogScreen has CompactSyncButton in top right AppBar actions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TodaysWorkoutLogScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final syncButton = find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(CompactSyncButton),
      );
      expect(syncButton, findsOneWidget);
    });

    testWidgets('HomeScreen has CompactSyncButton in top right AppBar actions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final syncButton = find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(CompactSyncButton),
      );
      expect(syncButton, findsOneWidget);
    });

    testWidgets('ExerciseStatisticsScreen has CompactSyncButton in top right AppBar actions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ExerciseStatisticsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final syncButton = find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(CompactSyncButton),
      );
      expect(syncButton, findsOneWidget);
    });

    testWidgets('WorkoutSplitPage has CompactSyncButton in top right AppBar actions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WorkoutSplitPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final syncButton = find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(CompactSyncButton),
      );
      expect(syncButton, findsOneWidget);
    });

    testWidgets('WorkoutSchedulePage has CompactSyncButton in top right AppBar actions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WorkoutSchedulePage(split: 'Bro Split'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final syncButton = find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(CompactSyncButton),
      );
      expect(syncButton, findsOneWidget);
    });
  });

  group('GoogleDriveService SyncState Notification Transitions', () {
    test('syncDailyRecordsToDriveInBackground sets syncState to syncing immediately', () async {
      final driveService = GoogleDriveService();
      driveService.syncStateNotifier.value = SyncState.synced;

      // Call background sync with standard debounce
      driveService.syncDailyRecordsToDriveInBackground(debounce: const Duration(seconds: 10));

      expect(driveService.syncStateNotifier.value, equals(SyncState.syncing));

      driveService.cancelPendingSync();
      expect(driveService.syncStateNotifier.value, equals(SyncState.synced));
    });

    test('manualSyncToExcel sets syncState to syncing then synced or error', () async {
      final driveService = GoogleDriveService();
      driveService.simulateSyncFailure = true;

      final result = await driveService.manualSyncToExcel();
      expect(result, equals(SyncState.error));
      expect(driveService.syncStateNotifier.value, equals(SyncState.error));

      driveService.simulateSyncFailure = false;
      final resultSuccess = await driveService.manualSyncToExcel();
      expect(resultSuccess, equals(SyncState.synced));
      expect(driveService.syncStateNotifier.value, equals(SyncState.synced));
    });
  });
}
