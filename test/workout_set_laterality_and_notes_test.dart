import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/data/context/workout_db_context.dart';
import 'package:workout_tracker/domain/models/daily_record.dart';
import 'package:workout_tracker/domain/models/exercise.dart';
import 'package:workout_tracker/ui/core/theme/app_theme.dart';
import 'package:workout_tracker/ui/features/workout_log/views/widgets/add_workout_set_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Domain & Data: DailyRecord Laterality & Notes Serialization', () {
    test('DailyRecord defaults to bilateral execution and empty notes', () {
      final record = DailyRecord(
        id: 'rec-1',
        workoutId: 'ex-1',
        workoutName: 'Barbell Squat',
        date: DateTime(2026, 10, 12),
        set: 1,
        reps: 8,
        rir: 2.0,
        weight: 100.0,
      );

      expect(record.executionType, equals('bilateral'));
      expect(record.notes, equals(''));
    });

    test('DailyRecord copyWith updates executionType and notes', () {
      final record = DailyRecord(
        id: 'rec-1',
        workoutId: 'ex-1',
        workoutName: 'Dumbbell Curl',
        date: DateTime(2026, 10, 12),
        set: 1,
        reps: 12,
        rir: 1.0,
        weight: 14.0,
      );

      final updated = record.copyWith(
        executionType: 'unilateral-left',
        notes: 'Slight elbow swing on rep 12',
      );

      expect(updated.executionType, equals('unilateral-left'));
      expect(updated.notes, equals('Slight elbow swing on rep 12'));
      expect(updated.weight, equals(14.0));
      expect(updated.reps, equals(12));
    });

    test('DailyRecord toMap and fromMap serialize execution_type and notes', () {
      final original = DailyRecord(
        id: 'rec-uni-r',
        workoutId: 'ex-lunge',
        workoutName: 'Bulgarian Split Squat',
        date: DateTime(2026, 10, 12, 18, 30),
        set: 3,
        reps: 10,
        rir: 1.5,
        weight: 24.0,
        executionType: 'unilateral-right',
        notes: 'Paused 1s at bottom',
      );

      final map = original.toMap();
      expect(map['execution_type'], equals('unilateral-right'));
      expect(map['notes'], equals('Paused 1s at bottom'));

      final restored = DailyRecord.fromMap(map);
      expect(restored.id, equals(original.id));
      expect(restored.executionType, equals('unilateral-right'));
      expect(restored.notes, equals('Paused 1s at bottom'));
      expect(restored, equals(original));
    });

    test('DailyRecord fromMap provides backward compatibility for legacy records missing new fields', () {
      final legacyMap = {
        'ID': 'legacy-rec',
        'workout_ID': 'ex-bench',
        'workout_name': 'Bench Press',
        'Date': '2026-10-10T10:00:00.000',
        'set': 2,
        'reps': 8,
        'RIR': 2.0,
        'weight': 80.0,
      };

      final restored = DailyRecord.fromMap(legacyMap);
      expect(restored.executionType, equals('bilateral'));
      expect(restored.notes, equals(''));
    });

    test('DailyRecord.excelMapper encodes and decodes execution_type and notes schema columns', () {
      final record = DailyRecord(
        id: 'orm-test-1',
        workoutId: 'ex-press',
        workoutName: 'Overhead Press',
        date: DateTime(2026, 10, 12),
        set: 2,
        reps: 6,
        rir: 1.0,
        weight: 50.0,
        executionType: 'unilateral-left',
        notes: 'Strict form, no leg drive',
      );

      final cells = DailyRecord.excelMapper.toRowCells(record);
      expect(cells['execution_type'], equals('unilateral-left'));
      expect(cells['notes'], equals('Strict form, no leg drive'));

      final fromCells = DailyRecord.excelMapper.fromRow(cells);
      expect(fromCells.executionType, equals('unilateral-left'));
      expect(fromCells.notes, equals('Strict form, no leg drive'));
    });

    test('WorkoutDbContext creates default Daily_record.xlsx containing execution_type and notes headers', () {
      final context = WorkoutDbContext();
      final bytes = context.createDefaultDailyRecordBytes();
      expect(bytes, isNotEmpty);

      context.loadDailyRecordFromBytes(bytes);
      expect(DailyRecord.excelMapper.headers, contains('execution_type'));
      expect(DailyRecord.excelMapper.headers, contains('notes'));
    });
  });

  group('UI Layer: AddWorkoutSetModal Laterality & Notes Interactivity', () {
    testWidgets('Modal allows selecting Left unilateral execution and saving notes', (tester) async {
      DailyRecord? savedRecord;
      bool? savedKeepOpen;

      final testExercise = Exercise(
        guid: 'ex-dumbbell-curl',
        name: 'Dumbbell Curl',
        bodyPart: 'Biceps',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
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

      // Verify default execution type is Bilateral
      expect(find.text('Bilateral'), findsOneWidget);
      expect(find.text('Left'), findsOneWidget);
      expect(find.text('Right'), findsOneWidget);

      // Tap 'Left' unilateral tab
      await tester.tap(find.text('Left'));
      await tester.pumpAndSettle();

      // Enter custom notes
      final notesFinder = find.widgetWithText(
        TextFormField,
        'e.g. Form cues, tempo 3-0-1, drop set on last rep...',
      );
      expect(notesFinder, findsOneWidget);
      await tester.enterText(notesFinder, 'Strict form, 3s eccentric');

      // Tap Save Set
      await tester.tap(find.text('Save Set'));
      await tester.pumpAndSettle();

      expect(savedRecord, isNotNull);
      expect(savedRecord!.executionType, equals('unilateral-left'));
      expect(savedRecord!.notes, equals('Strict form, 3s eccentric'));
      expect(savedKeepOpen, isFalse);
    });

    testWidgets('Modal allows selecting Right unilateral execution', (tester) async {
      DailyRecord? savedRecord;

      final testExercise = Exercise(
        guid: 'ex-lunge',
        name: 'Walking Lunge',
        bodyPart: 'Legs',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddWorkoutSetModal(
              availableExercises: [testExercise],
              onSaveSet: (record, keepOpen) {
                savedRecord = record;
              },
            ),
          ),
        ),
      );

      // Tap 'Right' unilateral tab
      await tester.tap(find.text('Right'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Set'));
      await tester.pumpAndSettle();

      expect(savedRecord, isNotNull);
      expect(savedRecord!.executionType, equals('unilateral-right'));
    });

    testWidgets('Editing existing unilateral record pre-fills laterality and notes', (tester) async {
      DailyRecord? updatedRecord;

      final testExercise = Exercise(
        guid: 'ex-row',
        name: 'Single Arm Cable Row',
        bodyPart: 'Back',
      );

      final initialRecord = DailyRecord(
        id: 'edit-row-1',
        workoutId: testExercise.guid,
        workoutName: testExercise.name,
        date: DateTime(2026, 10, 12),
        set: 2,
        reps: 12,
        rir: 2.0,
        weight: 35.0,
        executionType: 'unilateral-left',
        notes: 'Slight pause at contraction',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddWorkoutSetModal(
              availableExercises: [testExercise],
              editRecord: initialRecord,
              onSaveSet: (record, _) {
                updatedRecord = record;
              },
            ),
          ),
        ),
      );

      // Verify modal is in edit mode with prefilled values
      expect(find.text('Edit Workout Set'), findsOneWidget);
      expect(find.text('Slight pause at contraction'), findsOneWidget);

      // Switch from Left to Right
      await tester.tap(find.text('Right'));
      await tester.pumpAndSettle();

      // Update notes
      final notesField = find.widgetWithText(TextFormField, 'Slight pause at contraction');
      await tester.enterText(notesField, 'Switched to right side, full squeeze');

      // Tap Update Set
      await tester.tap(find.text('Update Set'));
      await tester.pumpAndSettle();

      expect(updatedRecord, isNotNull);
      expect(updatedRecord!.id, equals(initialRecord.id));
      expect(updatedRecord!.executionType, equals('unilateral-right'));
      expect(updatedRecord!.notes, equals('Switched to right side, full squeeze'));
    });
  });
}
