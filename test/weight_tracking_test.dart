import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/data/context/workout_db_context.dart';
import 'package:workout_tracker/data/services/local_storage_service.dart';
import 'package:workout_tracker/data/services/scale_ocr_service.dart';
import 'package:workout_tracker/domain/models/weight_record.dart';
import 'package:workout_tracker/domain/models/weekly_weight_average.dart';
import 'package:workout_tracker/domain/repositories/weight_repository.dart';
import 'package:workout_tracker/domain/use_cases/manage_weight_records_use_case.dart';
import 'package:workout_tracker/ui/core/theme/app_colors.dart';
import 'package:workout_tracker/ui/core/theme/app_theme.dart';
import 'package:workout_tracker/ui/features/home/view_models/home_view_model.dart';
import 'package:workout_tracker/ui/features/home/views/home_screen.dart';
import 'package:workout_tracker/ui/features/weight_tracking/view_models/weight_tracking_view_model.dart';
import 'package:workout_tracker/ui/features/weight_tracking/views/weight_tracking_screen.dart';
import 'package:workout_tracker/ui/features/weight_tracking/views/widgets/scale_capture_dialog.dart';
import 'package:workout_tracker/ui/features/weight_tracking/views/widgets/weight_trend_chart.dart';

// ---------------------------------------------------------------------------
// Fakes & Test Doubles
// ---------------------------------------------------------------------------

class FakeWeightRepository implements WeightRepository {
  bool sheetExists;
  final List<WeightRecord> records;
  bool createSheetCalled = false;
  String? deletedId;

  FakeWeightRepository({this.sheetExists = true, List<WeightRecord>? initialRecords})
      : records = initialRecords ?? [];

  @override
  Future<bool> checkWeightSheetExists() async => sheetExists;

  @override
  Future<void> createWeightSheet() async {
    createSheetCalled = true;
    sheetExists = true;
  }

  @override
  Future<List<WeightRecord>> getWeightRecords() async => List.from(records);

