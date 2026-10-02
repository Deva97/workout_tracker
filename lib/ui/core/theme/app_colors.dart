import 'package:flutter/material.dart';

class AppColors {
  // Primary Athletic Palette (High-Performance Electric Cobalt / Indigo)
  static const Color primary = Color(0xFF4F46E5); // Indigo 600
  static const Color primaryLight = Color(0xFF6366F1); // Indigo 500
  static const Color primaryVariant = Color(0xFF4338CA); // Indigo 700
  static const Color accent = Color(0xFF7C3AED); // Violet 600
  static const Color accentLight = Color(0xFF8B5CF6); // Violet 500

  // Neutral Palette - Light Mode
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceLight = Color(0xFFFFFFFF); // Pure White
  static const Color surfaceLightElevated = Color(0xFFF1F5F9); // Slate 100
  static const Color cardBorderLight = Color(0xFFE2E8F0); // Slate 200
  static const Color dividerLight = Color(0xFFE2E8F0);

  // Neutral Palette - Dark Mode (OLED Obsidian & Slate)
  static const Color backgroundDark = Color(0xFF0A0E1A); // Deep Obsidian
  static const Color surfaceDark = Color(0xFF131B2E); // Midnight Slate
  static const Color surfaceDarkElevated = Color(0xFF1C263F); // Slate 800
  static const Color cardBorderDark = Color(0xFF22304C); // Slate 700 / Border
  static const Color dividerDark = Color(0xFF1E293B);

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  static const Color textTertiary = Color(0xFF94A3B8); // Slate 400
  static const Color textLight = Color(0xFFF8FAFC); // Slate 50
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Slate 400

  // Semantic Status Colors
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color successDark = Color(0xFF059669); // Emerald 600
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color error = Color(0xFFEF4444); // Red 500
  static const Color info = Color(0xFF3B82F6); // Blue 500

  // UI Element Colors
  static const Color disabled = Color(0xFFCBD5E1); // Slate 300
  static const Color shimmer = Color(0xFFE2E8F0); // Slate 200
  static const Color divider = Color(0xFFE2E8F0);
  static const Color onPrimaryContainer = Color(0xFFFFFFFF);

  // Muscle Group Color Palette (Balanced, Modern Luminescence)
  static const Map<String, Color> muscleGroupColors = {
    'Chest': Color(0xFFEF4444), // Crimson Red
    'Back': Color(0xFF0D9488), // Teal Emerald
    'Legs': Color(0xFFF59E0B), // Amber Gold
    'Quadriceps': Color(0xFFD97706), // Deep Amber
    'Hamstrings': Color(0xFFB45309), // Bronze
    'Calves': Color(0xFF84CC16), // Lime Green
    'Shoulders': Color(0xFF8B5CF6), // Purple Violet
    'Biceps': Color(0xFF2563EB), // Royal Blue
    'Triceps': Color(0xFF0891B2), // Cyan
    'Forearms': Color(0xFF4F46E5), // Indigo
    'Core': Color(0xFFEA580C), // Vibrant Orange
    'Abs': Color(0xFFEA580C), // Vibrant Orange
    'Glutes': Color(0xFFDB2777), // Rose Pink
  };

  static Color getMuscleColor(String bodyPart) {
    return muscleGroupColors[bodyPart] ?? primary;
  }
}
