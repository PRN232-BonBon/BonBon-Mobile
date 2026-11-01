import 'package:flutter/material.dart';

/// Bảng màu lấy từ inline styles của frontend web.
class AppColors {
  const AppColors._();

  static const background = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const border = Color(0xFF334155);
  static const primary = Color(0xFF6366F1);
  static const primarySoft = Color(0xFF818CF8);
  static const text = Color(0xFFF8FAFC);
  static const textMuted = Color(0xFF94A3B8);
  static const textDim = Color(0xFF64748B);
  static const danger = Color(0xFFEF4444);
  static const dangerSurface = Color(0xFF450A0A);
  static const dangerBorder = Color(0xFF7F1D1D);
  static const dangerText = Color(0xFFFCA5A5);
  static const token = Color(0xFF7DD3FC);
}

class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.text,
        error: AppColors.danger,
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        hintStyle: const TextStyle(color: AppColors.textDim, fontSize: 14),
        errorStyle: const TextStyle(color: AppColors.dangerText, fontSize: 12),
        border: _border(AppColors.border),
        enabledBorder: _border(AppColors.border),
        focusedBorder: _border(AppColors.primary),
        errorBorder: _border(AppColors.danger),
        focusedErrorBorder: _border(AppColors.danger),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primarySoft),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary,
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: color),
  );
}
