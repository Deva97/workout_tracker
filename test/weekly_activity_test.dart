import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/data/services/google_drive_service.dart';
import 'package:workout_tracker/domain/models/daily_record.dart';
import 'package:workout_tracker/domain/repositories/workout_repository.dart';
import 'package:workout_tracker/ui/core/theme/app_colors.dart';
import 'package:workout_tracker/ui/features/weekly_activity/view_models/weekly_activity_view_model.dart';
import 'package:workout_tracker/ui/features/weekly_activity/views/weekly_activity_section.dart';

class _WeeklyActivityRepository extends Fake implements WorkoutRepository {
  _WeeklyActivityRepository(this.records);

  final List<DailyRecord> records;

  @override
  Future<List<DailyRecord>> getWeeklyDailyRecords([
    DateTime? referenceDate,
  ]) async => records;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WeeklyActivityViewModel', () {
    test('marks logged days in the current Monday-to-Sunday week', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final monday = today.subtract(Duration(days: now.weekday - 1));
      final wednesday = monday.add(const Duration(days: 2));
      final repository = _WeeklyActivityRepository([
        DailyRecord(
          id: 'monday-record',
          workoutId: 'exercise-1',
          workoutName: 'Workout',
          date: monday,
          set: 1,
          reps: 8,
          rir: 2,
        ),
        DailyRecord(
          id: 'wednesday-record',
          workoutId: 'exercise-1',
          workoutName: 'Workout',
          date: DateTime(
            wednesday.year,
            wednesday.month,
            wednesday.day,
            23,
            59,
          ),
          set: 1,
          reps: 8,
          rir: 2,
        ),
      ]);
      final viewModel = WeeklyActivityViewModel(workoutRepository: repository);

      await viewModel.loadWeeklyActivity();

      expect(viewModel.weekActivity, hasLength(7));
      expect(viewModel.weekActivity['Mon'], isTrue);
      expect(viewModel.weekActivity['Wed'], isTrue);
      expect(viewModel.weekActivity['Sun'], isFalse);
      expect(viewModel.streakCount, 2);

      viewModel.dispose();
    });

    test(
      'retains completed dates after the daily cache purges history',
      () async {
        final referenceDate = DateTime(2020, 1, 8);
        final record = DailyRecord(
          id: 'older-set',
          workoutId: 'exercise-1',
          workoutName: 'Workout',
          date: DateTime(2020, 1, 8, 18),
          set: 1,
          reps: 8,
          rir: 2,
        );
        SharedPreferences.setMockInitialValues({
          'daily_record_cache': jsonEncode([record.toMap()]),
        });
        final driveService = GoogleDriveService();

        expect(
          (await driveService.getWeeklyDailyRecords(referenceDate))
              .map((r) => r.id),
          contains('older-set'),
        );
        expect(await driveService.getDailyRecords(), isEmpty);
        expect(
          (await driveService.getWeeklyDailyRecords(referenceDate))
              .map((r) => r.id),
          contains('older-set'),
        );
      },
    );
  });

  group('WeeklyActivitySection', () {
    testWidgets('shows a local loader while weekly data is loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WeeklyActivitySection(
              weekActivity: {},
              streakCount: 0,
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Week ${DateFormat('w').format(DateTime.now())}'), findsOneWidget);
    });

    testWidgets('renders active day indicators and the session count', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeeklyActivitySection(
              weekActivity: {
                'Mon': true,
                'Tue': true,
                'Wed': false,
                'Thu': true,
                'Fri': false,
                'Sat': false,
                'Sun': false,
              },
              streakCount: 3,
            ),
          ),
        ),
      );

      expect(find.text('3-Session Consistency'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNWidgets(3));
    });

    testWidgets('shows completed days green and missed past days red', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeeklyActivitySection(
              currentDate: DateTime(2026, 10, 1),
              weekActivity: {
                'Mon': true,
                'Tue': false,
                'Wed': false,
                'Thu': false,
                'Fri': false,
                'Sat': false,
                'Sun': false,
              },
              streakCount: 1,
            ),
          ),
        ),
      );

      final completed = tester.widget<Container>(
        find.byKey(const ValueKey('weekly-activity-Mon')),
      );
      final missed = tester.widget<Container>(
        find.byKey(const ValueKey('weekly-activity-Tue')),
      );
      expect((completed.decoration! as BoxDecoration).color, AppColors.success);
      expect((missed.decoration! as BoxDecoration).color, AppColors.error);
    });
  });
}
