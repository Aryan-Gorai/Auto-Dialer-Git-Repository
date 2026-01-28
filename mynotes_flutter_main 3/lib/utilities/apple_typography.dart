import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Utility class for consistent Apple-style typography throughout the app
class AppleTypography {
  static String get fontFamily {
    // Use San Francisco font family for Apple platforms
    if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      return '.SF UI Text'; // San Francisco system font
    }
    return '.SF UI Text'; // Use Apple font for all platforms for consistency
  }
  
  /// Standard text styles with Apple font
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );
  
  static const TextStyle body1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );
  
  static const TextStyle body2 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );
  
  static const TextStyle subtitle1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );
  
  static const TextStyle subtitle2 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );
  
  static const TextStyle headline6 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
  );
  
  static const TextStyle headline5 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w400,
  );
  
  static const TextStyle headline4 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w400,
  );
  
  static const TextStyle headline3 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w400,
  );
  
  static const TextStyle headline2 = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w400,
  );
  
  static const TextStyle headline1 = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w300,
  );
  
  /// Helper method to apply Apple font to existing TextStyle
  static TextStyle withAppleFont(TextStyle style) {
    return style.copyWith(fontFamily: fontFamily);
  }
}