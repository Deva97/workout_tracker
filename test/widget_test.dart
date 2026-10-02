import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/ui/features/home/views/home_screen.dart';
import 'package:workout_tracker/ui/features/workout_split/views/workout_schedule_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows today\'s saved workout on the landing page',
      (tester) async {
    final today = DateFormat('EEEE', 'en_US').format(DateTime.now());
    SharedPreferences.setMockInitialValues({
      'workout_schedule': jsonEncode({today: 'Push'}),
    });

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text("Today's Focus"), findsOneWidget);
    expect(find.text('Push'), findsOneWidget);
  });

  testWidgets('shows Rest when today has no saved workout', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text("Today's Focus"), findsOneWidget);
    expect(find.text('Rest'), findsOneWidget);
  });

  testWidgets('selecting a split opens the seven-day schedule', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.dragUntilVisible(
      find.text('Workout Split & Schedule'),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workout Split & Schedule'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bro Split'));
    await tester.pumpAndSettle();

    expect(find.text('Monday'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Sunday'), findsOneWidget);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('split_choice'), 'Bro Split');
  });

  testWidgets('Bro Split shows muscle choices and saves a day assignment',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: WorkoutSchedulePage(split: 'Bro Split')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monday'));
    await tester.pumpAndSettle();

    expect(find.text('Legs'), findsOneWidget);
    expect(find.text('Shoulders'), findsOneWidget);
    expect(find.text('Triceps'), findsOneWidget);
    expect(find.text('Chest'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Biceps'), findsOneWidget);

    await tester.tap(find.text('Chest'));
    await tester.pumpAndSettle();

    expect(find.text('Target: Chest'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    final schedule = jsonDecode(
      preferences.getString('workout_schedule')!,
    ) as Map<String, dynamic>;
    expect(schedule['Monday'], 'Chest');
  });

  testWidgets('Pull-Push Split only offers Push and Pull', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WorkoutSchedulePage(split: 'Pull-Push Split'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monday'));
    await tester.pumpAndSettle();

    expect(find.text('Push'), findsOneWidget);
    expect(find.text('Pull'), findsOneWidget);
    expect(find.text('Legs'), findsNothing);
    expect(find.text('Anterior'), findsNothing);
  });

  testWidgets('Full Body Split prevents a fourth workout day', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WorkoutSchedulePage(split: 'Full Body Split'),
      ),
    );
    await tester.pumpAndSettle();

    for (final day in ['Monday', 'Tuesday', 'Wednesday']) {
      await tester.tap(find.text(day));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Full Body').last);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Thursday'));
    await tester.pumpAndSettle();
    expect(find.text('Maximum of 3 workout days reached for Full Body Split.'),
        findsOneWidget);
  });

  testWidgets('restores saved weekly assignments', (tester) async {
    SharedPreferences.setMockInitialValues({
      'split_choice': 'Bro Split',
      'workout_schedule': jsonEncode({'Monday': 'Back'}),
    });

    await tester.pumpWidget(
      const MaterialApp(home: WorkoutSchedulePage(split: 'Bro Split')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Target: Back'), findsOneWidget);
    expect(find.text('Rest Day'), findsAtLeastNWidgets(5));
  });
}
