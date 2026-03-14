import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 应用主题配置（暗色 + 轻拟物风格）
class AppTheme {
  // 核心色彩
  static const Color backgroundLight = Color(0xFFF5F6FA);
  static const Color backgroundLight2 = Color(0xFFEEF0F7);
  static const Color backgroundDark = Color(0xFF1A1A2E);
  static const Color backgroundDarker = Color(0xFF16162A);
  static const Color surfaceSoft = Color(0xFF222240); // solid dark surface
  static const Color surfaceSoftLight = Color(0xFFFFFFFF); // solid white
  static const Color accent = Color(0xFFE94560);
  static const Color accentLight = Color(0xFFFF6B6B);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF); // 70% 白色
  static const Color textMuted = Color(0x80FFFFFF); // 50% 白色
  static const Color textPrimaryDarkOnLight = Color(0xFF101218);
  static const Color textSecondaryDarkOnLight = Color(0x99101218);

  // 圆角
  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 16;
  static const double radiusXLarge = 24;

  // 间距
  static const double spacingXSmall = 4;
  static const double spacingSmall = 8;
  static const double spacingMedium = 16;
  static const double spacingLarge = 24;
  static const double spacingXLarge = 32;

  static const SystemUiOverlayStyle overlayStyleLight =
      SystemUiOverlayStyle.light;
  static const SystemUiOverlayStyle overlayStyleDark =
      SystemUiOverlayStyle.dark;

  /// 亮色主题（跟随系统时使用）
  static ThemeData get lightTheme {
    final base = ThemeData.from(
      colorScheme: const ColorScheme.light(
        primary: accent,
        secondary: accentLight,
        surface: surfaceSoftLight,
        onPrimary: Colors.white,
        onSurface: textPrimaryDarkOnLight,
      ),
      useMaterial3: true,
    );

    return base.copyWith(
      scaffoldBackgroundColor: backgroundLight,
      primaryColor: accent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: overlayStyleDark,
        titleTextStyle: TextStyle(
          color: textPrimaryDarkOnLight,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: textPrimaryDarkOnLight),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: accent,
        unselectedItemColor: Color(0x99101218),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: surfaceSoftLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: const BorderSide(color: Color(0x14000000), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSoftLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: accent, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingMedium,
          vertical: spacingSmall,
        ),
        hintStyle: const TextStyle(color: textSecondaryDarkOnLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingLarge,
            vertical: spacingMedium,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: textPrimaryDarkOnLight,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        titleMedium: TextStyle(
          color: textPrimaryDarkOnLight,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        titleSmall: TextStyle(
          color: textSecondaryDarkOnLight,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        bodyLarge: TextStyle(
          color: textPrimaryDarkOnLight,
          fontSize: 16,
          height: 1.35,
        ),
        bodyMedium: TextStyle(
          color: textSecondaryDarkOnLight,
          fontSize: 14,
          height: 1.35,
        ),
        bodySmall: TextStyle(
          color: textSecondaryDarkOnLight,
          fontSize: 12,
          height: 1.3,
        ),
        labelLarge: TextStyle(
          color: textPrimaryDarkOnLight,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        labelMedium: TextStyle(
          color: textSecondaryDarkOnLight,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        labelSmall: TextStyle(
          color: textSecondaryDarkOnLight,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xF0FFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: const BorderSide(color: Color(0x14000000), width: 1),
        ),
        elevation: 6,
        contentTextStyle: const TextStyle(
          color: textPrimaryDarkOnLight,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        insetPadding: const EdgeInsets.fromLTRB(
          spacingMedium,
          spacingSmall,
          spacingMedium,
          88,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// 暗色主题
  static ThemeData get darkTheme {
    final base = ThemeData.from(
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accentLight,
        surface: surfaceSoft,
        onPrimary: textPrimary,
        onSurface: textPrimary,
      ),
      useMaterial3: true,
    );

    return base.copyWith(
      scaffoldBackgroundColor: backgroundDark,
      primaryColor: accent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: overlayStyleLight,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: accent,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: surfaceSoft,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: BorderSide(color: const Color(0x1AFFFFFF), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: accent, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingMedium,
          vertical: spacingSmall,
        ),
        hintStyle: const TextStyle(color: textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: textPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingLarge,
            vertical: spacingMedium,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accentLight),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        headlineLarge: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        titleSmall: TextStyle(
          color: textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16, height: 1.35),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14, height: 1.35),
        bodySmall: TextStyle(color: textMuted, fontSize: 12, height: 1.3),
        labelLarge: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        labelMedium: TextStyle(
          color: textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        labelSmall: TextStyle(
          color: textMuted,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xF0222240),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: const BorderSide(color: Color(0x1AFFFFFF), width: 1),
        ),
        elevation: 6,
        contentTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        insetPadding: const EdgeInsets.fromLTRB(
          spacingMedium,
          spacingSmall,
          spacingMedium,
          88,
        ),
      ),
      iconTheme: const IconThemeData(color: textPrimary),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// 轻拟物装饰
class SoftDecoration {
  static BoxDecoration get card => BoxDecoration(
    color: AppTheme.surfaceSoft,
    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
    border: Border.all(color: const Color(0x1AFFFFFF), width: 1),
  );

  static BoxDecoration get sheet => BoxDecoration(
    color: const Color(0xF216162A),
    borderRadius: const BorderRadius.vertical(
      top: Radius.circular(AppTheme.radiusXLarge),
    ),
    border: Border.all(color: const Color(0x1AFFFFFF), width: 1),
  );
}
