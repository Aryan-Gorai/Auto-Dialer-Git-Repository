import 'package:flutter/material.dart';

/// Centralized color constants used across the app.
class AppColors {
  AppColors._(); // prevent instantiation

  /// Coral accent used for median lines, highlights, and chart elements.
  static const Color coral = Color(0xFFFF6B6B);

  /// Primary gradient used for selected UI elements (e.g. theme toggle).
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF4A90D9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
