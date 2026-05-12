import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_colors.dart';
import 'firestore_service.dart';
import 'feedback_model.dart';
import 'main.dart';
import 'animations.dart';

class DeveloperInfoScreen extends StatefulWidget {
  const DeveloperInfoScreen({super.key});

  @override
  State<DeveloperInfoScreen> createState() => _DeveloperInfoScreenState();
}

class _DeveloperInfoScreenState extends State<DeveloperInfoScreen> {
  final FirestoreService _db = FirestoreService();
  final TextEditingController _msgController = TextEditingController();
  double _rating = 5.0;
  bool _isSubmitting = false;

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$label copied to clipboard")));
  }

  void _submitFeedback() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please login to send feedback")));
      return;
    }
    if (_msgController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final feedback = FeedbackModel(
        id: '',
        userId: user.uid,
        userName: userNameNotifier.value,
        rating: _rating,
        message: _msgController.text.trim(),
        timestamp: DateTime.now(),
      );

      await _db.submitFeedback(feedback);

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _msgController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("JazakAllah Khair! Message Sent.")));
      }
    } catch (e) {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color cardColor = AppColors.creamCard(context);
    final Color textColor = AppColors.textDark(context);
    final Color accentColor = AppColors.primaryMint(context);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // --- 1. APP BAR & PROFILE HEADER ---
          SliverAppBar(
            expandedHeight: 280,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.background(context),
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: textColor),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradient Background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          accentColor.withOpacity(0.1),
                          AppColors.background(context),
                        ],
                      ),
                    ),
                  ),
                  // Profile Content
                  Center(
                    child: FadeInSlide(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: accentColor, width: 2),
                                boxShadow: [
                                  BoxShadow(color: accentColor.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)
                                ]
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: cardColor,
                              child: Icon(Icons.terminal_rounded, size: 50, color: accentColor),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Muhammed Muavviz",
                            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                          ),
                          Text(
                            "Flutter Developer",
                            style: GoogleFonts.poppins(fontSize: 14, color: AppColors.accentBeige(context), letterSpacing: 1.2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- 2. CONTENT BODY ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // STORY SECTION
                  FadeInSlide(
                    delay: 0.1,
                    child: _buildSectionTitle(context, "The Story"),
                  ),
                  const SizedBox(height: 12),
                  FadeInSlide(
                    delay: 0.2,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.withOpacity(0.1)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
                      ),
                      child: Column(
                        children: [
                          Text(
                            "\"Sujoodly was born out of a frantic search I once had for an early Jummah prayer right before a crucial semester exam. The clock was ticking, and the anxiety of potentially missing the prayer or being late for the test was overwhelming. It was a stressful situation that made me realize how difficult it can be to find the right congregation time when you are on a tight schedule.\"",
                            style: GoogleFonts.poppins(fontSize: 14, fontStyle: FontStyle.italic, color: textColor.withOpacity(0.8), height: 1.6),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 12),
                          Text(
                            "This app is my personal contribution to the community to solve that exact problem. It is completely free and contains no ads because I built it purely for the sake of Allah. My hope is that it helps you find accurate Jamat timings quickly so you never have to rush or worry about missing a prayer again.",
                            style: GoogleFonts.poppins(fontSize: 14, color: textColor, height: 1.6),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // CONNECT SECTION
                  FadeInSlide(
                    delay: 0.3,
                    child: _buildSectionTitle(context, "Connect"),
                  ),
                  const SizedBox(height: 12),
                  FadeInSlide(
                    delay: 0.4,
                    child: Row(
                      children: [
                        Expanded(child: _buildSocialCard(context, "LinkedIn", Icons.link, const Color(0xFF0077B5), "https://www.linkedin.com/in/md-muavviz/")),
                        const SizedBox(width: 16),
                        Expanded(child: _buildSocialCard(context, "GitHub", Icons.code, const Color(0xFF333333), "https://github.com/Muavviz07/")),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeInSlide(
                    delay: 0.5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _buildContactRow(context, Icons.email_outlined, "muhammedmuavviz@gmail.com", "Email"),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                          _buildContactRow(context, Icons.phone_outlined, "+91 93423 10511", "Phone"),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // FEEDBACK SECTION
                  FadeInSlide(
                    delay: 0.6,
                    child: _buildSectionTitle(context, "Leave a Dua"),
                  ),
                  const SizedBox(height: 12),
                  FadeInSlide(
                    delay: 0.7,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: accentColor.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return GestureDetector(
                                onTap: () => setState(() => _rating = index + 1.0),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(
                                    index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                    color: Colors.amber,
                                    size: 36,
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _msgController,
                            style: TextStyle(color: textColor),
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: "Your feedback or dua...",
                              hintStyle: TextStyle(color: AppColors.accentBeige(context)),
                              filled: true,
                              fillColor: AppColors.background(context),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitFeedback,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: textColor,
                                foregroundColor: AppColors.background(context), // Inverted text color
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Text("Send Message", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.primaryMint(context))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Row(
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: AppColors.primaryMint(context), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark(context))),
      ],
    );
  }

  Widget _buildSocialCard(BuildContext context, String label, IconData icon, Color color, String url) {
    return GestureDetector(
      onTap: () => _launchUrl(url),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(BuildContext context, IconData icon, String text, String label) {
    return InkWell(
      onTap: () => _copyToClipboard(text, label),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.background(context), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 20, color: AppColors.accentBeige(context)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(text, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDark(context), fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.copy, size: 16, color: AppColors.accentBeige(context).withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}