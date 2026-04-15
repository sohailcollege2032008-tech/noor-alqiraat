import 'package:flutter/material.dart';

class AppTheme {
  // Deep Green and Gold accents for Islamic Aesthetic
  static const Color primaryDeepGreen = Color(0xFF1B4332);
  static const Color accentGold = Color(0xFFD4AF37);
  static const Color lightBackground = Color(0xFFF9F9F9);

  static final ThemeData islamicTheme = ThemeData(
    primaryColor: primaryDeepGreen,
    scaffoldBackgroundColor: lightBackground,
    colorScheme: const ColorScheme.light(
      primary: primaryDeepGreen,
      secondary: accentGold,
      surface: lightBackground,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryDeepGreen,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: accentGold,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      type: BottomNavigationBarType.fixed,
    ),
    useMaterial3: true,
  );
}
