import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'app_colors.dart';
import 'masjid_model.dart';
import 'change_request_model.dart';
import 'animations.dart';
import 'edit_timings_screen.dart';
import 'firestore_service.dart';
import 'verify_changes_screen.dart';

class MasjidDetailsScreen extends StatefulWidget {
  final Masjid masjid;
  const MasjidDetailsScreen({super.key, required this.masjid});

  @override
  State<MasjidDetailsScreen> createState() => _MasjidDetailsScreenState();
}

class _MasjidDetailsScreenState extends State<MasjidDetailsScreen> {
  String _distanceText = "Calculating...";
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    if (widget.masjid.distance != "New" && widget.masjid.distance != "0 km") {
      _distanceText = widget.masjid.distance;
    }
    _startLiveTracking();
    _checkAndShowMotivation();
  }

  Future<void> _checkAndShowMotivation() async {
    if (widget.masjid.timings.isNotEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    bool hasSeen = prefs.getBool('seen_motivation_popup_${widget.masjid.id}') ?? false;

    if (!hasSeen && mounted) {
      await prefs.setBool('seen_motivation_popup_${widget.masjid.id}', true);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.creamCard(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.lightbulb, color: Colors.amber, size: 28),
              const SizedBox(width: 10),
              Text("Earn Rewards!", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.textDark(context))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "The Prophet (ﷺ) said: 'Whoever guides someone to goodness will have a reward like one who did it.'",
                style: GoogleFonts.poppins(fontStyle: FontStyle.italic, color: AppColors.textDark(context).withOpacity(0.8)),
              ),
              const SizedBox(height: 16),
              Text(
                "Be the first to update prayer timings for this Masjid!",
                style: GoogleFonts.poppins(color: AppColors.textDark(context), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Maybe Later", style: TextStyle(color: AppColors.accentBeige(context))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => EditTimingsScreen(masjid: widget.masjid)));
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryMint(context)),
              child: Text("Update Now", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _startLiveTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _distanceText = "Loc disabled");
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _distanceText = "Perm denied");
      return;
    }

    const LocationSettings locationSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
            (Position position) {
          double distanceInMeters = Geolocator.distanceBetween(position.latitude, position.longitude, widget.masjid.lat, widget.masjid.lng);
          if (mounted) {
            setState(() {
              _distanceText = "${(distanceInMeters / 1000).toStringAsFixed(1)} km";
            });
          }
        },
        onError: (e) { }
    );
  }

  // --- CORRECT GOOGLE MAPS URL ---
  Future<void> _openMap() async {
    final uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=${widget.masjid.lat},${widget.masjid.lng}");
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not launch map: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderedPrayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha', 'Jummah'];
    String lastUpdatedText = "N/A";
    if (widget.masjid.lastUpdated != null) {
      lastUpdatedText = DateFormat('MMM d, yyyy').format(widget.masjid.lastUpdated!);
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: Stack(
        children: [
          Positioned(right: -30, top: 50, child: Opacity(opacity: 0.03, child: Icon(Icons.mosque, size: 300, color: AppColors.textDark(context)))),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(icon: Icon(Icons.arrow_back_ios, color: AppColors.textDark(context)), onPressed: () => Navigator.pop(context)),
                      const Spacer(),
                      StreamBuilder<List<ChangeRequestModel>>(
                        stream: FirestoreService().getChangesForMasjid(widget.masjid.id),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
                          return GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VerifyChangesScreen(masjidId: widget.masjid.id))),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange)),
                              child: Row(
                                children: [
                                  const Icon(Icons.edit_notifications, size: 14, color: Colors.orange),
                                  const SizedBox(width: 4),
                                  Text("Review Updates", style: GoogleFonts.poppins(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      if (widget.masjid.isVerified)
                        Chip(label: Text("Verified", style: GoogleFonts.poppins(fontSize: 10, color: Colors.white)), backgroundColor: const Color(0xFF4A90E2), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      FadeInSlide(delay: 0.1, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.masjid.name, style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textDark(context))),
                        const SizedBox(height: 8),
                        Row(children: [
                          Icon(Icons.near_me, size: 16, color: AppColors.primaryMint(context)),
                          const SizedBox(width: 4),
                          Text(_distanceText, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.textDark(context))),
                          const SizedBox(width: 12),
                          Container(height: 4, width: 4, decoration: BoxDecoration(color: AppColors.accentBeige(context), shape: BoxShape.circle)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(widget.masjid.address, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDark(context).withOpacity(0.7)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ]),
                      ])),
                      const SizedBox(height: 32),
                      FadeInSlide(delay: 0.2, child: Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppColors.creamCard(context), borderRadius: BorderRadius.circular(24)), child: Column(children: [
                        Text("Prayer Timings", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark(context))),
                        const SizedBox(height: 20),
                        for (var prayer in orderedPrayers) ...[
                          if (widget.masjid.timings.containsKey(prayer)) ...[
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text(prayer, style: GoogleFonts.poppins(fontSize: 16, color: AppColors.textDark(context))),
                              Text(widget.masjid.timings[prayer]!, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark(context))),
                            ]),
                            if (prayer != "Jummah") Divider(color: AppColors.accentBeige(context).withOpacity(0.2), height: 24),
                          ]
                        ],
                        const SizedBox(height: 16),
                        Divider(color: AppColors.accentBeige(context).withOpacity(0.4)),
                        const SizedBox(height: 8),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.history, size: 14, color: AppColors.textDark(context).withOpacity(0.5)),
                          const SizedBox(width: 4),
                          Text("Last updated: $lastUpdatedText", style: GoogleFonts.poppins(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textDark(context).withOpacity(0.5))),
                        ]),
                      ]))),
                      const SizedBox(height: 32),
                      FadeInSlide(delay: 0.3, child: SizedBox(width: double.infinity, height: 56, child: OutlinedButton(onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => EditTimingsScreen(masjid: widget.masjid))); }, style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.textDark(context)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: Text("Suggest Edit", style: GoogleFonts.poppins(color: AppColors.textDark(context), fontWeight: FontWeight.w600))))),
                      const SizedBox(height: 32),
                      FadeInSlide(delay: 0.4, child: GestureDetector(onTap: _openMap, child: Container(height: 150, width: double.infinity, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.accentBeige(context).withOpacity(0.3))), child: Stack(children: [ Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Opacity(opacity: 0.3, child: Icon(Icons.map_outlined, size: 80, color: AppColors.accentBeige(context))))), Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: AppColors.background(context).withOpacity(0.9), borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)]), child: Row(mainAxisSize: MainAxisSize.min, children: [ Icon(Icons.location_on, color: AppColors.primaryMint(context), size: 18), const SizedBox(width: 8), Text("View on Map", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.textDark(context))) ]))) ])))),
                      const SizedBox(height: 40),
                    ],
                    ),
                  ),
                ),
                Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppColors.background(context), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))]), child: ElevatedButton.icon(onPressed: _openMap, style: ElevatedButton.styleFrom(backgroundColor: AppColors.textDark(context), minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), icon: Icon(Icons.directions, color: AppColors.primaryMint(context)), label: Text("Get Directions", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primaryMint(context)))))
              ],
            ),
          ),
        ],
      ),
    );
  }
}