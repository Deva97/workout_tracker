import 'package:intl/intl.dart';
import '../../domain/models/weight_record.dart';
import '../../domain/repositories/weight_repository.dart';
import '../services/google_drive_service.dart';
import '../services/local_storage_service.dart';

class WeightRepositoryImpl implements WeightRepository {
  final GoogleDriveService _driveService;
  final LocalStorageService _storageService;

  WeightRepositoryImpl({
    GoogleDriveService? driveService,
    LocalStorageService? storageService,
  })  : _driveService = driveService ?? GoogleDriveService(),
        _storageService = storageService ?? LocalStorageService();

  @override
  Future<bool> checkWeightSheetExists() async {
    final cachedId = await _storageService.getBodyWeightFileId();
    if (cachedId != null && cachedId.isNotEmpty) {
      return true;
    }
    return _driveService.checkBodyWeightSheetExists();
  }

  @override
  Future<void> createWeightSheet() async {
    await _driveService.createBodyWeightExcelFile();
  }

  @override
  Future<List<WeightRecord>> getWeightRecords() async {
    final cached = await _storageService.getCachedWeightRecords();
    if (cached.isNotEmpty) {
      // Fire-and-forget background Drive refresh
      _driveService.loadWeightRecordsFromDrive().then((driveRecords) {
        if (driveRecords.isNotEmpty) {
          _storageService.setCachedWeightRecords(driveRecords);
        }
      }).catchError((_) {});
      return cached;
    }

    // If cache is empty, load from Drive
    final driveRecords = await _driveService.loadWeightRecordsFromDrive();
    if (driveRecords.isNotEmpty) {
      await _storageService.setCachedWeightRecords(driveRecords);
      return driveRecords;
    }

    return [];
  }

  @override
  Future<WeightRecord?> getTodayWeightRecord() async {
    final records = await getWeightRecords();
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    for (final r in records) {
      final rStr = DateFormat('yyyy-MM-dd').format(r.date);
      if (rStr == todayStr) return r;
    }
    return null;
  }

  @override
  Future<void> saveWeightRecord(WeightRecord record) async {
    final records = (await _storageService.getCachedWeightRecords()).toList();
    final recordDateStr = DateFormat('yyyy-MM-dd').format(record.date);

    final existingIndex = records.indexWhere(
      (r) => DateFormat('yyyy-MM-dd').format(r.date) == recordDateStr,
    );

    if (existingIndex >= 0) {
      records[existingIndex] = record;
    } else {
      records.add(record);
    }

    records.sort((a, b) => a.date.compareTo(b.date));
    await _storageService.setCachedWeightRecords(records);

    // Sync to Drive
    await _driveService.syncWeightRecordsToDrive(records);
  }

  @override
  Future<void> deleteWeightRecord(String id) async {
    final records = (await _storageService.getCachedWeightRecords()).toList();
    records.removeWhere((r) => r.id == id);
    await _storageService.setCachedWeightRecords(records);

    // Sync to Drive
    await _driveService.syncWeightRecordsToDrive(records);
  }
}
