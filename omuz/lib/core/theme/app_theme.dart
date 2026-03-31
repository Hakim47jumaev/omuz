import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Omuz: black background, white text, pink tab accent, gradient CTAs (reference layout).
class AppTheme {
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF000000);
  static const Color card = Color(0xFF0A0A0A);
  static const Color text = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFFB3B3B3);
  static const Color borderSubtle = Color(0x33FFFFFF);
  static const Color accentPink = Color(0xFFF472B6);
  static const Color gradientStart = Color(0xFFEC4899);
  static const Color gradientEnd = Color(0xFF7C3AED);
  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFEF4444);

  /// Glass: blur and fill.
  static const double glassBlurSigma = 18;
  static const Color glassFill = Color(0x14FFFFFF);
  static const Color glassBorder = Color(0x2EFFFFFF);

  static const LinearGradient ctaGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [gradientStart, gradientEnd],
  );

  static ThemeData get light => dark;

  static ThemeData get dark {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: accentPink,
      onPrimary: Color(0xFF000000),
      primaryContainer: Color(0xFF3D1F30),
      onPrimaryContainer: Color(0xFFFBCFE8),
      secondary: gradientEnd,
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFF2E1065),
      onSecondaryContainer: Color(0xFFE9D5FF),
      tertiary: text,
      onTertiary: background,
      error: danger,
      onError: Color(0xFFFFFFFF),
      surface: surface,
      onSurface: text,
      surfaceContainerHighest: Color(0xFF141414),
      onSurfaceVariant: secondaryText,
      outline: borderSubtle,
      outlineVariant: Color(0x22FFFFFF),
      shadow: Color(0x40000000),
      scrim: Color(0xCC000000),
      inverseSurface: text,
      onInverseSurface: background,
      inversePrimary: gradientStart,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
        shadowColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        surfaceTintColor: Colors.transparent,
        shape: const Border(
          bottom: BorderSide(color: borderSubtle, width: 1),
        ),
        iconTheme: const IconThemeData(color: text),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 68,
        backgroundColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: accentPink, size: 24);
          }
          return const IconThemeData(color: secondaryText, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final w = states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500;
          final c = states.contains(WidgetState.selected) ? accentPink : secondaryText;
          return GoogleFonts.inter(fontSize: 12, fontWeight: w, color: c);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1A1A1A),
        contentTextStyle: GoogleFonts.inter(color: text, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: borderSubtle),
        ),
      ),
      dividerTheme: const DividerThemeData(color: borderSubtle, thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderSubtle),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: accentPink,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: const BorderSide(color: borderSubtle),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentPink,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        hintStyle: GoogleFonts.inter(color: secondaryText),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accentPink, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primaryContainer,
        disabledColor: scheme.surfaceContainerHighest,
        labelStyle: GoogleFonts.inter(color: text, fontWeight: FontWeight.w500),
        secondaryLabelStyle: GoogleFonts.inter(color: text),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: const BorderSide(color: borderSubtle),
        showCheckmark: false,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: secondaryText,
        textColor: text,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accentPink,
        circularTrackColor: Color(0x22FFFFFF),
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: text,
        displayColor: text,
      ),
    );
  }
}
