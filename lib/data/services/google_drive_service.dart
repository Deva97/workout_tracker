import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../context/workout_db_context.dart';
import '../../domain/models/daily_record.dart';
import '../../domain/models/daily_workout_entry.dart';
import '../../domain/models/exercise.dart';
import '../../domain/repositories/auth_repository.dart';
import '../orm/excel_query.dart';

export '../../domain/repositories/auth_repository.dart' show SyncState, DriveSheetsStatus;


class GoogleDriveService {
  // Singleton Pattern
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  static const String _cacheKey = 'exercise_cache';
  static const String _dailyRecordCacheKey = 'daily_record_cache';
  static const String _folderNameKey = 'workout_folder_id';
  static const String _fileIdKey = 'exercise_file_id';
  static const String _dailyRecordFileIdKey = 'daily_record_file_id';
  
  static const String _folderName = 'Workout Tracker';
  static const String _exerciseDbFileName = 'Exercise_DB.xlsx';
  static const String _dailyRecordFileName = 'Daily_record.xlsx';

  // Optional: Set Client ID here if needed
  static const String? _clientId = null;
  static const String? _serverClientId = null;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: _clientId,
    serverClientId: _serverClientId,
    scopes: [
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/drive',
    ],
  );

  drive.DriveApi? _driveApi;

  /// ExcelORM Database Context Instance
  final WorkoutDbContext dbContext = WorkoutDbContext();

  /// Real-time Sync State Notifier (synced, syncing, error)
  final ValueNotifier<SyncState> syncStateNotifier = ValueNotifier(SyncState.synced);

  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw Exception('Sign in cancelled by user');
      }
      
      await _initializeDriveApi(account);
      return account;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _initializeDriveApi(GoogleSignInAccount account) async {
    try {
      // Verify we can get an initial token
      final auth = await account.authentication;
      final accessToken = auth.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Failed to obtain authentication access token.');
      }
      // Pass GoogleSignIn for auto-refresh on each request
      final httpClient = GoogleAuthClient(_googleSignIn);
      _driveApi = drive.DriveApi(httpClient);
    } catch (e) {
      throw Exception('Failed to initialize Google Drive API: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _driveApi = null;
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  /// Initialize Drive API if already signed in silently
  Future<bool> initializeIfSignedIn() async {
    try {
      final signedIn = await _googleSignIn.isSignedIn();
      if (signedIn) {
        final account = _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
        if (account != null) {
          await _initializeDriveApi(account);
          return true;
        }
      }
    } catch (e) {
      debugPrint('initializeIfSignedIn: silent auth error: $e');
    }
    return false;
  }

  /// Ensure Drive API is ready before performing Drive operations
  Future<void> ensureDriveApiReady() async {
    if (_driveApi == null) {
      await initializeIfSignedIn();
    }
  }

  /// Check existence of Exercise_DB.xlsx and Daily_record.xlsx on Google Drive
  Future<DriveSheetsStatus> checkSheetsExistence() async {
    await ensureDriveApiReady();
    if (_driveApi == null) {
      throw Exception('Google Drive API not initialized. User not signed in.');
    }

    final folderId = await _getOrCreateFolder();
    final prefs = await SharedPreferences.getInstance();

    // Check Exercise_DB.xlsx
    final query1 = "name='$_exerciseDbFileName' and '$folderId' in parents and trashed=false";
    final list1 = await _driveApi!.files.list(q: query1, spaces: 'drive', pageSize: 5);
    final exerciseDbExists = list1.files != null && list1.files!.isNotEmpty;
    if (exerciseDbExists) {
      await prefs.setString(_fileIdKey, list1.files!.first.id!);
    }

    // Check Daily_record.xlsx
    final query2 = "name='$_dailyRecordFileName' and '$folderId' in parents and trashed=false";
    final list2 = await _driveApi!.files.list(q: query2, spaces: 'drive', pageSize: 5);
    final dailyRecordExists = list2.files != null && list2.files!.isNotEmpty;
    if (dailyRecordExists) {
      await prefs.setString(_dailyRecordFileIdKey, list2.files!.first.id!);
    }

    return DriveSheetsStatus(
      exerciseDbExists: exerciseDbExists,
      dailyRecordExists: dailyRecordExists,
    );
  }

  /// Create missing Excel sheets on Google Drive using ExcelORM
  Future<void> createMissingSheets({
    required bool createExerciseDb,
    required bool createDailyRecord,
  }) async {
    await ensureDriveApiReady();
    if (_driveApi == null) {
      throw Exception('Google Drive API not initialized.');
    }

    final folderId = await _getOrCreateFolder();
    final prefs = await SharedPreferences.getInstance();

    if (createExerciseDb) {
      final fileId = await _createExerciseDbExcelFile(folderId);
      await prefs.setString(_fileIdKey, fileId);
    }

    if (createDailyRecord) {
      final fileId = await _createDailyRecordExcelFile(folderId);
      await prefs.setString(_dailyRecordFileIdKey, fileId);
    }
  }

  /// Get existing folder or create new one
  Future<String> _getOrCreateFolder() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedFolderId = prefs.getString(_folderNameKey);

    if (cachedFolderId != null && _driveApi != null) {
      try {
        await _driveApi!.files.get(cachedFolderId);
        return cachedFolderId;
      } catch (e) {
        await prefs.remove(_folderNameKey);
      }
    }

    final query = "name='$_folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false";
    final fileList = await _driveApi!.files.list(
      q: query,
      spaces: 'drive',
      pageSize: 10,
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      final folderId = fileList.files!.first.id!;
      await prefs.setString(_folderNameKey, folderId);
      return folderId;
    }

    final folder = drive.File()
      ..name = _folderName
      ..mimeType = 'application/vnd.google-apps.folder';

    final createdFolder = await _driveApi!.files.create(folder);
    final folderId = createdFolder.id!;
    await prefs.setString(_folderNameKey, folderId);
    return folderId;
  }

  /// Create Exercise_DB.xlsx using ExcelORM default byte template
  Future<String> _createExerciseDbExcelFile(String folderId) async {
    final bytes = dbContext.createDefaultExerciseDbBytes();

    final driveFile = drive.File()
      ..name = _exerciseDbFileName
      ..parents = [folderId];

    final response = await _driveApi!.files.create(
      driveFile,
      uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
    );

    return response.id!;
  }

  /// Create Daily_record.xlsx using ExcelORM default byte template
  Future<String> _createDailyRecordExcelFile(String folderId) async {
    final bytes = dbContext.createDefaultDailyRecordBytes();

    final driveFile = drive.File()
      ..name = _dailyRecordFileName
      ..parents = [folderId];

    final response = await _driveApi!.files.create(
      driveFile,
      uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
    );

    return response.id!;
  }

  /// Download and sync exercises from Google Drive using ExcelORM
  Future<void> syncFromDrive() async {
    await ensureDriveApiReady();
    if (_driveApi == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      var fileId = prefs.getString(_fileIdKey);

      if (fileId == null) {
        final folderId = await _getOrCreateFolder();
        final query = "name='$_exerciseDbFileName' and '$folderId' in parents and trashed=false";
        final list = await _driveApi!.files.list(q: query, spaces: 'drive', pageSize: 5);
        if (list.files != null && list.files!.isNotEmpty) {
          fileId = list.files!.first.id!;
          await prefs.setString(_fileIdKey, fileId);
        } else {
          return;
        }
      }

      final media = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = await _readStream(media.stream);

      // Parse bytes via ExcelORM DbContext
      dbContext.loadExerciseDbFromBytes(bytes);
      final exercises = dbContext.exercises.toList();

      await _cacheExercises(exercises);

      // Also sync daily records
      await syncDailyRecordsFromDrive();
    } catch (e) {
      debugPrint('syncFromDrive: error syncing from Drive: $e');
    }
  }

  /// Upload exercises to Google Drive Exercise_DB.xlsx file using ExcelORM
  Future<void> syncToDrive(List<Exercise> exercises) async {
    await ensureDriveApiReady();
    if (_driveApi == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      var fileId = prefs.getString(_fileIdKey);

      final folderId = await _getOrCreateFolder();

      if (fileId == null) {
        final query = "name='$_exerciseDbFileName' and '$folderId' in parents and trashed=false";
        final list = await _driveApi!.files.list(q: query, spaces: 'drive', pageSize: 5);
        if (list.files != null && list.files!.isNotEmpty) {
          fileId = list.files!.first.id!;
          await prefs.setString(_fileIdKey, fileId);
        } else {
          fileId = await _createExerciseDbExcelFile(folderId);
          await prefs.setString(_fileIdKey, fileId);
        }
      }

      // Update DbContext table & encode to bytes
      dbContext.exercises.clear();
      dbContext.exercises.addAll(exercises);
      final bytes = dbContext.saveExerciseDbToBytes();

      // Upload directly from memory — no temp file needed
      await _driveApi!.files.update(
        drive.File(),
        fileId,
        uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Add a new exercise using ExcelORM and sync to Drive
  Future<Exercise> addExercise(String name, String bodyPart) async {
    final guid = const Uuid().v4();
    final exercise = Exercise(
      guid: guid,
      name: name,
      bodyPart: bodyPart,
    );

    final exercises = await getExercises();
    exercises.add(exercise);

    // Sync DbContext table
    dbContext.exercises.add(exercise);

    await _cacheExercises(exercises);

    await ensureDriveApiReady();
    if (_driveApi != null) {
      await syncToDrive(exercises);
    }

    return exercise;
  }

  /// Get all exercises from cache and sync to DbContext
  Future<List<Exercise>> getExercises() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);

    if (cached == null) return [];

    try {
      final jsonList = jsonDecode(cached) as List<dynamic>;
      final exercises = jsonList
          .map((item) => Exercise.fromMap(item as Map<String, dynamic>))
          .toList();

      dbContext.exercises.clear();
      dbContext.exercises.addAll(exercises);

      return exercises;
    } catch (e) {
      debugPrint('getExercises: error reading exercise cache: $e');
      return [];
    }
  }

  /// Delete an exercise using ExcelORM and sync to Drive
  Future<void> deleteExercise(String guid) async {
    final exercises = await getExercises();
    exercises.removeWhere((e) => e.guid == guid);

    dbContext.exercises.deleteWhere((e) => e.guid == guid);

    await _cacheExercises(exercises);

    await ensureDriveApiReady();
    if (_driveApi != null) {
      await syncToDrive(exercises);
    }
  }

  // ==================== DailyRecord Sync & Cache Methods ==================== //

  /// Filters daily records to retain ONLY entries matching today's date (year, month, day).
  List<DailyRecord> _filterTodayOnly(List<DailyRecord> records) {
    final now = DateTime.now();
    return records.where((r) {
      return r.date.year == now.year &&
          r.date.month == now.month &&
          r.date.day == now.day;
    }).toList();
  }

  /// Download and sync Daily_record.xlsx from Google Drive using ExcelORM
  Future<void> syncDailyRecordsFromDrive() async {
    await ensureDriveApiReady();
    if (_driveApi == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      var fileId = prefs.getString(_dailyRecordFileIdKey);

      if (fileId == null) {
        final folderId = await _getOrCreateFolder();
        final query = "name='$_dailyRecordFileName' and '$folderId' in parents and trashed=false";
        final list = await _driveApi!.files.list(q: query, spaces: 'drive', pageSize: 5);
        if (list.files != null && list.files!.isNotEmpty) {
          fileId = list.files!.first.id!;
          await prefs.setString(_dailyRecordFileIdKey, fileId);
        } else {
          return;
        }
      }

      final media = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = await _readStream(media.stream);

      // Parse full bytes into DbContext
      dbContext.loadDailyRecordFromBytes(bytes);
      final records = dbContext.dailyRecords.toList();

      // Enforce Purge Policy: Store ONLY today's records in local SharedPreferences cache memory
      await _cacheDailyRecords(records);
      syncStateNotifier.value = SyncState.synced;
    } catch (e) {
      syncStateNotifier.value = SyncState.error;
    }
  }

  /// Upload Daily_record.xlsx to Google Drive using merge-sync strategy.
  /// Downloads existing historical records from Drive, replaces today's entries
  /// with local records, and uploads the merged set to preserve all history.
  Future<void> syncDailyRecordsToDrive(List<DailyRecord> todayRecords) async {
    await ensureDriveApiReady();
    if (_driveApi == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      var fileId = prefs.getString(_dailyRecordFileIdKey);

      final folderId = await _getOrCreateFolder();

      if (fileId == null) {
        final query = "name='$_dailyRecordFileName' and '$folderId' in parents and trashed=false";
        final list = await _driveApi!.files.list(q: query, spaces: 'drive', pageSize: 5);
        if (list.files != null && list.files!.isNotEmpty) {
          fileId = list.files!.first.id!;
          await prefs.setString(_dailyRecordFileIdKey, fileId);
        } else {
          fileId = await _createDailyRecordExcelFile(folderId);
          await prefs.setString(_dailyRecordFileIdKey, fileId);
        }
      }

      // Merge strategy: download existing records, keep historical, replace today's
      List<DailyRecord> mergedRecords = [];
      try {
        final media = await _driveApi!.files.get(
          fileId,
          downloadOptions: drive.DownloadOptions.fullMedia,
        ) as drive.Media;
        final existingBytes = await _readStream(media.stream);

        // Parse existing records from Drive into a temporary context
        final tempContext = WorkoutDbContext();
        tempContext.loadDailyRecordFromBytes(existingBytes);
        final existingRecords = tempContext.dailyRecords.toList();

        // Keep all historical (non-today) records from Drive
        final now = DateTime.now();
        final historicalRecords = existingRecords.where((r) =>
            r.date.year != now.year ||
            r.date.month != now.month ||
            r.date.day != now.day).toList();

        // Merge: historical from Drive + today's from local
        mergedRecords = [...historicalRecords, ...todayRecords];
      } catch (e) {
        // If download fails, just upload today's records (first-time or corrupted file)
        debugPrint('Merge-sync: could not download existing records, uploading today only: $e');
        mergedRecords = todayRecords;
      }

      // Write merged records to Drive
      dbContext.dailyRecords.clear();
      dbContext.dailyRecords.addAll(mergedRecords);
      final bytes = dbContext.saveDailyRecordToBytes();

      final uploadMedia = drive.Media(
        Stream.value(bytes),
        bytes.length,
      );

      await _driveApi!.files.update(
        drive.File(),
        fileId,
        uploadMedia: uploadMedia,
      );

      // Restore dbContext to only today's records for the UI
      dbContext.dailyRecords.clear();
      dbContext.dailyRecords.addAll(todayRecords);
    } catch (e) {
      rethrow;
    }
  }

  /// Get daily records from local cache, enforcing purge policy to delete historical (non-today) records from cache memory.
  Future<List<DailyRecord>> getDailyRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_dailyRecordCacheKey);

    if (cached == null) return [];

    try {
      final jsonList = jsonDecode(cached) as List<dynamic>;
      final rawRecords = jsonList
          .map((item) => DailyRecord.fromMap(item as Map<String, dynamic>))
          .toList();

      final todayRecords = _filterTodayOnly(rawRecords);

      // Purge non-today records if any were found in cache memory
      if (todayRecords.length != rawRecords.length) {
        await _cacheDailyRecords(todayRecords);
      }

      dbContext.dailyRecords.clear();
      dbContext.dailyRecords.addAll(todayRecords);

      return todayRecords;
    } catch (e) {
      debugPrint('getDailyRecords: error reading daily record cache: $e');
      return [];
    }
  }

  /// Returns all [DailyRecord] entries whose date falls within the current
  /// Monday–Sunday week, read directly from SharedPreferences without applying
  /// the today-only purge policy. Safe to call for the weekly activity heatmap.
  Future<List<DailyRecord>> getWeeklyDailyRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_dailyRecordCacheKey);
    if (cached == null) return [];

    try {
      final jsonList = jsonDecode(cached) as List<dynamic>;
      final rawRecords = jsonList
          .map((item) => DailyRecord.fromMap(item as Map<String, dynamic>))
          .toList();

      // Determine Monday of the current week (time-zeroed to avoid timezone drift)
      final now = DateTime.now();
      final monday = DateTime(
        now.year,
        now.month,
        now.day - (now.weekday - 1), // weekday: Mon=1 … Sun=7
      );

      return rawRecords.where((r) {
        final recordDay = DateTime(r.date.year, r.date.month, r.date.day);
        return !recordDay.isBefore(monday) &&
            recordDay.isBefore(monday.add(const Duration(days: 7)));
      }).toList();
    } catch (e) {
      debugPrint('getWeeklyDailyRecords: error reading cache: $e');
      return [];
    }
  }

  /// Optimistically add a workout set: updates local cache & memory instantly,
  /// then asynchronously uploads to Google Drive Excel in the background without blocking the UI.
  Future<DailyRecord> addDailyRecordOptimistic(DailyRecord record) async {
    dbContext.dailyRecords.add(record);
    await _cacheDailyRecords(dbContext.dailyRecords.toList());

    // Fire background Excel upload non-blockingly
    syncDailyRecordsToDriveInBackground();

    return record;
  }

  /// Optimistically edit a workout set: updates local cache & memory instantly,
  /// then asynchronously uploads to Google Drive Excel in the background without blocking the UI.
  Future<DailyRecord> editDailyRecordOptimistic(DailyRecord record) async {
    dbContext.dailyRecords.update(record, (r) => r.id == record.id);
    await _cacheDailyRecords(dbContext.dailyRecords.toList());

    // Fire background Excel upload non-blockingly
    syncDailyRecordsToDriveInBackground();

    return record;
  }

  /// Optimistically delete a workout set: updates local cache & memory instantly,
  /// then asynchronously uploads to Google Drive Excel in the background without blocking the UI.
  Future<void> deleteDailyRecordOptimistic(String id) async {
    dbContext.dailyRecords.deleteWhere((r) => r.id == id);
    await _cacheDailyRecords(dbContext.dailyRecords.toList());

    // Fire background Excel upload non-blockingly
    syncDailyRecordsToDriveInBackground();
  }

  /// Background upload worker: updates syncStateNotifier to syncing -> synced or error
  Future<void> syncDailyRecordsToDriveInBackground() async {
    syncStateNotifier.value = SyncState.syncing;
    try {
      await ensureDriveApiReady();
      if (_driveApi != null) {
        await syncDailyRecordsToDrive(dbContext.dailyRecords.toList());
      }
      syncStateNotifier.value = SyncState.synced;
    } catch (e) {
      syncStateNotifier.value = SyncState.error;
    }
  }

  /// Manual Sync action triggered by tapping the "Sync" button.
  /// Synchronizes local DbContext records with Google Drive Excel.
  Future<SyncState> manualSyncToExcel() async {
    syncStateNotifier.value = SyncState.syncing;
    try {
      await ensureDriveApiReady();
      if (_driveApi != null) {
        await syncDailyRecordsToDrive(dbContext.dailyRecords.toList());
        syncStateNotifier.value = SyncState.synced;
        return SyncState.synced;
      } else {
        // Not signed in to Google Drive
        syncStateNotifier.value = SyncState.synced;
        return SyncState.synced;
      }
    } catch (e) {
      syncStateNotifier.value = SyncState.error;
      return SyncState.error;
    }
  }

  /// Add a new DailyRecord workout set (optimistic alias)
  Future<DailyRecord> addDailyRecord(DailyRecord record) async {
    return addDailyRecordOptimistic(record);
  }

  /// Delete a DailyRecord set (optimistic alias)
  Future<void> deleteDailyRecord(String id) async {
    await deleteDailyRecordOptimistic(id);
  }

  /// Query today's workout entries resolved with associated Exercise entity.
  /// Triggers fresh Excel download from Google Drive when signed in.
  Future<List<DailyWorkoutEntry>> getTodaysWorkoutEntries([DateTime? date]) async {
    await getExercises();
    if (_driveApi != null) {
      await syncDailyRecordsFromDrive();
    } else {
      await getDailyRecords();
    }
    return dbContext.getTodaysWorkoutEntries(date);
  }

  /// Cache daily records locally in SharedPreferences, enforcing purge policy (today's entries ONLY).
  Future<void> _cacheDailyRecords(List<DailyRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final todayOnlyRecords = _filterTodayOnly(records);
    final jsonList = todayOnlyRecords.map((r) => r.toMap()).toList();
    await prefs.setString(_dailyRecordCacheKey, jsonEncode(jsonList));
  }

  // ==================== ExcelORM Query Interfaces ==================== //

  /// Query exercises using ExcelORM fluid query builder
  ExcelQuery<Exercise> queryExercises({
    String? category,
    String? searchQuery,
  }) {
    var query = dbContext.exercises.query();

    if (category != null && category != 'All') {
      query = query.where((e) => e.bodyPart == category);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final queryLower = searchQuery.toLowerCase();
      query = query.where((e) => e.name.toLowerCase().contains(queryLower));
    }

    return query;
  }

  /// Get exercise by GUID using ExcelORM
  Exercise? getExerciseById(String guid) {
    return dbContext.exercises.firstOrDefault((e) => e.guid == guid);
  }

  /// Get exercises by category using ExcelORM
  List<Exercise> getExercisesByCategory(String category) {
    if (category == 'All') return dbContext.exercises.toList();
    return dbContext.exercises.whereQuery((e) => e.bodyPart == category).toList();
  }

  /// Query daily records using ExcelORM
  ExcelQuery<DailyRecord> queryDailyRecords({
    String? workoutId,
    String? workoutName,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    var query = dbContext.dailyRecords.query();

    if (workoutId != null && workoutId.isNotEmpty) {
      query = query.where((r) => r.workoutId == workoutId);
    }

    if (workoutName != null && workoutName.isNotEmpty) {
      final nameLower = workoutName.toLowerCase();
      query = query.where((r) => r.workoutName.toLowerCase() == nameLower);
    }

    if (startDate != null) {
      query = query.where((r) => r.date.isAfter(startDate) || r.date.isAtSameMomentAs(startDate));
    }

    if (endDate != null) {
      query = query.where((r) => r.date.isBefore(endDate) || r.date.isAtSameMomentAs(endDate));
    }

    return query;
  }

  /// Query historical DailyRecord entries matching workoutId within the last [daysLimit] days.
  /// Downloads full history from Google Drive to avoid the today-only cache limitation.
  Future<List<DailyRecord>> queryExerciseHistory(String workoutId, {int daysLimit = 30}) async {
    final startDate = DateTime.now().subtract(Duration(days: daysLimit));
    final cutoff = DateTime(startDate.year, startDate.month, startDate.day);

    List<DailyRecord> allRecords = [];
    if (_driveApi != null) {
      try {
        allRecords = await _loadFullHistoryFromDrive();
      } catch (e) {
        debugPrint('queryExerciseHistory: failed to load from Drive, using local context: $e');
        allRecords = dbContext.dailyRecords.toList();
      }
    } else {
      allRecords = dbContext.dailyRecords.toList();
    }

    return allRecords
        .where((r) => r.workoutId == workoutId && (r.date.isAfter(cutoff) || r.date.isAtSameMomentAs(cutoff)))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Downloads the full Daily_record.xlsx from Google Drive and returns all records
  /// without modifying the local dbContext or cache. Used for historical queries.
  Future<List<DailyRecord>> _loadFullHistoryFromDrive() async {
    await ensureDriveApiReady();
    if (_driveApi == null) {
      throw Exception('Drive API not available');
    }

    final prefs = await SharedPreferences.getInstance();
    var fileId = prefs.getString(_dailyRecordFileIdKey);

    if (fileId == null) {
      final folderId = await _getOrCreateFolder();
      final query = "name='$_dailyRecordFileName' and '$folderId' in parents and trashed=false";
      final list = await _driveApi!.files.list(q: query, spaces: 'drive', pageSize: 5);
      if (list.files != null && list.files!.isNotEmpty) {
        fileId = list.files!.first.id!;
        await prefs.setString(_dailyRecordFileIdKey, fileId);
      } else {
        return [];
      }
    }

    final media = await _driveApi!.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final bytes = await _readStream(media.stream);

    // Parse into a temporary context to avoid polluting the today-only context
    final tempContext = WorkoutDbContext();
    tempContext.loadDailyRecordFromBytes(bytes);
    return tempContext.dailyRecords.toList();
  }

  /// Cache exercises locally
  Future<void> _cacheExercises(List<Exercise> exercises) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = exercises.map((e) => e.toMap()).toList();
    await prefs.setString(_cacheKey, jsonEncode(jsonList));
  }

  /// Helper to read stream to bytes
  Future<List<int>> _readStream(Stream<List<int>> stream) async {
    final chunks = <List<int>>[];
    await for (final chunk in stream) {
      chunks.add(chunk);
    }
    return chunks.expand((chunk) => chunk).toList();
  }
}

/// Custom HTTP client for authenticated requests with automatic token refresh
class GoogleAuthClient extends http.BaseClient {
  final GoogleSignIn _googleSignIn;
  final http.Client _inner;

  GoogleAuthClient(this._googleSignIn) : _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Always fetch a fresh token to handle expiry
    final account = _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
    if (account != null) {
      final auth = await account.authentication;
      final accessToken = auth.accessToken;
      if (accessToken != null && accessToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $accessToken';
      }
    }
    return _inner.send(request);
  }
}
