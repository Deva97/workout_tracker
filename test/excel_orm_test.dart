import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/data/context/workout_db_context.dart';
import 'package:workout_tracker/domain/models/daily_record.dart';
import 'package:workout_tracker/domain/models/exercise.dart';

void main() {
  group('ExcelORM - Query Builder & Filtering Tests', () {
    late List<Exercise> sampleExercises;

    setUp(() {
      sampleExercises = [
        Exercise(guid: '1', name: 'Bench Press', bodyPart: 'Chest'),
        Exercise(guid: '2', name: 'Incline Dumbbell Press', bodyPart: 'Chest'),
        Exercise(guid: '3', name: 'Barbell Row', bodyPart: 'Back'),
        Exercise(guid: '4', name: 'Lat Pulldown', bodyPart: 'Back'),
        Exercise(guid: '5', name: 'Overhead Press', bodyPart: 'Shoulders'),
        Exercise(guid: '6', name: 'Squat', bodyPart: 'Legs'),
        Exercise(guid: '7', name: 'Barbell Curl', bodyPart: 'Biceps'),
      ];
    });

    test('where filtering works correctly', () {
      final context = WorkoutDbContext();
      context.exercises.addAll(sampleExercises);

      final chestExercises = context.exercises.whereQuery((e) => e.bodyPart == 'Chest').toList();
      expect(chestExercises.length, equals(2));
      expect(chestExercises.map((e) => e.name), containsAll(['Bench Press', 'Incline Dumbbell Press']));
    });

    test('orderBy and orderByDescending work correctly', () {
      final context = WorkoutDbContext();
      context.exercises.addAll(sampleExercises);

      final sortedAsc = context.exercises.orderBy((e) => e.name).toList();
      expect(sortedAsc.first.name, equals('Barbell Curl'));
      expect(sortedAsc.last.name, equals('Squat'));

      final sortedDesc = context.exercises.orderByDescending((e) => e.name).toList();
      expect(sortedDesc.first.name, equals('Squat'));
      expect(sortedDesc.last.name, equals('Barbell Curl'));
    });

    test('skip and take pagination work correctly', () {
      final context = WorkoutDbContext();
      context.exercises.addAll(sampleExercises);

      final page = context.exercises.orderBy((e) => e.name).skip(2).take(3).toList();
      expect(page.length, equals(3));
    });

    test('firstOrDefault, count, any, and all work correctly', () {
      final context = WorkoutDbContext();
      context.exercises.addAll(sampleExercises);

      final squat = context.exercises.firstOrDefault((e) => e.name == 'Squat');
      expect(squat, isNotNull);
      expect(squat!.bodyPart, equals('Legs'));

      final missing = context.exercises.firstOrDefault((e) => e.name == 'NonExistent');
      expect(missing, isNull);

      expect(context.exercises.query().count((e) => e.bodyPart == 'Back'), equals(2));
      expect(context.exercises.query().any((e) => e.name == 'Barbell Row'), isTrue);
      expect(context.exercises.query().all((e) => e.guid.isNotEmpty), isTrue);
    });
  });

  group('ExcelORM - Table Repository CRUD Operations', () {
    test('add, update, delete operations track state correctly', () {
      final context = WorkoutDbContext();

      // Add
      final ex1 = Exercise(guid: '101', name: 'Deadlift', bodyPart: 'Back');
      context.exercises.add(ex1);
      expect(context.exercises.length, equals(1));

      // Update
      final updatedEx1 = Exercise(guid: '101', name: 'Sumo Deadlift', bodyPart: 'Back');
      final updated = context.exercises.update(updatedEx1, (e) => e.guid == '101');
      expect(updated, isTrue);
      expect(context.exercises.first.name, equals('Sumo Deadlift'));

      // Delete
      final deleted = context.exercises.deleteWhere((e) => e.guid == '101');
      expect(deleted, equals(1));
      expect(context.exercises.isEmpty, isTrue);
    });
  });

  group('ExcelORM - Context Excel Bytes Encoding & Decoding', () {
    test('Exercise_DB.xlsx roundtrip encoding and decoding preserves data', () {
      final context = WorkoutDbContext();
      context.exercises.addAll([
        Exercise(guid: 'ex-1', name: 'Push Up', bodyPart: 'Chest'),
        Exercise(guid: 'ex-2', name: 'Pull Up', bodyPart: 'Back'),
      ]);

      // Encode table to Excel bytes
      final bytes = context.saveExerciseDbToBytes();
      expect(bytes, isNotEmpty);

      // Create new context and decode bytes
      final restoredContext = WorkoutDbContext();
      restoredContext.loadExerciseDbFromBytes(bytes);

      expect(restoredContext.exercises.length, equals(2));
      expect(restoredContext.exercises.first.guid, equals('ex-1'));
      expect(restoredContext.exercises.first.name, equals('Push Up'));
      expect(restoredContext.exercises.first.bodyPart, equals('Chest'));
      expect(restoredContext.exercises.last.name, equals('Pull Up'));
    });

    test('Daily_record.xlsx roundtrip encoding and decoding preserves typed fields', () {
      final now = DateTime(2026, 9, 1, 10, 30);
      final context = WorkoutDbContext();
      context.dailyRecords.add(
        DailyRecord(
          id: 'rec-1',
          workoutId: 'w-101',
          workoutName: 'Chest Day',
          date: now,
          set: 1,
          reps: 10,
          rir: 2.0,
          weight: 75.5,
        ),
      );

      final bytes = context.saveDailyRecordToBytes();
      expect(bytes, isNotEmpty);

      final restoredContext = WorkoutDbContext();
      restoredContext.loadDailyRecordFromBytes(bytes);

      expect(restoredContext.dailyRecords.length, equals(1));
      final record = restoredContext.dailyRecords.first;
      expect(record.id, equals('rec-1'));
      expect(record.workoutId, equals('w-101'));
      expect(record.workoutName, equals('Chest Day'));
      expect(record.set, equals(1));
      expect(record.reps, equals(10));
      expect(record.rir, equals(2.0));
      expect(record.weight, equals(75.5));
    });
  });
}

