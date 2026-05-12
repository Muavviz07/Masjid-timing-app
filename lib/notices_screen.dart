import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; // NEW
import 'app_colors.dart';
import 'firestore_service.dart';
import 'log_model.dart';
import 'animations.dart';

class NoticesScreen extends StatefulWidget {
  final List<String> favoriteIds;
  const NoticesScreen({super.key, required this.favoriteIds});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  // Save current time as the "Last Checked" time
  Future<void> _markAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_viewed_notices', DateTime.now().toIso8601String());
  }

  @override
  Widget build(BuildContext context) {
    final FirestoreService db = FirestoreService();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.textDark(context)),
          onPressed: () => Navigator.pop(context, true), // Return true to refresh bell
        ),
        title: Text("Notices", style: GoogleFonts.poppins(color: AppColors.textDark(context), fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<List<LogModel>>(
        stream: db.getLogs(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error loading notices", style: TextStyle(color: AppColors.textDark(context))));
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: AppColors.primaryMint(context)));

          // Filter logs: Only favorites
          final logs = snapshot.data!.where((log) {
            return log.masjidId != null && widget.favoriteIds.contains(log.masjidId);
          }).toList();

          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 60, color: AppColors.accentBeige(context)),
                  const SizedBox(height: 16),
                  Text("No recent updates", style: GoogleFonts.poppins(color: AppColors.textDark(context).withOpacity(0.6))),
                  Text("Favorite a masjid to see changes here.", style: GoogleFonts.poppins(fontSize: 12, color: AppColors.accentBeige(context))),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final timeString = DateFormat('MMM d, h:mm a').format(log.timestamp);

              return FadeInSlide(
                delay: index * 0.05,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.creamCard(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accentBeige(context).withOpacity(0.15)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.background(context), shape: BoxShape.circle),
                        child: Icon(Icons.update, color: AppColors.primaryMint(context), size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(log.masjidName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.textDark(context), fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                                Text(timeString, style: GoogleFonts.poppins(fontSize: 10, color: AppColors.accentBeige(context))),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Displays the new Detailed Log (Fajr: 5:00 -> 5:15)
                            Text(log.action, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.verifiedBlue, fontWeight: FontWeight.w500, height: 1.4)),
                            const SizedBox(height: 6),
                            Text("Updated by ${log.userName}", style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textDark(context).withOpacity(0.5))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}