import '../../domain/models/exercise.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../services/google_drive_service.dart';

class ExerciseRepositoryImpl implements ExerciseRepository {
  final GoogleDriveService _driveService;

  ExerciseRepositoryImpl({GoogleDriveService? driveService})
      : _driveService = driveService ?? GoogleDriveService();

  @override
  Future<List<Exercise>> getExercises() {
    return _driveService.getExercises();
  }

  @override
  Future<Exercise> addExercise(String name, String bodyPart) {
    return _driveService.addExercise(name, bodyPart);
  }

  @override
  Future<void> deleteExercise(String guid) {
    return _driveService.deleteExercise(guid);
  }

  @override
  Future<void> syncFromDrive() {
    return _driveService.syncFromDrive();
  }

  @override
  List<Exercise> getCachedExercises() {
    return _driveService.dbContext.exercises.toList();
  }

  @override
  Exercise? getExerciseById(String guid) {
    return _driveService.getExerciseById(guid);
  }

  @override
  List<Exercise> queryExercises({String? category, String? searchQuery}) {
    var query = _driveService.queryExercises(
      category: category,
      searchQuery: searchQuery,
    );
    return query.orderBy((e) => e.name).toList();
  }
}
