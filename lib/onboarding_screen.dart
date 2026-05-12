import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';
import 'animations.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {"title": "Find Masjids Instantly", "desc": "Locate nearby Masjids and get accurate prayer timings.", "icon": Icons.location_on_outlined},
    {"title": "Live Jamat Updates", "desc": "Never miss a Jamat. Get real-time updates.", "icon": Icons.access_time},
    {"title": "Contribute & Share", "desc": "Help the community by updating timings.", "icon": Icons.volunteer_activism},
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return FadeInSlide(
                    delay: 0.2,
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_pages[index]['icon'], size: 100, color: AppColors.primaryMint(context)),
                          const SizedBox(height: 40),
                          Text(_pages[index]['title'], textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark(context))),
                          const SizedBox(height: 16),
                          Text(_pages[index]['desc'], textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 16, color: AppColors.textDark(context).withOpacity(0.6))),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: List.generate(_pages.length, (index) => AnimatedContainer(duration: const Duration(milliseconds: 300), margin: const EdgeInsets.only(right: 8), height: 8, width: _currentPage == index ? 24 : 8, decoration: BoxDecoration(color: _currentPage == index ? AppColors.primaryMint(context) : AppColors.accentBeige(context).withOpacity(0.3), borderRadius: BorderRadius.circular(4))))),
                  FloatingActionButton.extended(
                    onPressed: () {
                      if (_currentPage == _pages.length - 1) {
                        _completeOnboarding();
                      } else {
                        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                      }
                    },
                    label: Text(_currentPage == _pages.length - 1 ? "Get Started" : "Next", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.textDark(context))),
                    backgroundColor: AppColors.primaryMint(context),
                    elevation: 0,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}