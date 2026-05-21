import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand palette — purple primary works on both light and dark surfaces.
/// Light tokens are exposed via static fields (kept for backwards-compat
/// with existing widgets). Dark tokens live on [AppPalette.dark] and are
/// resolved per-context via [AppColors.of].
class AppColors {
  // Brand — same in both modes (matches admin console command-center palette)
  static const Color primary = Color(0xFF7C3AED); // vivid purple
  static const Color primaryDark = Color(0xFF5B21B6);
  static const Color primaryDeep = Color(0xFF2E1065);
  static const Color accent = Color(0xFFA78BFA); // soft purple
  static const Color accentSoft = Color(0xFFC4B5FD);
  static const Color pink = Color(0xFFEC4899); // gradient partner (active state)
  static const Color pinkSoft = Color(0xFFF472B6);
  static const Color teal = Color(0xFF06B6D4); // data viz / hero glow
  static const Color signal = Color(0xFF10B981);
  static const Color signalDark = Color(0xFF34D399);

  // Status — light defaults
  static const Color safe = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // LIGHT mode surfaces — subtle lavender-tinted white (matches admin light)
  static const Color surface = Color(0xFFF8F7FC);
  static const Color card = Color(0xFFFFFFFF);
  static const Color glass = Color(0xB8FFFFFF);
  static const Color hairline = Color(0xFFE9E4F5);
  static const Color hairlineSoft = Color(0xFFF1EDF9);

  // LIGHT text
  static const Color textPrimary = Color(0xFF0F0C1A); // near-black with purple undertone
  static const Color textSecondary = Color(0xFF6B6580);
  static const Color textMuted = Color(0xFF9B95AE);

  // DARK mode surfaces — matches admin console exactly
  static const Color surfaceDark = Color(0xFF0A0A0F); // charcoal-black
  static const Color cardDark = Color(0xFF14121E); // glass panel base
  static const Color glassDark = Color(0x8C14121E); // 55% panel for frosted look
  static const Color hairlineDark = Color(0x0FFFFFFF); // rgba(255,255,255,0.06)
  static const Color hairlineSoftDark = Color(0x2E7C3AED); // purple soft (18%)

  // DARK text — neutral off-white + purple-tinted greys (never blue)
  static const Color textPrimaryDark = Color(0xFFF5F5F7);
  static const Color textSecondaryDark = Color(0xFFB8B0CC);
  static const Color textMutedDark = Color(0xFF8F8AA8);

  // DARK status — neon variants for readability on charcoal
  static const Color safeDark = Color(0xFF34D399);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color dangerDark = Color(0xFFF87171);

  /// Resolve surface/text tokens for the current theme mode.
  static AppPalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppPalette.dark : AppPalette.light;
  }
}

/// Resolved palette for one brightness — pass either [AppPalette.light]
/// or [AppPalette.dark] and read theme-aware tokens.
class AppPalette {
  const AppPalette({
    required this.surface,
    required this.card,
    required this.glass,
    required this.hairline,
    required this.hairlineSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.safe,
    required this.warning,
    required this.danger,
    required this.signal,
  });

  final Color surface;
  final Color card;
  final Color glass;
  final Color hairline;
  final Color hairlineSoft;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color safe;
  final Color warning;
  final Color danger;
  final Color signal;

  static const AppPalette light = AppPalette(
    surface: AppColors.surface,
    card: AppColors.card,
    glass: AppColors.glass,
    hairline: AppColors.hairline,
    hairlineSoft: AppColors.hairlineSoft,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
    safe: AppColors.safe,
    warning: AppColors.warning,
    danger: AppColors.danger,
    signal: AppColors.signal,
  );

  static const AppPalette dark = AppPalette(
    surface: AppColors.surfaceDark,
    card: AppColors.cardDark,
    glass: AppColors.glassDark,
    hairline: AppColors.hairlineDark,
    hairlineSoft: AppColors.hairlineSoftDark,
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    textMuted: AppColors.textMutedDark,
    safe: AppColors.safeDark,
    warning: AppColors.warningDark,
    danger: AppColors.dangerDark,
    signal: AppColors.signalDark,
  );
}

/// Reusable gradients (purple-first identity, mirrors admin console).
class AppGradients {
  /// Hero panels — deep-purple ramp (mirrors the admin command-center bg).
  static const LinearGradient heroPurple = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A0B3D), Color(0xFF2E1065), Color(0xFF5B21B6), Color(0xFF7C3AED)],
    stops: [0.0, 0.35, 0.70, 1.0],
  );

  static const LinearGradient heroNavy = heroPurple; // alias for legacy refs

  /// Primary CTA & active states — purple → pink (matches admin nav active).
  static const LinearGradient cyberAccent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
  );

  /// Soft purple → lavender — secondary accent strips.
  static const LinearGradient softAccent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)],
  );

  static const LinearGradient signalPulse = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF34D399)],
  );

  static const LinearGradient dangerPulse = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
  );

  /// Aurora glows for background ambience (matches admin dashboard).
  static const RadialGradient purpleAurora = RadialGradient(
    colors: [Color(0x2E7C3AED), Color(0x00000000)],
  );

  static const RadialGradient tealAurora = RadialGradient(
    colors: [Color(0x1A06B6D4), Color(0x00000000)],
  );

  static const RadialGradient purpleHalo = RadialGradient(
    colors: [Color(0x667C3AED), Color(0x00000000)],
  );
}

class AppShadows {
  /// Light-mode card shadow — soft purple tint.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x1A7C3AED),
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: -6,
    ),
  ];

  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x267C3AED),
      blurRadius: 32,
      offset: Offset(0, 14),
      spreadRadius: -8,
    ),
  ];

  /// Dark-mode card shadow — bigger blur, lower opacity, purple glow.
  static const List<BoxShadow> cardDark = [
    BoxShadow(
      color: Color(0x4D000000),
      blurRadius: 20,
      offset: Offset(0, 8),
      spreadRadius: -4,
    ),
  ];

  /// Purple neon edge — for emphasis, used sparingly.
  static const List<BoxShadow> neon = [
    BoxShadow(
      color: Color(0x807C3AED),
      blurRadius: 22,
      offset: Offset(0, 0),
      spreadRadius: 0,
    ),
  ];
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.hairline, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.hairline, width: 1.2),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.hairlineSoft,
        side: const BorderSide(color: AppColors.hairline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.hairlineSoft,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.cardDark,
      ),
      scaffoldBackgroundColor: AppColors.surfaceDark,
      canvasColor: AppColors.surfaceDark,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimaryDark,
        displayColor: AppColors.textPrimaryDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimaryDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimaryDark,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimaryDark),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: AppColors.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.hairlineDark, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentSoft,
          side: const BorderSide(color: AppColors.hairlineDark, width: 1.2),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardDark,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.hairlineDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.hairlineDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondaryDark),
        hintStyle: const TextStyle(color: AppColors.textMutedDark),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.hairlineSoftDark,
        side: const BorderSide(color: AppColors.hairlineDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondaryDark,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.hairlineSoftDark,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimaryDark),
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.textPrimaryDark,
        iconColor: AppColors.textSecondaryDark,
      ),
    );
  }
}
