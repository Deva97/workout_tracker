import '../models/daily_record.dart';
import '../repositories/workout_repository.dart';

class ManageWorkoutSetUseCase {
  final WorkoutRepository _workoutRepository;

  ManageWorkoutSetUseCase({
    required this._workoutRepository,
  });

  Future<DailyRecord> addSet(DailyRecord record) {
    return _workoutRepository.addDailyRecord(record);
  }

  Future<DailyRecord> editSet(DailyRecord record) {
    return _workoutRepository.editDailyRecord(record);
  }

  Future<void> deleteSet(String id) {
    return _workoutRepository.deleteDailyRecord(id);
  }
}
