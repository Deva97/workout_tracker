import '../models/exercise.dart';
import '../repositories/exercise_repository.dart';

class ManageExercisesUseCase {
  final ExerciseRepository _exerciseRepository;

  ManageExercisesUseCase({
    required this._exerciseRepository,
  });

  Future<List<Exercise>> getExercises() => _exerciseRepository.getExercises();

  List<Exercise> getCachedExercises() => _exerciseRepository.getCachedExercises();

  List<Exercise> queryExercises({String? category, String? searchQuery}) =>
      _exerciseRepository.queryExercises(category: category, searchQuery: searchQuery);

  Future<Exercise> addExercise(String name, String bodyPart) =>
      _exerciseRepository.addExercise(name, bodyPart);

  Future<void> deleteExercise(String guid) =>
      _exerciseRepository.deleteExercise(guid);

  Future<void> syncFromDrive() => _exerciseRepository.syncFromDrive();
}