  @override
  Future<WeightRecord?> getTodayWeightRecord() async {
    final now = DateTime.now();
    try {
      return records.firstWhere(
        (r) => r.date.year == now.year && r.date.month == now.month && r.date.day == now.day,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveWeightRecord(WeightRecord record) async {
    records.removeWhere((r) => r.id == record.id);
    records.add(record);
  }

  @override
  Future<void> deleteWeightRecord(String id) async {
    deletedId = id;
    records.removeWhere((r) => r.id == id);
  }
}

class FakeImagePicker extends Fake implements ImagePicker {
  XFile? photoToReturn;
  bool shouldThrow;

  FakeImagePicker({this.photoToReturn, this.shouldThrow = false});

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    if (shouldThrow) {
      throw Exception('Simulated camera hardware error');
    }
    return photoToReturn;
  }
}

class FakeRecognizedText extends Fake implements RecognizedText {
  @override
  final String text;

  FakeRecognizedText(this.text);
}

class FakeTextRecognizer extends Fake implements TextRecognizer {
  final String textToReturn;
  final bool shouldThrow;
  bool isClosed = false;

  FakeTextRecognizer({this.textToReturn = '75.4', this.shouldThrow = false});

  @override
  Future<RecognizedText> processImage(InputImage inputImage) async {
    if (shouldThrow) {
      throw Exception('Simulated OCR processing exception');
    }
    return FakeRecognizedText(textToReturn);
  }

  @override
  Future<void> close() async {
    isClosed = true;
  }
}

// ---------------------------------------------------------------------------
// Main Test Suite
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Domain Layer: WeightRecord Model', () {
    test('toJson and fromJson roundtrip serialization', () {
      final date = DateTime(2026, 10, 5, 8, 30);
      final record = WeightRecord(
        id: 'wt_2026-10-05',
        date: date,
        weight: 74.5,
        unit: 'kg',
        notes: 'Fasted morning weight',
      );

      final json = record.toJson();
      expect(json['ID'], equals('wt_2026-10-05'));
      expect(json['Weight'], equals(74.5));
      expect(json['Unit'], equals('kg'));
      expect(json['Notes'], equals('Fasted morning weight'));

      final restored = WeightRecord.fromJson(json);
      expect(restored.id, equals(record.id));
      expect(restored.date, equals(record.date));
      expect(restored.weight, equals(record.weight));
      expect(restored.unit, equals(record.unit));
      expect(restored.notes, equals(record.notes));
    });

    test('copyWith updates properties while retaining others', () {
      final record = WeightRecord(
        id: 'wt_1',
        date: DateTime(2026, 10, 5),
        weight: 72.0,
      );

      final updated = record.copyWith(weight: 73.2, notes: 'Post-workout');
      expect(updated.id, equals('wt_1'));
      expect(updated.date, equals(DateTime(2026, 10, 5)));
      expect(updated.weight, equals(73.2));
      expect(updated.notes, equals('Post-workout'));
    });

    test('ExcelEntityMapper converts to and from row cell map', () {
      final mapper = WeightRecord.excelMapper;
      expect(mapper.headers, containsAll(['ID', 'Date', 'Weight', 'Unit', 'Notes']));

      final record = WeightRecord(
        id: 'wt_excel_1',
        date: DateTime(2026, 10, 5, 9, 0),
        weight: 80.5,
        unit: 'kg',
        notes: 'Scale OCR verified',
      );

      final cells = mapper.toRowCells(record);
      expect(cells['ID'], equals('wt_excel_1'));
      expect(cells['Weight'], equals(80.5));
      expect(cells['Unit'], equals('kg'));
      expect(cells['Notes'], equals('Scale OCR verified'));

      final reconstructed = mapper.fromRow(cells);
      expect(reconstructed.id, equals('wt_excel_1'));
      expect(reconstructed.weight, equals(80.5));
      expect(reconstructed.unit, equals('kg'));
      expect(reconstructed.notes, equals('Scale OCR verified'));
    });
  });

  group('Domain Layer: WeeklyWeightAverage Model', () {
    test('computes range label and short label correctly', () {
      final weeklyAvg = WeeklyWeightAverage(
        weekStart: DateTime(2026, 10, 5), // Monday
        weekEnd: DateTime(2026, 10, 11), // Sunday
        averageWeight: 75.35,
        entryCount: 6,
        minWeight: 74.8,
        maxWeight: 76.1,
      );

      expect(weeklyAvg.averageWeight, equals(75.35));
      expect(weeklyAvg.entryCount, equals(6));
      expect(weeklyAvg.minWeight, equals(74.8));
      expect(weeklyAvg.maxWeight, equals(76.1));
      expect(weeklyAvg.formattedRange, contains('Oct 5 - Oct 11'));
      expect(weeklyAvg.shortLabel, equals('10/5'));
      expect(weeklyAvg.toString(), contains('75.3 kg'));
    });
  });

  group('Domain Layer: ManageWeightRecordsUseCase', () {
    late FakeWeightRepository repository;
    late ManageWeightRecordsUseCase useCase;

    setUp(() {
      repository = FakeWeightRepository();
      useCase = ManageWeightRecordsUseCase(repository: repository);
    });

    test('computeWeeklyAverages groups daily records into calendar weeks', () {
      final records = [
        WeightRecord(id: '1', date: DateTime(2026, 10, 5), weight: 75.0), // Monday Week 1
        WeightRecord(id: '2', date: DateTime(2026, 10, 6), weight: 75.6), // Tuesday Week 1
        WeightRecord(id: '3', date: DateTime(2026, 10, 8), weight: 74.4), // Thursday Week 1
        WeightRecord(id: '4', date: DateTime(2026, 10, 12), weight: 74.0), // Monday Week 2
        WeightRecord(id: '5', date: DateTime(2026, 10, 14), weight: 73.8), // Wednesday Week 2
      ];

      final averages = useCase.computeWeeklyAverages(records);
      expect(averages.length, equals(2));

      // Week 1: (75.0 + 75.6 + 74.4) / 3 = 225.0 / 3 = 75.0
      expect(averages[0].entryCount, equals(3));
      expect(averages[0].averageWeight, equals(75.0));
      expect(averages[0].minWeight, equals(74.4));
      expect(averages[0].maxWeight, equals(75.6));

      // Week 2: (74.0 + 73.8) / 2 = 73.9
      expect(averages[1].entryCount, equals(2));
      expect(averages[1].averageWeight, equals(73.9));
      expect(averages[1].minWeight, equals(73.8));
      expect(averages[1].maxWeight, equals(74.0));
    });

    test('computeWeeklyAverages returns empty list when records are empty', () {
      final averages = useCase.computeWeeklyAverages([]);
      expect(averages, isEmpty);
    });

    test('CRUD operations delegate correctly to repository', () async {
      expect(await useCase.checkWeightSheetExists(), isTrue);

      await useCase.createWeightSheet();
      expect(repository.createSheetCalled, isTrue);

      await useCase.saveTodayWeight(77.5, notes: 'Morning');
      final records = await useCase.getWeightRecords();
      expect(records.length, equals(1));
      expect(records.first.weight, equals(77.5));
      expect(records.first.notes, equals('Morning'));

      final today = await useCase.getTodayWeightRecord();
      expect(today, isNotNull);
      expect(today!.weight, equals(77.5));

      await useCase.deleteWeightRecord(today.id);
      expect(repository.deletedId, equals(today.id));
      expect(await useCase.getWeightRecords(), isEmpty);
    });
  });

  group('Data Layer: ScaleOcrService Text Parsing', () {
    test('extracts valid weight digits across varied LCD formats', () {
      expect(ScaleOcrService.parseWeightFromText('6.6 kg'), equals(6.6));
      expect(ScaleOcrService.parseWeightFromText('CAMRY\n6.6 kg'), equals(6.6));
      expect(ScaleOcrService.parseWeightFromText('CAMRY 6.6 kg'), equals(6.6));
      expect(ScaleOcrService.parseWeightFromText('74.5 kg'), equals(74.5));
      expect(ScaleOcrService.parseWeightFromText('Weight: 82.3kg'), equals(82.3));
      expect(ScaleOcrService.parseWeightFromText('\n  120.0 \n'), equals(120.0));
      expect(ScaleOcrService.parseWeightFromText('68,4 kg'), equals(68.4));
      expect(ScaleOcrService.parseWeightFromText('75 kg'), equals(75.0));
      expect(ScaleOcrService.parseWeightFromText('15.0 kg'), equals(15.0));
      expect(ScaleOcrService.parseWeightFromText('MAX 150KG \n 75.8 KG \n READY'), equals(75.8));
      expect(ScaleOcrService.parseWeightFromText('68.25'), equals(68.3));
    });

    test('handles 7-segment display letter O and b substitutions', () {
      expect(ScaleOcrService.parseWeightFromText('7O.5 kg'), equals(70.5));
      expect(ScaleOcrService.parseWeightFromText('80.O kg'), equals(80.0));
      expect(ScaleOcrService.parseWeightFromText('b.b kg'), equals(6.6));
      expect(ScaleOcrService.parseWeightFromText('6.b kg'), equals(6.6));
    });

    test('rejects noise and non-weight text', () {
      expect(ScaleOcrService.parseWeightFromText(''), isNull);
      expect(ScaleOcrService.parseWeightFromText('   '), isNull);
      expect(ScaleOcrService.parseWeightFromText('ERR 04'), isNull);
      expect(ScaleOcrService.parseWeightFromText('12:45 PM'), isNull);
      expect(ScaleOcrService.parseWeightFromText('0.2 kg'), isNull); // under 0.5kg scale threshold
      expect(ScaleOcrService.parseWeightFromText('0.0 kg'), isNull);
      expect(ScaleOcrService.parseWeightFromText('450 kg'), isNull); // above 300kg scale threshold
    });
  });

  group('Data Layer: ScaleOcrService Photo Deletion Invariant', () {
    test('deletes captured photo immediately after successful OCR extraction', () async {
      final tempDir = await Directory.systemTemp.createTemp('scale_ocr_test_');
      final photoFile = File('${tempDir.path}/test_scale_photo.jpg');
      await photoFile.writeAsString('simulated photo bytes from camera');

      expect(photoFile.existsSync(), isTrue);

      final ocrService = ScaleOcrService(
        imagePicker: FakeImagePicker(photoToReturn: XFile(photoFile.path)),
        recognizerFactory: () => FakeTextRecognizer(textToReturn: '76.8 kg'),
      );

      final result = await ocrService.captureAndExtractWeight();

      expect(result.isSuccess, isTrue);
      expect(result.detectedWeight, equals(76.8));
      // INVARIANT: The temporary photo on disk MUST be deleted immediately
      expect(photoFile.existsSync(), isFalse);

      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('deletes captured photo even when OCR engine throws an exception', () async {
      final tempDir = await Directory.systemTemp.createTemp('scale_ocr_error_test_');
      final photoFile = File('${tempDir.path}/error_scale_photo.jpg');
      await photoFile.writeAsString('corrupted or unreadable photo bytes');

      expect(photoFile.existsSync(), isTrue);

      final ocrService = ScaleOcrService(
        imagePicker: FakeImagePicker(photoToReturn: XFile(photoFile.path)),
        recognizerFactory: () => FakeTextRecognizer(shouldThrow: true),
      );

      final result = await ocrService.captureAndExtractWeight();

      expect(result.isSuccess, isFalse);
      // INVARIANT: The temporary photo MUST still be deleted in finally block
      expect(photoFile.existsSync(), isFalse);

      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('handles camera cancellation gracefully', () async {
      final ocrService = ScaleOcrService(
        imagePicker: FakeImagePicker(photoToReturn: null),
      );

      final result = await ocrService.captureAndExtractWeight();
      expect(result.isCancelled, isTrue);
      expect(result.isSuccess, isFalse);
    });

    test('handles camera permission or hardware exception gracefully', () async {
      final ocrService = ScaleOcrService(
        imagePicker: FakeImagePicker(shouldThrow: true),
      );

      final result = await ocrService.captureAndExtractWeight();
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Could not access camera'));
    });
  });

  group('Data Layer: LocalStorageService Body Weight Caching', () {
    test('stores and retrieves cached weight records and file ID', () async {
      final storage = LocalStorageService();

      expect(await storage.getBodyWeightFileId(), isNull);
      await storage.setBodyWeightFileId('drive_body_weight_file_id_123');
      expect(await storage.getBodyWeightFileId(), equals('drive_body_weight_file_id_123'));

      expect(await storage.getCachedWeightRecords(), isEmpty);

      final records = [
        WeightRecord(id: 'wt_1', date: DateTime(2026, 10, 5), weight: 74.2),
        WeightRecord(id: 'wt_2', date: DateTime(2026, 10, 6), weight: 74.0),
      ];

      await storage.setCachedWeightRecords(records);
      final cached = await storage.getCachedWeightRecords();

      expect(cached.length, equals(2));
      expect(cached[0].id, equals('wt_1'));
      expect(cached[0].weight, equals(74.2));
      expect(cached[1].id, equals('wt_2'));
      expect(cached[1].weight, equals(74.0));
    });
  });

  group('Data Layer: WorkoutDbContext Default Excel Bytes', () {
    test('creates valid Body_weight.xlsx default bytes with schema headers', () {
      final dbContext = WorkoutDbContext();
      final bytes = dbContext.createDefaultBodyWeightBytes();

      expect(bytes, isNotEmpty);
      // Valid ZIP archive header for .xlsx files
      expect(bytes[0], equals(0x50)); // 'P'
      expect(bytes[1], equals(0x4B)); // 'K'
    });
  });

  group('ViewModel Layer: WeightTrackingViewModel', () {
    late FakeWeightRepository repository;
    late ManageWeightRecordsUseCase useCase;
    late WeightTrackingViewModel viewModel;

    setUp(() {
      repository = FakeWeightRepository(
        sheetExists: true,
        initialRecords: [
          WeightRecord(id: '1', date: DateTime.now().subtract(const Duration(days: 7)), weight: 76.0),
          WeightRecord(id: '2', date: DateTime.now(), weight: 75.0),
        ],
      );
      useCase = ManageWeightRecordsUseCase(repository: repository);
      viewModel = WeightTrackingViewModel(useCase: useCase);
    });

    test('initializes and loads existing records and weekly averages', () async {
      expect(viewModel.isCheckingDrive, isTrue);

      await viewModel.initialize();

      expect(viewModel.isCheckingDrive, isFalse);
      expect(viewModel.sheetExists, isTrue);
      expect(viewModel.records.length, equals(2));
      expect(viewModel.todayRecord, isNotNull);
      expect(viewModel.todayRecord!.weight, equals(75.0));
      expect(viewModel.weeklyAverages, isNotEmpty);
    });

    test('handles missing sheet state and provides createSheet action', () async {
      repository.sheetExists = false;
      await viewModel.initialize();

      expect(viewModel.isCheckingDrive, isFalse);
      expect(viewModel.sheetExists, isFalse);

      await viewModel.createSheet();

      expect(repository.createSheetCalled, isTrue);
      expect(viewModel.sheetExists, isTrue);
    });

    test('toggleGraphMode switches between daily and weekly averages', () {
      expect(viewModel.graphMode, equals(WeightGraphMode.daily));

      viewModel.toggleGraphMode(WeightGraphMode.weeklyAverage);
      expect(viewModel.graphMode, equals(WeightGraphMode.weeklyAverage));

      viewModel.toggleGraphMode(WeightGraphMode.daily);
      expect(viewModel.graphMode, equals(WeightGraphMode.daily));
    });

    test('deleteRecord removes record and updates view model state', () async {
      await viewModel.initialize();
      expect(viewModel.records.length, equals(2));

      await viewModel.deleteRecord('2');

      expect(viewModel.records.length, equals(1));
      expect(viewModel.todayRecord, isNull);
    });
  });

  group('UI Layer: ScaleCaptureDialog Widget Tests', () {
    testWidgets('renders initial weight and allows quick adjustments', (tester) async {
      double? savedWeight;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  savedWeight = await showDialog<double>(
                    context: context,
                    builder: (_) => const ScaleCaptureDialog(initialWeight: 75.0),
                  );
                },
                child: const Text('Open Scale Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Scale Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Scale Reading Verified'), findsOneWidget);
      expect(find.text('75.0'), findsOneWidget);
      expect(find.text('🔒 Scale photo permanently deleted for privacy'), findsOneWidget);

      // Tap +0.5 quick adjustment chip
      await tester.tap(find.text('+0.5'));
      await tester.pumpAndSettle();
      expect(find.text('75.5'), findsOneWidget);

      // Tap -0.1 fine-tune button
      await tester.tap(find.byIcon(Icons.remove_circle_outline_rounded));
      await tester.pumpAndSettle();
      expect(find.text('75.4'), findsOneWidget);

      // Confirm & Log
      await tester.tap(find.text('Confirm & Log'));
      await tester.pumpAndSettle();

      expect(savedWeight, equals(75.4));
    });

    testWidgets('dismisses with null on Retake Photo', (tester) async {
      double? result = 999.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showDialog<double>(
                    context: context,
                    builder: (_) => const ScaleCaptureDialog(initialWeight: 80.0),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retake Photo'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });

  group('UI Layer: WeightTrendChart Widget Tests', () {
    testWidgets('renders empty state when no records are available', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WeightTrendChart(
              dailyRecords: [],
              weeklyAverages: [],
              mode: WeightGraphMode.daily,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('No weight records logged yet'), findsOneWidget);
    });

    testWidgets('renders chart and allows scrubbing interaction in daily mode', (tester) async {
      final records = [
        WeightRecord(id: '1', date: DateTime(2026, 10, 1), weight: 76.5),
        WeightRecord(id: '2', date: DateTime(2026, 10, 2), weight: 76.2),
        WeightRecord(id: '3', date: DateTime(2026, 10, 3), weight: 75.8),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SizedBox(
              height: 320,
              child: WeightTrendChart(
                dailyRecords: records,
                weeklyAverages: const [],
                mode: WeightGraphMode.daily,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // CustomPaint is rendered
      expect(find.byType(CustomPaint), findsWidgets);

      // Perform a scrub gesture on the chart
      final center = tester.getCenter(find.byType(CustomPaint).first);
      await tester.tapAt(center);
      await tester.pumpAndSettle();
    });

    testWidgets('renders weekly average chart points properly', (tester) async {
      final weeklyAverages = [
        WeeklyWeightAverage(
          weekStart: DateTime(2026, 9, 21),
          weekEnd: DateTime(2026, 9, 27),
          averageWeight: 77.0,
          entryCount: 4,
          minWeight: 76.5,
          maxWeight: 77.5,
        ),
        WeeklyWeightAverage(
          weekStart: DateTime(2026, 9, 28),
          weekEnd: DateTime(2026, 10, 4),
          averageWeight: 76.2,
          entryCount: 5,
          minWeight: 75.9,
          maxWeight: 76.8,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SizedBox(
              height: 320,
              child: WeightTrendChart(
                dailyRecords: const [],
                weeklyAverages: weeklyAverages,
                mode: WeightGraphMode.weeklyAverage,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('UI Layer: WeightTrackingScreen View Tests', () {
    testWidgets('shows minimalist loader while verifying Google Drive sheet', (tester) async {
      final repository = FakeWeightRepository(sheetExists: true);
      final useCase = ManageWeightRecordsUseCase(repository: repository);
      final viewModel = WeightTrackingViewModel(useCase: useCase);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: WeightTrackingScreen(viewModel: viewModel),
        ),
      );

      // Before pumpAndSettle, isCheckingDrive is true
      expect(find.text('Checking Drive for Body_weight.xlsx...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Checking Drive for Body_weight.xlsx...'), findsNothing);
    });

    testWidgets('shows missing sheet prompt and initializes sheet on button tap', (tester) async {
      final repository = FakeWeightRepository(sheetExists: false);
      final useCase = ManageWeightRecordsUseCase(repository: repository);
      final viewModel = WeightTrackingViewModel(useCase: useCase);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: WeightTrackingScreen(viewModel: viewModel),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Initialize Weight Tracker'), findsOneWidget);
      expect(find.text('Add Body_weight.xlsx'), findsOneWidget);

      // Tap initialize sheet
      await tester.tap(find.text('Add Body_weight.xlsx'));
      await tester.pumpAndSettle();

      expect(repository.createSheetCalled, isTrue);
      expect(find.text("Today's Weight"), findsOneWidget);
    });

    testWidgets('renders dashboard cards, graph mode toggle, and recent history', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final records = [
        WeightRecord(id: '1', date: DateTime.now().subtract(const Duration(days: 1)), weight: 75.8),
        WeightRecord(id: '2', date: DateTime.now(), weight: 75.2),
      ];

      final repository = FakeWeightRepository(sheetExists: true, initialRecords: records);
      final useCase = ManageWeightRecordsUseCase(repository: repository);
      final viewModel = WeightTrackingViewModel(useCase: useCase);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: WeightTrackingScreen(viewModel: viewModel),
        ),
      );

      await tester.pumpAndSettle();

      // Today's Weight Card
      expect(find.text("Today's Weight: 75.2 kg"), findsOneWidget);
      expect(find.text('LOGGED'), findsOneWidget);

      // Mode toggles
      expect(find.text('Everyday Graph'), findsOneWidget);
      expect(find.text('Weekly Average'), findsOneWidget);

      // Switch to Weekly Average
      await tester.tap(find.text('Weekly Average'));
      await tester.pumpAndSettle();

      expect(viewModel.graphMode, equals(WeightGraphMode.weeklyAverage));

      // Recent Measurements & Summary
      expect(find.text('Recent Measurements'), findsOneWidget);
      expect(find.text('75.2 kg'), findsNWidgets(2));
      expect(find.text('75.8 kg'), findsOneWidget);

      // Delete confirmation
      await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('Delete Weight Record?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Today Weight Card renders cleanly without overflow on narrow 320px screen', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = FakeWeightRepository(sheetExists: true);
      final useCase = ManageWeightRecordsUseCase(repository: repository);
      final viewModel = WeightTrackingViewModel(useCase: useCase);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: WeightTrackingScreen(viewModel: viewModel),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("Today's Weight"), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('Log Today’s Weight (Camera)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Mode filter chips have high contrast text in dark mode', (tester) async {
      final repository = FakeWeightRepository(sheetExists: true);
      final useCase = ManageWeightRecordsUseCase(repository: repository);
      final viewModel = WeightTrackingViewModel(useCase: useCase);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: WeightTrackingScreen(viewModel: viewModel),
        ),
      );

      await tester.pumpAndSettle();

      // Find the unselected "Weekly Average" Text widget
      final unselectedText = tester.widget<Text>(find.text('Weekly Average'));
      expect(unselectedText.style?.color, equals(AppColors.textLight));

      // Find the selected "Everyday Graph" Text widget
      final selectedText = tester.widget<Text>(find.text('Everyday Graph'));
      expect(selectedText.style?.color, equals(Colors.white));
    });
  });

  group('HomeScreen Integration: Body Weight Card Navigation', () {
    testWidgets('renders Body Weight & Trends card and navigates to WeightTrackingScreen', (tester) async {
      final homeViewModel = HomeViewModel();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(viewModel: homeViewModel),
        ),
      );

      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('Body Weight & Trends'),
        find.byType(CustomScrollView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      // Find the Body Weight & Trends ModularCard
      expect(find.text('Body Weight & Trends'), findsOneWidget);
      expect(find.text('Log scale photo and view everyday & weekly average graphs'), findsOneWidget);

      // Tap on the card
      await tester.tap(find.text('Body Weight & Trends'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Successfully pushed WeightTrackingScreen
      expect(find.text('Body Weight Tracker'), findsOneWidget);
    });
  });
}
