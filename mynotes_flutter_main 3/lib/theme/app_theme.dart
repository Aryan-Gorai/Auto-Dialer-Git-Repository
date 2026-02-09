import 'package:flutter/material.dart';

/// Centralized design tokens for the enterprise UI.
/// All colors, shadows, radii, and the light ThemeData are defined here.
class AppDesignTokens {
  AppDesignTokens._(); // not instantiable

  // ── Primary ──────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF6D4DFF);
  static const Color primaryDark = Color(0xFF5638DB);
  static const Color primarySoft = Color(0xFFEEE8FF);
  static const Color primarySurface = Color(0xFFF9F7FF);

  // ── Accent ───────────────────────────────────────────────────────────────
  static const Color accentBlue = Color(0xFF2563EB);
  static const Color accentBlueSoft = Color(0xFFDBEAFE);

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color successSoft = Color(0xFFD1FAE5);
  static const Color successDark = Color(0xFF059669);

  static const Color danger = Color(0xFFEF4444);
  static const Color dangerSoft = Color(0xFFFEE2E2);
  static const Color dangerLight = Color(0xFFF87171);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFFD97706);

  // ── Neutrals ─────────────────────────────────────────────────────────────
  static const Color neutral900 = Color(0xFF111827);
  static const Color neutral800 = Color(0xFF1F2937);
  static const Color neutral700 = Color(0xFF374151);
  static const Color neutral600 = Color(0xFF4B5563);
  static const Color neutral500 = Color(0xFF6B7280);
  static const Color neutral400 = Color(0xFF9CA3AF);
  static const Color neutral300 = Color(0xFFD1D5DB);
  static const Color neutral200 = Color(0xFFE5E7EB);
  static const Color neutral100 = Color(0xFFF3F4F6);
  static const Color neutral50 = Color(0xFFF9FAFB);

  // ── Surfaces ─────────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF5F5FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color scaffoldBg = Color(0xFFF5F5FA);

  // ── Gradients ────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accentBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFF87171)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Shadows ──────────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.10),
          blurRadius: 24,
          offset: const Offset(0, 8),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get coloredShadow => [
        BoxShadow(
          color: primary.withOpacity(0.20),
          blurRadius: 16,
          offset: const Offset(0, 6),
          spreadRadius: 0,
        ),
      ];

  // ── Border Radii ─────────────────────────────────────────────────────────
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusPill = 999.0;

  // ── Spacing ──────────────────────────────────────────────────────────────
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;

  // ── ThemeData ────────────────────────────────────────────────────────────
  static ThemeData lightTheme() {
    const fontFamily = 'Inter';

    final colorScheme = ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primarySoft,
      onPrimaryContainer: primaryDark,
      secondary: accentBlue,
      onSecondary: Colors.white,
      secondaryContainer: accentBlueSoft,
      onSecondaryContainer: Color(0xFF1E40AF),
      surface: surface,
      onSurface: neutral900,
      error: danger,
      onError: Colors.white,
      errorContainer: dangerSoft,
      onErrorContainer: Color(0xFFB91C1C),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
      canvasColor: surface,
      cardColor: surface,

      // ── AppBar ─────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: neutral900,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: neutral900,
        ),
        iconTheme: IconThemeData(color: neutral700, size: 22),
      ),

      // ── Card ───────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: neutral200, width: 1),
        ),
      ),

      // ── Input ──────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: neutral50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: neutral300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: neutral300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: danger),
        ),
        hintStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: neutral500,
        ),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: neutral700,
        ),
      ),

      // ── Elevated Button (Primary) ──────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Outlined Button (Secondary) ────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Text Button ────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Floating Action Button ─────────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),

      // ── Chip ───────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: primarySoft,
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: primary,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),

      // ── TabBar ─────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: neutral600,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),

      // ── Bottom Navigation ─────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: neutral500,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),

      // ── Dialog ─────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: neutral900,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: neutral700,
        ),
      ),

      // ── Divider ────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: neutral200,
        thickness: 1,
        space: 1,
      ),

      // ── Switch ─────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return neutral400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primarySoft;
          return neutral200;
        }),
      ),

      // ── ProgressIndicator ──────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: neutral200,
        circularTrackColor: neutral200,
      ),

      // ── SnackBar ───────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: neutral800,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Text Theme ─────────────────────────────────────────────────
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontFamily: fontFamily,
            fontSize: 40,
            fontWeight: FontWeight.w300,
            color: neutral900),
        displayMedium: TextStyle(
            fontFamily: fontFamily,
            fontSize: 36,
            fontWeight: FontWeight.w400,
            color: neutral900),
        displaySmall: TextStyle(
            fontFamily: fontFamily,
            fontSize: 32,
            fontWeight: FontWeight.w400,
            color: neutral900),
        headlineLarge: TextStyle(
            fontFamily: fontFamily,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: neutral900),
        headlineMedium: TextStyle(
            fontFamily: fontFamily,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: neutral900),
        headlineSmall: TextStyle(
            fontFamily: fontFamily,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: neutral900),
        titleLarge: TextStyle(
            fontFamily: fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: neutral900),
        titleMedium: TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: neutral900),
        titleSmall: TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: neutral900),
        bodyLarge: TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: neutral700),
        bodyMedium: TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: neutral700),
        bodySmall: TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: neutral600),
        labelLarge: TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: neutral700),
        labelMedium: TextStyle(
            fontFamily: fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: neutral700),
        labelSmall: TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: neutral600),
      ),
    );
  }
}
