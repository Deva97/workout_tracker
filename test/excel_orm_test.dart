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
      context.replaceExercises(sampleExercises);

      final chestExercises = context.queryExercises().where((e) => e.bodyPart == 'Chest').toList();
      expect(chestExercises.length, equals(2));
      expect(chestExercises.map((e) => e.name), containsAll(['Bench Press', 'Incline Dumbbell Press']));
    });

    test('orderBy and orderByDescending work correctly', () {
      final context = WorkoutDbContext();
      context.replaceExercises(sampleExercises);

      final sortedAsc = context.queryExercises().orderBy((e) => e.name).toList();
      expect(sortedAsc.first.name, equals('Barbell Curl'));
      expect(sortedAsc.last.name, equals('Squat'));

      final sortedDesc = context.queryExercises().orderByDescending((e) => e.name).toList();
      expect(sortedDesc.first.name, equals('Squat'));
      expect(sortedDesc.last.name, equals('Barbell Curl'));
    });

    test('skip and take pagination work correctly', () {
      final context = WorkoutDbContext();
      context.replaceExercises(sampleExercises);

      final page = context.queryExercises().orderBy((e) => e.name).skip(2).take(3).toList();
      expect(page.length, equals(3));
    });

    test('firstOrDefault, count, any, and all work correctly', () {
      final context = WorkoutDbContext();
      context.replaceExercises(sampleExercises);

      final squat = context.firstExerciseOrDefault((e) => e.name == 'Squat');
      expect(squat, isNotNull);
      expect(squat!.bodyPart, equals('Legs'));

      final missing = context.firstExerciseOrDefault((e) => e.name == 'NonExistent');
      expect(missing, isNull);

      expect(context.queryExercises().count((e) => e.bodyPart == 'Back'), equals(2));
      expect(context.queryExercises().any((e) => e.name == 'Barbell Row'), isTrue);
      expect(context.queryExercises().all((e) => e.guid.isNotEmpty), isTrue);
    });
  });

  group('ExcelORM - Table Repository CRUD Operations', () {
    test('exercise context CRUD operations track state correctly', () {
      final context = WorkoutDbContext();

      final ex1 = Exercise(guid: '101', name: 'Deadlift', bodyPart: 'Back');
      context.addExercise(ex1);
      expect(context.readExercises().length, equals(1));

      final updatedEx1 = Exercise(guid: '101', name: 'Sumo Deadlift', bodyPart: 'Back');
      expect(context.updateExercise(updatedEx1, (e) => e.guid == '101'), isTrue);
      expect(context.readExercises().first.name, equals('Sumo Deadlift'));

      expect(context.deleteExercisesWhere((e) => e.guid == '101'), equals(1));
      expect(context.readExercises().isEmpty, isTrue);
      expect(context.updateExercise(ex1, (e) => e.guid == 'missing'), isFalse);
    });

    test('daily record context CRUD operations track state correctly', () {
      final context = WorkoutDbContext();
      final record = DailyRecord(
        id: 'record-1',
        workoutId: 'exercise-1',
        workoutName: 'Deadlift',
        date: DateTime(2026, 9, 1),
        set: 1,
        reps: 5,
        rir: 2,
        weight: 100,
      );
      context.addDailyRecord(record);

      final updated = DailyRecord(
        id: 'record-1',
        workoutId: 'exercise-1',
        workoutName: 'Deadlift',
        date: record.date,
        set: 1,
        reps: 5,
        rir: 1,
        weight: 105,
      );
      expect(context.updateDailyRecord(updated, (existing) => existing.id == record.id), isTrue);
      expect(context.readDailyRecords().first.weight, equals(105));
      expect(context.deleteDailyRecordsWhere((existing) => existing.id == record.id), equals(1));
      expect(context.readDailyRecords(), isEmpty);
      expect(context.deleteDailyRecordsWhere((existing) => existing.id == record.id), equals(0));
    });

    test('replace operations snapshot input and replace existing rows', () {
      final context = WorkoutDbContext();
      context.addExercise(Exercise(guid: 'old', name: 'Old', bodyPart: 'Back'));

      context.replaceExercises([
        Exercise(guid: 'new', name: 'New', bodyPart: 'Chest'),
      ]);

      expect(context.readExercises().map((exercise) => exercise.guid), ['new']);
    });
  });

  group('ExcelORM - Context Excel Bytes Encoding & Decoding', () {
    test('Exercise_DB.xlsx roundtrip encoding and decoding preserves data', () {
      final context = WorkoutDbContext();
      context.replaceExercises([
        Exercise(guid: 'ex-1', name: 'Push Up', bodyPart: 'Chest'),
        Exercise(guid: 'ex-2', name: 'Pull Up', bodyPart: 'Back'),
      ]);

      // Encode table to Excel bytes
      final bytes = context.saveExerciseDbToBytes();
      expect(bytes, isNotEmpty);

      // Create new context and decode bytes
      final restoredContext = WorkoutDbContext();
      restoredContext.loadExerciseDbFromBytes(bytes);

      expect(restoredContext.readExercises().length, equals(2));
      expect(restoredContext.readExercises().first.guid, equals('ex-1'));
      expect(restoredContext.readExercises().first.name, equals('Push Up'));
      expect(restoredContext.readExercises().first.bodyPart, equals('Chest'));
      expect(restoredContext.readExercises().last.name, equals('Pull Up'));
    });

    test('Daily_record.xlsx roundtrip encoding and decoding preserves typed fields', () {
      final now = DateTime(2026, 9, 1, 10, 30);
      final context = WorkoutDbContext();
      context.addDailyRecord(
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

      expect(restoredContext.readDailyRecords().length, equals(1));
      final record = restoredContext.readDailyRecords().first;
      expect(record.id, equals('rec-1'));
      expect(record.workoutId, equals('w-101'));
      expect(record.workoutName, equals('Chest Day'));
      expect(record.set, equals(1));
      expect(record.reps, equals(10));
      expect(record.rir, equals(2.0));
      expect(record.weight, equals(75.5));
    });

    test('recent daily rows load backwards and stop before the date boundary', () {
      final context = WorkoutDbContext();
      DailyRecord record(String id, DateTime date) => DailyRecord(
            id: id,
            workoutId: 'exercise-1',
            workoutName: 'Workout',
            date: date,
            set: 1,
            reps: 8,
            rir: 2,
          );
      context.replaceDailyRecords([
        record('older-1', DateTime(2026, 9, 20)),
        record('older-2', DateTime(2026, 9, 27)),
        record('monday', DateTime(2026, 9, 28)),
        record('friday', DateTime(2026, 10, 2)),
        record('saturday', DateTime(2026, 10, 3)),
      ]);
      final bytes = context.saveDailyRecordToBytes();
      var scannedRecords = 0;

      final recentRecords = context
          .loadTableFromBytes<DailyRecord>(
            bytes: bytes,
            mapper: DailyRecord.excelMapper,
            sheetName: 'Sheet1',
            reverseRows: true,
            stopWhen: (record) {
              scannedRecords++;
              final recordDay = DateTime(
                record.date.year,
                record.date.month,
                record.date.day,
              );
              return recordDay.isBefore(DateTime(2026, 9, 28));
            },
          )
          .toList();

      expect(recentRecords.map((record) => record.id), ['monday', 'friday', 'saturday']);
      expect(scannedRecords, 4);
    });
  });
}

