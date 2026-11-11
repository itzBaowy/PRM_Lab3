import 'package:flutter/material.dart';

abstract final class AppSpace {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 24.0, xxl = 32.0;
  static const touch = 48.0,
      button = 52.0,
      formWidth = 640.0,
      dayWidth = 184.0,
      slotWidth = 88.0;
}

abstract final class AppRadius {
  static const small = 8.0, medium = 12.0, large = 16.0;
}

abstract final class AppColors {
  static const primary = Color(0xFFC93C13),
      brand = Color(0xFFF4511E),
      soft = Color(0xFFFFF0E8),
      background = Color(0xFFFFF7F3),
      surface = Colors.white,
      text = Color(0xFF243047),
      secondary = Color(0xFF667085),
      border = Color(0xFFD9DEE7),
      success = Color(0xFF16835D),
      error = Color(0xFFC93A2B),
      info = Color(0xFF2563B8);
}

ThemeData buildAppTheme() {
  const text = TextTheme(
    headlineSmall: TextStyle(
      fontSize: 24,
      height: 32 / 24,
      fontWeight: FontWeight.w700,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      height: 28 / 20,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 24 / 16),
    bodyMedium: TextStyle(fontSize: 16, height: 24 / 16),
    bodySmall: TextStyle(fontSize: 14, height: 20 / 14),
    labelLarge: TextStyle(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w600,
    ),
    labelMedium: TextStyle(fontSize: 14, height: 20 / 14),
    labelSmall: TextStyle(fontSize: 14, height: 20 / 14),
  );
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
    primary: AppColors.primary,
    onPrimary: AppColors.surface,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.secondary,
    error: AppColors.error,
    outline: AppColors.secondary,
    outlineVariant: AppColors.border,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.medium),
    borderSide: const BorderSide(color: AppColors.secondary),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Roboto',
    textTheme: text.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.text,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: border,
      enabledBorder: border,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.all(AppSpace.lg),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(AppSpace.touch, AppSpace.button),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(AppSpace.touch, AppSpace.button),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(AppSpace.touch, AppSpace.touch),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(AppSpace.touch, AppSpace.touch),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.soft,
    ),
  );
}
