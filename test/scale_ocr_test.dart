import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:workout_tracker/data/services/scale_ocr_service.dart';
import 'package:workout_tracker/ui/core/theme/app_theme.dart';
import 'package:workout_tracker/ui/features/weight_tracking/views/widgets/scale_capture_dialog.dart';

// ---------------------------------------------------------------------------
// Fakes for Unit Testing OCR without Native Platform Channel Dependencies
// ---------------------------------------------------------------------------

class FakeImagePicker extends Fake implements ImagePicker {
  final XFile? photoToReturn;
  final bool shouldThrow;

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

  FakeTextRecognizer({this.textToReturn = '6.6 kg', this.shouldThrow = false});

  @override
  Future<RecognizedText> processImage(InputImage inputImage) async {
    if (shouldThrow) {
      throw Exception('Simulated OCR processing failure');
    }
    return FakeRecognizedText(textToReturn);
  }

  @override
  Future<void> close() async {
    isClosed = true;
  }
}

// ---------------------------------------------------------------------------
// Main Unit Test Suite: Scale OCR Service & 6.6kg Camry Scale Display
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScaleOcrService - Camry Scale 6.6kg OCR Data Processing', () {
    test('accurately parses 6.6 kg across various raw OCR formats', () {
      // Direct scale reading
      expect(ScaleOcrService.parseWeightFromText('6.6 kg'), equals(6.6));
      expect(ScaleOcrService.parseWeightFromText('6.6kg'), equals(6.6));
      expect(ScaleOcrService.parseWeightFromText('6.6'), equals(6.6));
      expect(ScaleOcrService.parseWeightFromText('6.60 kg'), equals(6.6));

      // With scale brand (as visible in the user Camry scale photo)
      expect(ScaleOcrService.parseWeightFromText('CAMRY\n6.6 kg'), equals(6.6));
      expect(ScaleOcrService.parseWeightFromText('CAMRY 6.6 kg'), equals(6.6));
      expect(ScaleOcrService.parseWeightFromText('CAMRY\n  6.6  \nkg'), equals(6.6));

      // Multi-line block with scale capacity text
      expect(
        ScaleOcrService.parseWeightFromText('CAMRY\nMAX 150 kg\n6.6 kg'),
        equals(6.6),
      );
    });

    test('handles 7-segment display digit confusions for 6.6 (b substitutions)', () {
      expect(ScaleOcrService.parseWeightFromText('b.b kg'), equals(6.6));
      expect(ScaleOcrService.parseWeightFromText('6.b kg'), equals(6.6));
      expect(ScaleOcrService.parseWeightFromText('b.6 kg'), equals(6.6));
    });

    test('supports weights across valid scale range from 0.5kg to 300kg including 29.3kg sub-30kg boundary', () {
      expect(ScaleOcrService.parseWeightFromText('0.5 kg'), equals(0.5));
      expect(ScaleOcrService.parseWeightFromText('6.6 kg'), equals(6.6));
      expect(ScaleOcrService.parseWeightFromText('15.0 kg'), equals(15.0));
      expect(ScaleOcrService.parseWeightFromText('29.3 kg'), equals(29.3));
      expect(ScaleOcrService.parseWeightFromText('CAMRY\n29.3 kg'), equals(29.3));
      expect(ScaleOcrService.parseWeightFromText('74.5 kg'), equals(74.5));
      expect(ScaleOcrService.parseWeightFromText('120.0 kg'), equals(120.0));
      expect(ScaleOcrService.parseWeightFromText('300.0 kg'), equals(300.0));
    });

    test('rejects values outside personal scale bounds and non-weight noise', () {
      // Below 0.5kg threshold (e.g. scale zeroed or small sensor noise)
      expect(ScaleOcrService.parseWeightFromText('0.0 kg'), isNull);
      expect(ScaleOcrService.parseWeightFromText('0.2 kg'), isNull);

      // Above 300kg threshold
      expect(ScaleOcrService.parseWeightFromText('450 kg'), isNull);

      // Scale error codes and timestamps
      expect(ScaleOcrService.parseWeightFromText('ERR 04'), isNull);
      expect(ScaleOcrService.parseWeightFromText('12:45 PM'), isNull);
      expect(ScaleOcrService.parseWeightFromText(''), isNull);
      expect(ScaleOcrService.parseWeightFromText('   '), isNull);
    });
  });

  Future<File> resolveFixtureFile(String fixturePath, String fallbackName) async {
    final file = File(fixturePath);
    if (file.existsSync()) return file;
    final tempDir = await Directory.systemTemp.createTemp('fixture_fallback_');
    final fallback = File('${tempDir.path}/$fallbackName');
    await fallback.writeAsString('fallback photo bytes');
    return fallback;
  }

  group('ScaleOcrService - Photo Fixture Processing (Camry Scale)', () {
    test('extractWeightFromPhoto processes 6.6kg scale image without deleting fixture', () async {
      final fixtureFile = await resolveFixtureFile(
        'test/fixtures/scale_camry_6_6kg.jpg',
        'scale_camry_6_6kg.jpg',
      );

      final ocrService = ScaleOcrService(
        recognizerFactory: () => FakeTextRecognizer(textToReturn: 'CAMRY\n6.6 kg'),
      );

      final result = await ocrService.extractWeightFromPhoto(
        XFile(fixtureFile.path),
        deleteAfter: false,
      );

      expect(result.isSuccess, isTrue);
      expect(result.detectedWeight, equals(6.6));
      expect(result.rawText, contains('6.6 kg'));
      expect(fixtureFile.existsSync(), isTrue);
    });

    test('extractWeightFromPhoto processes 29.3kg scale image without deleting fixture', () async {
      final fixtureFile = await resolveFixtureFile(
        'test/fixtures/scale_camry_29_3kg.jpg',
        'scale_camry_29_3kg.jpg',
      );

      final ocrService = ScaleOcrService(
        recognizerFactory: () => FakeTextRecognizer(textToReturn: 'CAMRY\n29.3 kg'),
      );

      final result = await ocrService.extractWeightFromPhoto(
        XFile(fixtureFile.path),
        deleteAfter: false,
      );

      expect(result.isSuccess, isTrue);
      expect(result.detectedWeight, equals(29.3));
      expect(result.rawText, contains('29.3 kg'));
      expect(fixtureFile.existsSync(), isTrue);
    });

    test('extractWeightFromPhoto processes 34.6kg scale image without deleting fixture', () async {
      final fixtureFile = await resolveFixtureFile(
        'test/fixtures/scale_camry_34_6kg.jpg',
        'scale_camry_34_6kg.jpg',
      );

      final ocrService = ScaleOcrService(
        recognizerFactory: () => FakeTextRecognizer(textToReturn: 'CAMRY\n34.6 kg'),
      );

      final result = await ocrService.extractWeightFromPhoto(
        XFile(fixtureFile.path),
        deleteAfter: false,
      );

      expect(result.isSuccess, isTrue);
      expect(result.detectedWeight, equals(34.6));
      expect(result.rawText, contains('34.6 kg'));
      expect(fixtureFile.existsSync(), isTrue);
    });

    test('captureAndExtractWeight extracts 6.6kg and preserves privacy invariant', () async {
      final tempDir = await Directory.systemTemp.createTemp('camry_ocr_test_');
      final photoFile = File('${tempDir.path}/captured_camry_6_6kg.jpg');
      await photoFile.writeAsString('simulated captured camera bytes of 6.6kg scale');

      expect(photoFile.existsSync(), isTrue);

      final ocrService = ScaleOcrService(
        imagePicker: FakeImagePicker(photoToReturn: XFile(photoFile.path)),
        recognizerFactory: () => FakeTextRecognizer(textToReturn: 'CAMRY\n6.6 kg'),
      );

      final result = await ocrService.captureAndExtractWeight();

      expect(result.isSuccess, isTrue);
      expect(result.detectedWeight, equals(6.6));
      // INVARIANT: Camera captured photo is deleted immediately after OCR
      expect(photoFile.existsSync(), isFalse);

      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('captureAndExtractWeight returns failure when OCR cannot detect weight digits', () async {
      final tempDir = await Directory.systemTemp.createTemp('unreadable_ocr_test_');
      final photoFile = File('${tempDir.path}/unreadable_display.jpg');
      await photoFile.writeAsString('blurry or unreadable photo bytes');

      final ocrService = ScaleOcrService(
        imagePicker: FakeImagePicker(photoToReturn: XFile(photoFile.path)),
        recognizerFactory: () => FakeTextRecognizer(textToReturn: 'ERR 04'),
      );

      final result = await ocrService.captureAndExtractWeight();

      expect(result.isSuccess, isFalse);
      expect(result.detectedWeight, isNull);
      expect(result.errorMessage, contains('Could not clearly detect weighing scale digits'));
      expect(photoFile.existsSync(), isFalse);

      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('UI Layer: ScaleCaptureDialog with 6.6kg Reading', () {
    testWidgets('renders initial 6.6kg reading and adjusts increments correctly', (tester) async {
      double? savedWeight;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  savedWeight = await showDialog<double>(
                    context: context,
                    builder: (_) => const ScaleCaptureDialog(initialWeight: 6.6),
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
      expect(find.text('6.6'), findsOneWidget);
      expect(find.text('🔒 Scale photo permanently deleted for privacy'), findsOneWidget);

      // Tap +0.5 quick adjustment chip -> 6.6 + 0.5 = 7.1
      await tester.tap(find.text('+0.5'));
      await tester.pumpAndSettle();
      expect(find.text('7.1'), findsOneWidget);

      // Tap -0.1 fine-tune button -> 7.1 - 0.1 = 7.0
      await tester.tap(find.byIcon(Icons.remove_circle_outline_rounded));
      await tester.pumpAndSettle();
      expect(find.text('7.0'), findsOneWidget);

      // Confirm & Log
      await tester.tap(find.text('Confirm & Log'));
      await tester.pumpAndSettle();

      expect(savedWeight, equals(7.0));
    });
  });
}
