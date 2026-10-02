import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/domain/models/daily_record.dart';
import 'package:workout_tracker/ui/features/workout_log/views/widgets/rest_timer_widget.dart';
import 'package:workout_tracker/ui/features/workout_log/views/widgets/strength_trend_chart.dart';
import 'package:workout_tracker/data/services/google_drive_service.dart';
import 'package:workout_tracker/ui/core/theme/app_colors.dart';
import 'package:workout_tracker/ui/core/theme/app_theme.dart';
import 'package:workout_tracker/ui/core/widgets/weekly_streak_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final driveService = GoogleDriveService();
    driveService.dbContext.exercises.clear();
    driveService.dbContext.dailyRecords.clear();
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

  group('WeeklyStreakWidget Tests', () {
    testWidgets('Renders weekly consistency dots and status correctly', (tester) async {
      final activity = {
        'Mon': true,
        'Tue': true,
        'Wed': false,
        'Thu': true,
        'Fri': false,
        'Sat': false,
        'Sun': false,
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: WeeklyStreakWidget(
              weekActivity: activity,
              streakCount: 3,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('3-Session Consistency'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNWidgets(3));
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
      driveService.dbContext.dailyRecords.addAll([recYesterday, recToday]);

      // Query history for 30 days
      final history = await driveService.queryExerciseHistory('ex-bench', daysLimit: 30);
      expect(history.length, equals(2));
    });
  });
}
