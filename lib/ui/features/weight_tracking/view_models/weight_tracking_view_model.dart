import 'package:flutter/material.dart';
import 'package:workout_tracker/data/repositories/weight_repository_impl.dart';
import 'package:workout_tracker/data/services/scale_ocr_service.dart';
import 'package:workout_tracker/domain/models/weight_record.dart';
import 'package:workout_tracker/domain/models/weekly_weight_average.dart';
import 'package:workout_tracker/domain/use_cases/manage_weight_records_use_case.dart';
import '../views/widgets/scale_capture_dialog.dart';
import '../views/widgets/weight_trend_chart.dart';

class WeightTrackingViewModel extends ChangeNotifier {
  final ManageWeightRecordsUseCase _useCase;
  final ScaleOcrService _ocrService;

  WeightTrackingViewModel({
    ManageWeightRecordsUseCase? useCase,
    ScaleOcrService? ocrService,
  })  : _useCase = useCase ??
            ManageWeightRecordsUseCase(repository: WeightRepositoryImpl()),
        _ocrService = ocrService ?? ScaleOcrService();

  bool _isCheckingDrive = true;
  bool get isCheckingDrive => _isCheckingDrive;

  bool _sheetExists = true;
  bool get sheetExists => _sheetExists;

  bool _isCreatingSheet = false;
  bool get isCreatingSheet => _isCreatingSheet;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  WeightGraphMode _graphMode = WeightGraphMode.daily;
  WeightGraphMode get graphMode => _graphMode;

  List<WeightRecord> _records = [];
  List<WeightRecord> get records => _records;

  List<WeeklyWeightAverage> _weeklyAverages = [];
  List<WeeklyWeightAverage> get weeklyAverages => _weeklyAverages;

  WeightRecord? _todayRecord;
  WeightRecord? get todayRecord => _todayRecord;

  double? _weeklyDelta;
  double? get weeklyDelta => _weeklyDelta;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    _isCheckingDrive = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final exists = await _useCase.checkWeightSheetExists();
      _sheetExists = exists;

      if (exists) {
        await _loadRecordsInternal();
      }
    } catch (e) {
      _errorMessage = 'Could not verify weight sheet in Drive: $e';
    } finally {
      _isCheckingDrive = false;
      notifyListeners();
    }
  }

  Future<void> createSheet() async {
    _isCreatingSheet = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _useCase.createWeightSheet();
      _sheetExists = true;
      await _loadRecordsInternal();
    } catch (e) {
      _errorMessage = 'Failed to create Body_weight.xlsx: $e';
    } finally {
      _isCreatingSheet = false;
      notifyListeners();
    }
  }

  Future<void> loadRecords() async {
    await _loadRecordsInternal();
    notifyListeners();
  }

  Future<void> _loadRecordsInternal() async {
    _records = await _useCase.getWeightRecords();
    _weeklyAverages = _useCase.computeWeeklyAverages(_records);
    _todayRecord = await _useCase.getTodayWeightRecord();
    _weeklyDelta = _useCase.computeWeeklyDelta(_weeklyAverages);
  }

  void toggleGraphMode(WeightGraphMode mode) {
    if (_graphMode != mode) {
      _graphMode = mode;
      notifyListeners();
    }
  }

  Future<void> captureAndLogWeight(BuildContext context) async {
    _isScanning = true;
    _errorMessage = null;
    notifyListeners();

    ScaleOcrResult ocrResult;
    try {
      ocrResult = await _ocrService.captureAndExtractWeight();
    } finally {
      _isScanning = false;
      notifyListeners();
    }

    if (ocrResult.isCancelled) return;

    if (!context.mounted) return;

    if (!ocrResult.isSuccess || ocrResult.detectedWeight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ocrResult.errorMessage ?? 'Could not detect weight number.'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmedWeight = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ScaleCaptureDialog(
        initialWeight: ocrResult.detectedWeight!,
      ),
    );

    if (confirmedWeight == null) return;

    try {
      await _useCase.saveTodayWeight(confirmedWeight);
      await _loadRecordsInternal();
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logged ${confirmedWeight.toStringAsFixed(1)} kg for today!'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _errorMessage = 'Failed to save weight record: $e';
      notifyListeners();
    }
  }

  Future<void> deleteRecord(String id) async {
    try {
      await _useCase.deleteWeightRecord(id);
      await _loadRecordsInternal();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to delete record: $e';
      notifyListeners();
    }
  }
}
