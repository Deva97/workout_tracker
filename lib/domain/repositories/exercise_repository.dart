import '../models/exercise.dart';

abstract class ExerciseRepository {
  Future<List<Exercise>> getExercises();
  Future<Exercise> addExercise(String name, String bodyPart);
  Future<void> deleteExercise(String guid);
  Future<void> syncFromDrive();
  List<Exercise> getCachedExercises();
  Exercise? getExerciseById(String guid);
  List<Exercise> queryExercises({String? category, String? searchQuery});
}
