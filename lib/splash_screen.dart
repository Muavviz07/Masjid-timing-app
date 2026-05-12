import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart'; // REQUIRED
import 'package:url_launcher/url_launcher.dart'; // REQUIRED
import 'app_colors.dart';
import 'animations.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'main.dart';
import 'firestore_service.dart'; // REQUIRED

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final FirestoreService _db = FirestoreService();

  @override
  void initState() {
    super.initState();
    _checkAppVersionAndNavigate();
  }

  Future<void> _checkAppVersionAndNavigate() async {
    // 1. Wait a bit for animation
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // 2. Check for Updates
    bool updateAvailable = await _checkForUpdates();
    if (updateAvailable) return; // Stop here if update dialog is shown

    // 3. Normal Navigation Logic (If no update)
    _navigateToNext();
  }

  Future<bool> _checkForUpdates() async {
    try {
      // Get Current Installed Version
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version; // e.g., "1.0.0"

      // Get Latest Version from Firestore
      Map<String, dynamic>? config = await _db.getAppConfig();

      if (config != null) {
        String latestVersion = config['latest_version'] ?? "1.0.0";
        String downloadUrl = config['download_url'] ?? "";
        bool isMandatory = config['is_mandatory'] ?? false;

        // Simple comparison (assuming format "1.0.0")
        if (_isVersionLower(currentVersion, latestVersion)) {
          if (mounted) {
            _showUpdateDialog(latestVersion, downloadUrl, isMandatory);
          }
          return true; // Stop navigation
        }
      }
    } catch (e) {
      debugPrint("Update Check Failed: $e");
    }
    return false; // Continue navigation
  }

  bool _isVersionLower(String current, String latest) {
    // Removes standard build numbers if present (e.g. 1.0.0+1 -> 1.0.0)
    List<int> v1 = current.split('+')[0].split('.').map(int.parse).toList();
    List<int> v2 = latest.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      int num1 = (i < v1.length) ? v1[i] : 0;
      int num2 = (i < v2.length) ? v2[i] : 0;
      if (num1 < num2) return true;
      if (num1 > num2) return false;
    }
    return false;
  }

  void _showUpdateDialog(String version, String url, bool isMandatory) {
    showDialog(
      context: context,
      barrierDismissible: !isMandatory, // If mandatory, user CANNOT close dialog
      builder: (context) => WillPopScope(
        onWillPop: () async => !isMandatory,
        child: AlertDialog(
          backgroundColor: AppColors.creamCard(context),
          title: Row(
            children: [
              const Icon(Icons.system_update, color: Colors.green),
              const SizedBox(width: 12),
              Text("Update Available", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.textDark(context))),
            ],
          ),
          content: Text(
            "A new version ($version) of Sujoodly is available with better features and fixes.",
            style: GoogleFonts.poppins(color: AppColors.textDark(context)),
          ),
          actions: [
            if (!isMandatory)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToNext(); // Allow user to skip
                },
                child: Text("Later", style: TextStyle(color: AppColors.accentBeige(context))),
              ),
            ElevatedButton(
              onPressed: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryMint(context)),
              child: Text("Update Now", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToNext() async {
    final prefs = await SharedPreferences.getInstance();
    bool seenOnboarding = prefs.getBool('seenOnboarding') ?? false;

    User? user = FirebaseAuth.instance.currentUser;
    bool isLoggedIn = user != null;

    if (isLoggedIn) {
      userNameNotifier.value = user.displayName ?? "User";
      userEmailNotifier.value = user.email ?? "";
    }

    if (mounted) {
      Widget targetScreen;
      if (isLoggedIn) {
        targetScreen = const HomeScreen();
      } else if (seenOnboarding) {
        targetScreen = const LoginScreen();
      } else {
        targetScreen = const OnboardingScreen();
      }

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeInSlide(child: Icon(Icons.mosque, size: 100, color: AppColors.primaryMint(context))),
            const SizedBox(height: 20),
            FadeInSlide(
              delay: 0.5,
              child: Text("Sujoodly", style: GoogleFonts.poppins(fontSize: 42, fontWeight: FontWeight.w700, color: AppColors.textDark(context))),
            ),
            const SizedBox(height: 8),
            FadeInSlide(
              delay: 0.8,
              child: Text("Find Peace Nearby", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.accentBeige(context))),
            ),
            const SizedBox(height: 50),
            FadeInSlide(
              delay: 1.2,
              child: CircularProgressIndicator(color: AppColors.primaryMint(context)),
            )
          ],
        ),
      ),
    );
  }
}