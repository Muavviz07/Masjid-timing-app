import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'app_colors.dart';
import 'animations.dart';
import 'main.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'firestore_service.dart';
import 'admin_panel_screen.dart';
import 'user_model.dart';
import 'developer_info_screen.dart'; // Ensure this import exists

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirestoreService _db = FirestoreService();

  void _editName() {
    final controller = TextEditingController(text: userNameNotifier.value);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.creamCard(context),
        title: Text("Edit Name", style: TextStyle(color: AppColors.textDark(context))),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            style: TextStyle(color: AppColors.textDark(context)),
            decoration: InputDecoration(
              hintText: "Enter new name",
              hintStyle: TextStyle(color: AppColors.accentBeige(context)),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return "Name is required";
              if (v.trim().length <= 3) return "Must be more than 3 chars";
              if (v.trim().length >= 16) return "Must be less than 16 chars";
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                userNameNotifier.value = controller.text.trim();
                setState((){});
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid != null) {
                  await _db.updateUser(uid, {'name': controller.text.trim()});
                }
                Navigator.pop(context);
              }
            },
            child: Text("Save", style: TextStyle(color: AppColors.primaryMint(context), fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(backgroundColor: AppColors.background(context), elevation: 0, leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: AppColors.textDark(context)), onPressed: () => Navigator.pop(context))),
      body: SingleChildScrollView(
        child: FadeInSlide(
          child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.creamCard(context),
              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null
                  ? Icon(Icons.person, size: 50, color: AppColors.textDark(context))
                  : null,
            ),
            const SizedBox(height: 16),

            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ValueListenableBuilder<String>(valueListenable: userNameNotifier, builder: (_, name, __) => Text(name, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark(context)))),
              IconButton(icon: Icon(Icons.edit, size: 18, color: AppColors.accentBeige(context)), onPressed: _editName)
            ]),

            ValueListenableBuilder<String>(
                valueListenable: userEmailNotifier,
                builder: (_, email, __) => Text(email.isEmpty ? "Guest" : email, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.accentBeige(context)))
            ),

            const SizedBox(height: 8),

            StreamBuilder<List<UserModel>>(
                stream: _db.getUsers(),
                builder: (context, snapshot) {
                  String phone = "";
                  if (snapshot.hasData && user != null) {
                    try {
                      final myProfile = snapshot.data!.firstWhere((u) => u.id == user.uid);
                      phone = myProfile.phone;
                    } catch (e) {}
                  }
                  if (phone.isEmpty) return const SizedBox.shrink();
                  return Text(phone, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDark(context).withOpacity(0.7)));
                }
            ),

            const SizedBox(height: 12),

            StreamBuilder<List<UserModel>>(
                stream: _db.getUsers(),
                builder: (context, snapshot) {
                  int points = 0;
                  if (snapshot.hasData && user != null) {
                    try {
                      final myProfile = snapshot.data!.firstWhere((u) => u.id == user.uid);
                      points = myProfile.points;
                    } catch (e) {}
                  }
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber.withOpacity(0.5))
                    ),
                    child: Text(
                        "🏅 $points Reputation",
                        style: TextStyle(color: Colors.amber[800], fontWeight: FontWeight.bold, fontSize: 12)
                    ),
                  );
                }
            ),

            const SizedBox(height: 32),
            _item(Icons.settings, "Settings", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),

            // --- RESTORED BUTTON ---
            _item(Icons.code, "About Developer", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeveloperInfoScreen()))),

            ValueListenableBuilder<String>(
              valueListenable: userEmailNotifier,
              builder: (context, email, _) {
                if (email == "muhammedmuavviz@gmail.com") {
                  return _item(
                      Icons.admin_panel_settings,
                      "Admin Panel",
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen()))
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            _item(Icons.logout, "Logout", _logout),
            const SizedBox(height: 40),
          ])),
        ),
      ),
    );
  }

  Widget _item(IconData icon, String text, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.creamCard(context), borderRadius: BorderRadius.circular(16)), child: Row(children: [Icon(icon, color: AppColors.textDark(context)), const SizedBox(width: 16), Text(text, style: GoogleFonts.poppins(fontSize: 16, color: AppColors.textDark(context))), const Spacer(), Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.accentBeige(context))])));
  }
}