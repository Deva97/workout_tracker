import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String keyExerciseCache = 'exercise_cache';
  static const String keyDailyRecordCache = 'daily_record_cache';
  static const String keyWorkoutFolderId = 'workout_folder_id';
  static const String keyExerciseFileId = 'exercise_file_id';
  static const String keyDailyRecordFileId = 'daily_record_file_id';
  static const String keyWorkoutSchedule = 'workout_schedule';
  static const String keySplitChoice = 'split_choice';
  static const String keyThemeMode = 'theme_mode';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String?> getString(String key) async {
    final prefs = await _prefs;
    return prefs.getString(key);
  }

  Future<bool> setString(String key, String value) async {
    final prefs = await _prefs;
    return prefs.setString(key, value);
  }

  Future<bool> remove(String key) async {
    final prefs = await _prefs;
    return prefs.remove(key);
  }

  // Schedule & Split specific helpers
  Future<String> getSelectedSplit() async {
    final val = await getString(keySplitChoice);
    return val ?? 'Bro Split';
  }

  Future<void> setSelectedSplit(String split) async {
    await setString(keySplitChoice, split);
  }

  Future<Map<String, String>> getWorkoutSchedule() async {
    final raw = await getString(keyWorkoutSchedule);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map<String, String>(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
      }
    } catch (_) {}
    return {};
  }

  Future<void> setWorkoutSchedule(Map<String, String> schedule) async {
    await setString(keyWorkoutSchedule, jsonEncode(schedule));
  }

  Future<Map<String, String>> getWeeklySchedule() => getWorkoutSchedule();

  Future<void> setWeeklySchedule(Map<String, String> schedule) => setWorkoutSchedule(schedule);

  // Theme mode specific helpers
  Future<String?> getThemeMode() => getString(keyThemeMode);

  Future<void> setThemeMode(String themeMode) => setString(keyThemeMode, themeMode);
}
