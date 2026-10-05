abstract class WorkoutSplitRepository {
  Future<String> getSelectedSplit();
  Future<void> saveSelectedSplit(String split);
  Future<int?> getSplitTargetDays();
  Future<void> saveSplitTargetDays(int days);
  Future<Map<String, String>> getWeeklySchedule();
  Future<void> saveWeeklySchedule(Map<String, String> schedule);
  Future<String> getTodaysFocus();
}
