import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'splash_screen.dart';

// Global State Managers
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<String> userNameNotifier = ValueNotifier("Guest");
final ValueNotifier<String> userEmailNotifier = ValueNotifier(""); // Changed from Phone

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    print("✅ Firebase Initialized Successfully");
  } catch (e) {
    print("❌ Firebase Initialization Failed: $e");
  }

  // Load Theme
  final prefs = await SharedPreferences.getInstance();
  final bool isDark = prefs.getBool('is_dark_mode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  // Restore User Session
  User? currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    userNameNotifier.value = currentUser.displayName ?? "User";
    userEmailNotifier.value = currentUser.email ?? "";
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Sujoodly',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              scaffoldBackgroundColor: const Color(0xFFF7F4EF)
          ),
          darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF121212)
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}