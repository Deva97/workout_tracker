import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class ScaleOcrResult {
  final bool isSuccess;
  final bool isCancelled;
  final double? detectedWeight;
  final String rawText;
  final String? errorMessage;

  const ScaleOcrResult({
    required this.isSuccess,
    this.isCancelled = false,
    this.detectedWeight,
    this.rawText = '',
    this.errorMessage,
  });

  factory ScaleOcrResult.cancelled() => const ScaleOcrResult(
        isSuccess: false,
        isCancelled: true,
      );

  factory ScaleOcrResult.success(double weight, {String rawText = ''}) => ScaleOcrResult(
        isSuccess: true,
        detectedWeight: weight,
        rawText: rawText,
      );

  factory ScaleOcrResult.failure(String message, {String rawText = ''}) => ScaleOcrResult(
        isSuccess: false,
        errorMessage: message,
        rawText: rawText,
      );
}

class ScaleOcrService {
  final ImagePicker _imagePicker;
  final TextRecognizer Function()? recognizerFactory;

  ScaleOcrService({
    ImagePicker? imagePicker,
    this.recognizerFactory,
  }) : _imagePicker = imagePicker ?? ImagePicker();

  /// Launches the camera, photographs the weighing machine display,
  /// parses the weight digits via on-device OCR, and immediately deletes
  /// the captured photo from storage.
  Future<ScaleOcrResult> captureAndExtractWeight() async {
    XFile? photo;
    try {
      photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
        preferredCameraDevice: CameraDevice.rear,
      );
    } catch (e) {
      return ScaleOcrResult.failure('Could not access camera: $e');
    }

    if (photo == null) {
      return ScaleOcrResult.cancelled();
    }

    String recognizedText = '';
    TextRecognizer? recognizer;
    try {
      final inputImage = InputImage.fromFilePath(photo.path);
      recognizer = recognizerFactory != null
          ? recognizerFactory!()
          : TextRecognizer(script: TextRecognitionScript.latin);

      final RecognizedText result = await recognizer.processImage(inputImage);
      recognizedText = result.text;
    } catch (e) {
      debugPrint('OCR extraction error: $e');
    } finally {
      await recognizer?.close();
      // INVARIANT: Delete picture immediately as soon as OCR processing finishes
      await _deletePhotoQuietly(photo.path);
    }

    final parsedWeight = parseWeightFromText(recognizedText);
    if (parsedWeight != null) {
      return ScaleOcrResult.success(parsedWeight, rawText: recognizedText);
    }

    return ScaleOcrResult.failure(
      'Could not clearly detect weighing scale digits. Please ensure the scale screen is lit and clearly framed.',
      rawText: recognizedText,
    );
  }

  /// Parses numeric weight from raw OCR text blocks
  static double? parseWeightFromText(String rawText) {
    if (rawText.trim().isEmpty) return null;

    // Normalization: replace commas with decimal points and handle common 7-segment digit confusions
    final normalized = rawText
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'(?<=[\d.])[oO]'), '0')
        .replaceAll(RegExp(r'[oO](?=[\d.])'), '0');

    // Matches standard decimal weight (e.g. 74.5, 74.50, 102.3, 68)
    final regex = RegExp(r'(?:^|[^\d.])(\d{2,3}(?:\.\d{1,2})?)(?:[^\d.]|$)');
    final matches = regex.allMatches(normalized);

    final List<double> candidates = [];
    for (final match in matches) {
      final str = match.group(1);
      if (str != null) {
        final val = double.tryParse(str);
        // Valid human weight bounds in kg (30 kg to 300 kg)
        if (val != null && val >= 30.0 && val <= 300.0) {
          candidates.add(val);
        }
      }
    }

    if (candidates.isEmpty) return null;

    // Prefer candidates that have an explicit decimal point (e.g. 74.5 over 74)
    final decimalCandidates = candidates.where((c) => c % 1 != 0).toList();
    if (decimalCandidates.isNotEmpty) {
      return double.parse(decimalCandidates.first.toStringAsFixed(1));
    }

    return double.parse(candidates.first.toStringAsFixed(1));
  }

  Future<void> _deletePhotoQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
