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

    return extractWeightFromPhoto(photo, deleteAfter: true);
  }

  /// Processes a photo file with OCR, parses weight digits,
  /// and optionally deletes the photo immediately after extraction.
  Future<ScaleOcrResult> extractWeightFromPhoto(
    XFile photo, {
    bool deleteAfter = true,
  }) async {
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
      if (deleteAfter) {
        // INVARIANT: Delete picture immediately as soon as OCR processing finishes
        await _deletePhotoQuietly(photo.path);
      }
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
    String normalized = rawText
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'(?<=[\d.])[oO]'), '0')
        .replaceAll(RegExp(r'[oO](?=[\d.])'), '0');

    // Handle 7-segment display letter 'b' confused with '6' when adjacent to a decimal point
    normalized = normalized
        .replaceAll(RegExp(r'\b[bB]\.(?=\d|[bB])'), '6.')
        .replaceAll(RegExp(r'(?<=\d|\.)[bB]\b'), '6');

    // Remove clock timestamps (e.g. 12:45 PM, 08:30) to prevent false numeric extractions
    final cleaned = normalized.replaceAll(
      RegExp(r'\b\d{1,2}:\d{2}(?::\d{2})?\s*(?:[AaPp][Mm])?\b'),
      ' ',
    );

    // Matches numbers with 1 to 3 digits before decimal, avoiding codes with leading zero like "04"
    final regex = RegExp(r'(?:^|[^\d.])([1-9]\d{0,2}(?:\.\d{1,2})?|0\.\d{1,2})(?:[^\d.]|$)');
    final matches = regex.allMatches(cleaned);

    final List<double> candidates = [];
    for (final match in matches) {
      final str = match.group(1);
      if (str != null) {
        final val = double.tryParse(str);
        // Valid personal scale weight bounds in kg (0.5 kg to 300.0 kg)
        if (val != null && val >= 0.5 && val <= 300.0) {
          candidates.add(val);
        }
      }
    }

    if (candidates.isEmpty) return null;

    // Prefer candidates that have an explicit decimal point (e.g. 6.6 or 74.5 over 74)
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
