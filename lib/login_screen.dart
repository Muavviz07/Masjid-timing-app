import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'app_colors.dart';
import 'animations.dart';
import 'home_screen.dart';
import 'firestore_service.dart';
import 'main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirestoreService _db = FirestoreService();
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        bool exists = await _db.checkUserExists(user.uid);

        if (!exists) {
          if (mounted) await _showRegistrationDialog(user);
        } else {
          userNameNotifier.value = user.displayName ?? "User";
          userEmailNotifier.value = user.email ?? "";
          if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
        }
      }
    } catch (e) {
      debugPrint("Login Error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Failed: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showRegistrationDialog(User user) async {
    final nameController = TextEditingController(text: user.displayName);
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            backgroundColor: AppColors.creamCard(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text("Complete Profile", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.textDark(context))),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // NAME VALIDATION
                  TextFormField(
                    controller: nameController,
                    style: TextStyle(color: AppColors.textDark(context)),
                    decoration: InputDecoration(
                        labelText: "Your Name",
                        labelStyle: TextStyle(color: AppColors.accentBeige(context)),
                        hintText: "4-15 characters"
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return "Name is required";
                      if (v.trim().length <= 3) return "Must be more than 3 chars";
                      if (v.trim().length >= 16) return "Must be less than 16 chars";
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // PHONE VALIDATION (STRICT 10 DIGITS)
                  TextFormField(
                    controller: phoneController,
                    style: TextStyle(color: AppColors.textDark(context)),
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                        labelText: "Mobile Number",
                        labelStyle: TextStyle(color: AppColors.accentBeige(context)),
                        hintText: "9876543210"
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return "Phone is required";
                      // STRICT CHECK: Must be exactly 10 digits
                      if (v.trim().length != 10) return "Must be exactly 10 digits";
                      // Ensure only numbers
                      if (!RegExp(r'^[0-9]+$').hasMatch(v.trim())) return "Only numbers allowed";
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      await _db.createGoogleUser(user, nameController.text.trim(), phoneController.text.trim());

                      userNameNotifier.value = nameController.text.trim();
                      userEmailNotifier.value = user.email ?? "";

                      if (mounted) {
                        Navigator.pop(context);
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textDark(context),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Save & Continue", style: GoogleFonts.poppins(color: AppColors.primaryMint(context), fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              )
            ],
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeInSlide(child: Icon(Icons.mosque, size: 80, color: AppColors.primaryMint(context))),
              const SizedBox(height: 24),
              FadeInSlide(delay: 0.1, child: Text("Welcome to Sujoodly", style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textDark(context)))),
              const SizedBox(height: 8),
              FadeInSlide(delay: 0.2, child: Text("Connect with your community", style: GoogleFonts.poppins(fontSize: 16, color: AppColors.accentBeige(context)))),
              const SizedBox(height: 60),
              FadeInSlide(
                delay: 0.3,
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.login, color: Colors.blue),
                        const SizedBox(width: 12),
                        Text("Sign in with Google", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600))
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}