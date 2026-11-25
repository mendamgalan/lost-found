// Keep compatibility with the project's Flutter 3.47 Android baseline.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF172D31);
  static const teal = Color(0xFF006D66);
  static const mint = Color(0xFFE2F0EA);
  static const canvas = Color(0xFFF7F8F5);
  static const line = Color(0xFFDFE6E1);
  static const coral = Color(0xFFAF452F);
  static const peach = Color(0xFFFFEDE5);
  static const muted = Color(0xFF5D7070);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.teal).copyWith(
    primary: AppColors.teal,
    onPrimary: Colors.white,
    surface: Colors.white,
    onSurface: AppColors.ink,
    outline: AppColors.line,
    secondaryContainer: AppColors.mint,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.canvas,
    visualDensity: VisualDensity.standard,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 34,
        height: 1.16,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: -.7,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.canvas,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.teal, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.mint,
      height: 76,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
