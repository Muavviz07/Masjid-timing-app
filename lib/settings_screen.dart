import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';
import 'main.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _saveTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', isDark);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(backgroundColor: AppColors.background(context), elevation: 0, leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: AppColors.textDark(context)), onPressed: () => Navigator.pop(context)), title: Text("Settings", style: GoogleFonts.poppins(color: AppColors.textDark(context), fontWeight: FontWeight.w600))),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(color: AppColors.creamCard(context), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [Icon(Icons.dark_mode_outlined, color: AppColors.textDark(context)), const SizedBox(width: 16), Text("Dark Mode", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark(context)))]),
                ValueListenableBuilder<ThemeMode>(valueListenable: themeNotifier, builder: (context, mode, _) {
                  return Switch(value: mode == ThemeMode.dark, activeColor: AppColors.primaryMint(context), onChanged: (val) { themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light; _saveTheme(val); });
                }),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}