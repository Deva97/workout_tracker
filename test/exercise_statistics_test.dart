import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/domain/models/daily_record.dart';
import 'package:workout_tracker/domain/models/exercise.dart';
import 'package:workout_tracker/ui/features/home/views/home_screen.dart';
import 'package:workout_tracker/ui/features/workout_log/views/exercise_statistics_screen.dart';
import 'package:workout_tracker/ui/features/workout_log/views/widgets/strength_trend_chart.dart';
import 'package:workout_tracker/data/services/google_drive_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleDriveService().dbContext.exercises.clear();
    GoogleDriveService().dbContext.dailyRecords.clear();
    GoogleDriveService().syncStateNotifier.value = SyncState.synced;
  });

  group('Exercise Statistics - ORM History Query Tests', () {
    test('queryExerciseHistory returns records matching workoutId within timeframe limit', () async {
      final driveService = GoogleDriveService();
      final now = DateTime.now();
      final date15d = now.subtract(const Duration(days: 15));
      final date40d = now.subtract(const Duration(days: 40));

      final recBenchRecent = DailyRecord(
        id: 'r-bench-1',
        workoutId: 'ex-bench',
        workoutName: 'Bench Press',
        date: date15d,
        set: 1,
        reps: 10,
        rir: 2.0,
        weight: 80.0,
      );

      final recBenchOld = DailyRecord(
        id: 'r-bench-2',
        workoutId: 'ex-bench',
        workoutName: 'Bench Press',
        date: date40d,
        set: 1,
        reps: 8,
        rir: 1.0,
        weight: 75.0,
      );

      final recSquat = DailyRecord(
        id: 'r-squat-1',
        workoutId: 'ex-squat',
        workoutName: 'Squat',
        date: date15d,
        set: 1,
        reps: 12,
        rir: 2.0,
        weight: 100.0,
      );

      driveService.dbContext.dailyRecords.addAll([recBenchRecent, recBenchOld, recSquat]);

      // Query for Bench Press in 30 days limit
      final history30d = await driveService.queryExerciseHistory('ex-bench', daysLimit: 30);
      expect(history30d.length, equals(1));
      expect(history30d.first.id, equals('r-bench-1'));

      // Query for Bench Press in 60 days limit
      final history60d = await driveService.queryExerciseHistory('ex-bench', daysLimit: 60);
      expect(history60d.length, equals(2));
    });
  });

  group('ExerciseStatisticsScreen - Widget UI Tests', () {
    testWidgets('Renders empty state when no exercises exist', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ExerciseStatisticsScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Exercise Statistics'), findsOneWidget);
      expect(find.text('No Exercises Found'), findsOneWidget);
    });

    testWidgets('Renders exercise selector, date range chips, and StrengthTrendChart when data exists',
        (tester) async {
      final driveService = GoogleDriveService();
      final benchPress = Exercise(
        guid: 'ex-bench',
        name: 'Bench Press',
        bodyPart: 'Chest',
      );

      final now = DateTime.now();
      final record = DailyRecord(
        id: 'r-1',
        workoutId: benchPress.guid,
        workoutName: 'Bench Press',
        date: now.subtract(const Duration(days: 10)),
        set: 1,
        reps: 10,
        rir: 2.0,
        weight: 80.0,
      );

      SharedPreferences.setMockInitialValues({
        'exercise_cache': jsonEncode([benchPress.toMap()]),
      });
      driveService.dbContext.exercises.add(benchPress);
      driveService.dbContext.dailyRecords.add(record);

      await tester.pumpWidget(
        MaterialApp(
          home: ExerciseStatisticsScreen(initialExerciseGuid: benchPress.guid),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Bench Press'), findsAtLeastNWidgets(1));
      expect(find.text('1 Month'), findsOneWidget);
      expect(find.text('Graph'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
      expect(find.byType(StrengthTrendChart), findsOneWidget);
    });

    testWidgets('Toggles between Graph and Details view mode correctly', (tester) async {
      final driveService = GoogleDriveService();
      final benchPress = Exercise(
        guid: 'ex-bench-2',
        name: 'Bench Press',
        bodyPart: 'Chest',
      );

      final now = DateTime.now();
      final record = DailyRecord(
        id: 'r-2',
        workoutId: benchPress.guid,
        workoutName: 'Bench Press',
        date: now.subtract(const Duration(days: 2)),
        set: 1,
        reps: 10,
        rir: 2.0,
        weight: 80.0,
      );

      SharedPreferences.setMockInitialValues({
        'exercise_cache': jsonEncode([benchPress.toMap()]),
      });
      driveService.dbContext.exercises.add(benchPress);
      driveService.dbContext.dailyRecords.add(record);

      await tester.pumpWidget(
        MaterialApp(
          home: ExerciseStatisticsScreen(initialExerciseGuid: benchPress.guid),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Graph view initially visible
      expect(find.byType(StrengthTrendChart), findsOneWidget);

      // Tap Details tab
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      // Details view visible with raw logs
      expect(find.byType(StrengthTrendChart), findsNothing);
      expect(find.text('Set 1'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('10'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('80.0 kg'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('HomeScreen has Exercise Statistics card and does NOT have Previous Week History card',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Previous Week History'), findsNothing);

      await tester.dragUntilVisible(
        find.text('Exercise Statistics & Progress'),
        find.byType(CustomScrollView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      expect(find.text('Exercise Statistics & Progress'), findsOneWidget);

      await tester.tap(find.text('Exercise Statistics & Progress'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Exercise Statistics'), findsOneWidget);
    });
  });
}
