import 'package:flutter/material.dart';

class AppColors {
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) => isDark(context) ? const Color(0xFF121212) : const Color(0xFFF7F4EF);
  static Color creamCard(BuildContext context) => isDark(context) ? const Color(0xFF1E1E1E) : const Color(0xFFF3ECD0);
  static Color textDark(BuildContext context) => isDark(context) ? const Color(0xFFE0E0E0) : const Color(0xFF1A1A1A);
  static Color primaryMint(BuildContext context) => isDark(context) ? const Color(0xFF2E7D32) : const Color(0xFFD2E1D1);
  static Color accentBeige(BuildContext context) => isDark(context) ? const Color(0xFFA1887F) : const Color(0xFFC4B89F);

  static const Color verifiedBlue = Color(0xFF4A90E2);
}