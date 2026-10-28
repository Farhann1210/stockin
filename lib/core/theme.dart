import 'package:flutter/material.dart';

class StockinTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xff087f5b),
      surface: const Color(0xfff7f9f8),
    ),
    scaffoldBackgroundColor: const Color(0xfff7f9f8),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Color(0xfff7f9f8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xffe8eeeb)),
      ),
    ),
  );
}
