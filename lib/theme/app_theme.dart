// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppColors {
  static const black   = Color(0xFF08090D);
  static const dark1   = Color(0xFF0E0F17);
  static const dark2   = Color(0xFF14162A);
  static const dark3   = Color(0xFF1C1F3A);
  static const blue    = Color(0xFF2563FF);
  static const blue2   = Color(0xFF4F86FF);
  static const violet  = Color(0xFF7C3AED);
  static const violet2 = Color(0xFFA855F7);
  static const green   = Color(0xFF10B981);
  static const orange  = Color(0xFFF59E0B);
  static const red     = Color(0xFFEF4444);
  static const text    = Color(0xFFE8EAF6);
  static const text2   = Color(0xFF8B8FA8);
  static const glass   = Color(0x0AFFFFFF);
  static const border  = Color(0x12FFFFFF);

  static const gradient = LinearGradient(
    colors: [blue, violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.black,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.blue,
        secondary: AppColors.violet,
        surface: AppColors.dark1,
        error: AppColors.red,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.dark1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
        ),
        iconTheme: IconThemeData(color: AppColors.text2),
      ),
      cardTheme: CardTheme(
        color: AppColors.dark2,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.dark2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.blue),
        ),
        labelStyle: const TextStyle(color: AppColors.text2),
        hintStyle: const TextStyle(color: AppColors.text2),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.dark1,
        selectedItemColor: AppColors.blue2,
        unselectedItemColor: AppColors.text2,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerColor: AppColors.border,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontWeight: FontWeight.w800, color: AppColors.text),
        titleLarge: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
        bodyLarge: TextStyle(color: AppColors.text),
        bodyMedium: TextStyle(color: AppColors.text2),
      ),
    );
  }
}
