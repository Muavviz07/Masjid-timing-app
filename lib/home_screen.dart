import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:home_widget/home_widget.dart';
import 'app_colors.dart';
import 'animations.dart';
import 'masjid_model.dart';
import 'log_model.dart';
import 'add_masjid_screen.dart';
import 'masjid_details_screen.dart';
import 'profile_screen.dart';
import 'notices_screen.dart';
import 'firestore_service.dart';
import 'main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final FirestoreService _db = FirestoreService();

  String _selectedFilter = "All";
  bool _isAscending = true;
  String _searchQuery = "";
  final FocusNode _searchFocusNode = FocusNode();
  List<String> _favoriteIds = [];
  Position? _currentPosition;
  DateTime? _lastViewedNotices;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enforceLocationPermission();
    _loadUserData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enforceLocationPermission();
    }
  }

  // --- WIDGET SYNC ---
  Future<void> _updateAppWidget(List<Masjid> masjids) async {
    try {
      List<Masjid> favs = masjids.where((m) => _favoriteIds.contains(m.id)).toList();

      if (favs.isEmpty) {
        await HomeWidget.saveWidgetData<int>('fav_count', 0);
        await HomeWidget.saveWidgetData<String>('masjid_name_0', 'Sujoodly');
        await HomeWidget.saveWidgetData<String>('prayer_time_0', '--:--');
        await HomeWidget.saveWidgetData<String>('prayer_name_0', 'Add Favorites');
      } else {
        await HomeWidget.saveWidgetData<int>('fav_count', favs.length);
        for (int i = 0; i < favs.length; i++) {
          final m = favs[i];
          final next = _getNextPrayerInfo(m.timings);

          await HomeWidget.saveWidgetData<String>('masjid_name_$i', m.name);
          await HomeWidget.saveWidgetData<String>('prayer_name_$i', next['name'] ?? "Prayer");
          await HomeWidget.saveWidgetData<String>('prayer_time_$i', next['time'] ?? "--:--");
        }
      }

      await HomeWidget.updateWidget(
        name: 'PrayerWidgetProvider',
        androidName: 'PrayerWidgetProvider',
      );
    } catch (e) {
      debugPrint("Widget Error: $e");
    }
  }

  // --- LOCATION ---
  Future<void> _enforceLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationDialog("Location Services Disabled", "Please enable GPS to use Sujoodly.", () => Geolocator.openLocationSettings());
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showLocationDialog("Permission Required", "This app needs location to find nearby Masjids.", () => Geolocator.requestPermission());
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showLocationDialog("Permission Blocked", "Please allow location in Settings.", () => Geolocator.openAppSettings());
      return;
    }
    _refreshLocation();
  }

  Future<void> _refreshLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) setState(() => _currentPosition = position);
    } catch (e) {
      debugPrint("Error refreshing location: $e");
    }
  }

  void _showLocationDialog(String title, String msg, Function onAction) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.creamCard(context),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.textDark(context))),
        content: Text(msg, style: GoogleFonts.poppins(color: AppColors.textDark(context))),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onAction();
            },
            child: Text("Enable", style: TextStyle(color: AppColors.textDark(context), fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
    );
  }

  // --- DATA LOADING ---
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteIds = prefs.getStringList('favorite_masjids') ?? [];
      String? lastViewedStr = prefs.getString('last_viewed_notices');
      if (lastViewedStr != null) {
        _lastViewedNotices = DateTime.parse(lastViewedStr);
      } else {
        _lastViewedNotices = DateTime.now();
        prefs.setString('last_viewed_notices', _lastViewedNotices!.toIso8601String());
      }
    });
    if (prefs.getString('user_name') != null) userNameNotifier.value = prefs.getString('user_name')!;
  }

  Future<void> _toggleFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favoriteIds.contains(id)) {
        _favoriteIds.remove(id);
      } else {
        _favoriteIds.add(id);
      }
    });
    await prefs.setStringList('favorite_masjids', _favoriteIds);
  }

  // --- HELPERS ---
  DateTime _getSpecificPrayerTime(Masjid masjid, String prayerName) {
    if (masjid.timings.isEmpty || !masjid.timings.containsKey(prayerName)) return DateTime(2100);
    try {
      final now = DateTime.now();
      String cleanTime = masjid.timings[prayerName]!.replaceAll("\u202F", " ").trim();
      final format = DateFormat('h:mm a');
      DateTime parsedTime;
      try { parsedTime = format.parse(cleanTime); } catch (_) { parsedTime = DateFormat.jm().parse(cleanTime); }
      return DateTime(now.year, now.month, now.day, parsedTime.hour, parsedTime.minute);
    } catch (e) { return DateTime(2100); }
  }

  DateTime _getNextPrayerDateTime(Masjid masjid) {
    if (masjid.timings.isEmpty) return DateTime(2100);
    final now = DateTime.now();
    final format = DateFormat('h:mm a');
    bool isFriday = now.weekday == DateTime.friday;
    final prayers = ["Fajr", isFriday ? "Jummah" : "Dhuhr", "Asr", "Maghrib", "Isha"];
    for (var prayer in prayers) {
      if (masjid.timings.containsKey(prayer)) {
        try {
          String cleanTime = masjid.timings[prayer]!.replaceAll("\u202F", " ").trim();
          DateTime parsedTime;
          try { parsedTime = format.parse(cleanTime); } catch (_) { parsedTime = DateFormat.jm().parse(cleanTime); }
          DateTime prayerDateTime = DateTime(now.year, now.month, now.day, parsedTime.hour, parsedTime.minute);
          if (prayerDateTime.add(const Duration(minutes: 10)).isAfter(now)) return prayerDateTime;
        } catch (e) {}
      }
    }
    if (masjid.timings.containsKey("Fajr")) {
      try {
        String cleanTime = masjid.timings["Fajr"]!.replaceAll("\u202F", " ").trim();
        DateTime parsedTime = format.parse(cleanTime);
        return DateTime(now.year, now.month, now.day + 1, parsedTime.hour, parsedTime.minute);
      } catch (_) {}
    }
    return DateTime(2100);
  }

  List<Masjid> _filterList(List<Masjid> allMasjids) {
    List<Masjid> list = List.from(allMasjids);

    if (_currentPosition != null) {
      for (var masjid in list) {
        double distanceInMeters = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          masjid.lat,
          masjid.lng,
        );
        masjid.distance = "${(distanceInMeters / 1000).toStringAsFixed(1)} km";
      }
    } else {
      // If no location, set a placeholder so it doesn't say "New"
      for (var masjid in list) {
        masjid.distance = "...";
      }
    }

    for (var masjid in list) {
      masjid.isFavorite = _favoriteIds.contains(masjid.id);
    }

    if (_searchQuery.isNotEmpty) {
      String q = _searchQuery.toLowerCase();
      list = list.where((m) =>
      m.name.toLowerCase().contains(q) ||
          m.address.toLowerCase().contains(q) ||
          m.city.toLowerCase().contains(q) ||
          m.pincode.contains(q)
      ).toList();
    }

    if (_selectedFilter == "Verified") list = list.where((m) => m.isVerified).toList();
    if (_selectedFilter == "Favorites") list = list.where((m) => m.isFavorite).toList();

    if (_selectedFilter == "Nearby" && _currentPosition != null) {
      list = list.where((m) {
        double dist = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, m.lat, m.lng);
        return dist <= 3000;
      }).toList();

      list.sort((a, b) {
        double distA = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, a.lat, a.lng);
        double distB = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, b.lat, b.lng);
        return distA.compareTo(distB);
      });
    } else if (_selectedFilter == "Next Jamat") {
      list.sort((a, b) => _getNextPrayerDateTime(a).compareTo(_getNextPrayerDateTime(b)));
    } else {
      const prayers = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha", "Jummah"];
      if (prayers.contains(_selectedFilter)) {
        list.sort((a, b) {
          DateTime t1 = _getSpecificPrayerTime(a, _selectedFilter);
          DateTime t2 = _getSpecificPrayerTime(b, _selectedFilter);
          return _isAscending ? t1.compareTo(t2) : t2.compareTo(t1);
        });
      }
    }

    return list;
  }

  Map<String, String> _getNextPrayerInfo(Map<String, String> timings) {
    if (timings.isEmpty) return {"name": "Info", "time": "N/A"};
    final now = DateTime.now();
    final format = DateFormat('h:mm a');
    bool isFriday = now.weekday == DateTime.friday;
    final prayers = ["Fajr", isFriday ? "Jummah" : "Dhuhr", "Asr", "Maghrib", "Isha"];
    for (var prayer in prayers) {
      if (timings.containsKey(prayer)) {
        String timeStr = timings[prayer]!;
        try {
          String cleanTime = timeStr.replaceAll("\u202F", " ").trim();
          DateTime parsedTime;
          try { parsedTime = format.parse(cleanTime); } catch (_) { parsedTime = DateFormat.jm().parse(cleanTime); }
          DateTime prayerDateTime = DateTime(now.year, now.month, now.day, parsedTime.hour, parsedTime.minute);
          if (prayerDateTime.add(const Duration(minutes: 10)).isAfter(now)) { return {"name": prayer, "time": timeStr}; }
        } catch (e) { }
      }
    }
    return {"name": "Fajr", "time": timings["Fajr"] ?? "--:--"};
  }

  Future<void> _openMasjidsNearMe() async {
    final url = Uri.parse("https://www.google.com/maps/search/masjids+near+me");
    try { await launchUrl(url, mode: LaunchMode.externalApplication); } catch (e) { debugPrint("Error launching map"); }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background(context),
        body: Stack(
          children: [
            Positioned(right: -50, top: -50, child: Opacity(opacity: 0.05, child: Icon(Icons.mosque, size: 300, color: AppColors.textDark(context)))),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        FadeInSlide(delay: 0.1, child: _buildHeader()),
                        const SizedBox(height: 24),
                        FadeInSlide(delay: 0.2, child: _buildSearchBar()),
                        const SizedBox(height: 24),
                        FadeInSlide(delay: 0.3, child: _buildFilters()),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

                  Expanded(
                    child: StreamBuilder<List<Masjid>>(
                      stream: _db.getMasjids(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) return Center(child: Text("Error loading data", style: TextStyle(color: AppColors.textDark(context))));
                        if (!snapshot.hasData) {
                          return Center(child: CircularProgressIndicator(color: AppColors.primaryMint(context)));
                        }

                        final masjids = _filterList(snapshot.data ?? []);
                        final favMasjids = masjids.where((m) => m.isFavorite).toList();
                        _updateAppWidget(masjids);

                        return RefreshIndicator(
                          onRefresh: _refreshLocation,
                          color: AppColors.primaryMint(context),
                          backgroundColor: AppColors.creamCard(context),
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              if (favMasjids.isNotEmpty && _selectedFilter == "All")
                                SliverToBoxAdapter(
                                  child: FadeInSlide(
                                    delay: 0.4,
                                    child: _buildFavoritesWidget(favMasjids),
                                  ),
                                ),

                              if (masjids.isEmpty)
                                SliverFillRemaining(
                                  child: Center(child: Text("No Masjids Found", style: GoogleFonts.poppins(color: AppColors.accentBeige(context)))),
                                )
                              else
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                          (context, index) {
                                        if (index == masjids.length) return _buildMapPreview();
                                        return FadeInSlide(delay: 0.1, child: _buildMasjidCard(masjids[index]));
                                      },
                                      childCount: masjids.length + 1,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            _searchFocusNode.unfocus();
            Navigator.push(context, MaterialPageRoute(builder: (context) => AddMasjidScreen(onAdd: (m) {})));
          },
          backgroundColor: AppColors.textDark(context),
          label: Text("Add Masjid", style: GoogleFonts.poppins(color: AppColors.primaryMint(context), fontWeight: FontWeight.w600)),
          icon: Icon(Icons.add_location_alt_outlined, color: AppColors.primaryMint(context)),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Assalamu Alaykum,", style: GoogleFonts.poppins(fontSize: 16, color: AppColors.accentBeige(context), fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text("Find Peace Nearby", style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textDark(context), letterSpacing: -0.5)),
        ]),
        Row(children: [
          GestureDetector(
            onTap: () async { _searchFocusNode.unfocus(); await Navigator.push(context, MaterialPageRoute(builder: (_) => NoticesScreen(favoriteIds: _favoriteIds))); _loadUserData(); },
            child: Stack(children: [
              CircleAvatar(radius: 22, backgroundColor: AppColors.creamCard(context), child: Icon(Icons.notifications_outlined, color: AppColors.textDark(context), size: 22)),
              Positioned(right: 2, top: 2, child: StreamBuilder<List<LogModel>>(
                stream: _db.getLogs(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || _favoriteIds.isEmpty || _lastViewedNotices == null) return const SizedBox.shrink();
                  bool hasUnread = snapshot.data!.any((log) => _favoriteIds.contains(log.masjidId) && log.timestamp.isAfter(_lastViewedNotices!));
                  if (hasUnread) return Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: AppColors.background(context), width: 1.5)));
                  return const SizedBox.shrink();
                },
              ))
            ]),
          ),
          const SizedBox(width: 12),
          GestureDetector(onTap: () { _searchFocusNode.unfocus(); Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())); }, child: CircleAvatar(radius: 22, backgroundColor: AppColors.creamCard(context), child: Icon(Icons.person, color: AppColors.textDark(context)))),
        ]),
      ],
    );
  }

  Widget _buildSearchBar() { return Container(decoration: BoxDecoration(color: AppColors.creamCard(context), borderRadius: BorderRadius.circular(20)), child: TextField(focusNode: _searchFocusNode, onChanged: (value) => setState(() => _searchQuery = value), style: TextStyle(color: AppColors.textDark(context)), decoration: InputDecoration(hintText: "Search Masjid, Area...", hintStyle: GoogleFonts.poppins(color: AppColors.accentBeige(context).withOpacity(0.7)), prefixIcon: Icon(Icons.search, color: AppColors.accentBeige(context)), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)))); }

  Widget _buildFilters() {
    final filters = ["All", "Nearby", "Verified", "Favorites", "Next Jamat"];
    final prayers = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha", "Jummah"];
    final allChips = [...filters, ...prayers];
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: allChips.map((label) { final isSelected = _selectedFilter == label; final isPrayerChip = prayers.contains(label); return Padding(padding: const EdgeInsets.only(right: 12), child: InkWell(onTap: () { setState(() { if (_selectedFilter == label && isPrayerChip) { _isAscending = !_isAscending; } else { _selectedFilter = label; _isAscending = true; } }); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), decoration: BoxDecoration(color: isSelected ? AppColors.textDark(context) : AppColors.creamCard(context), borderRadius: BorderRadius.circular(30)), child: Row(mainAxisSize: MainAxisSize.min, children: [ Text(label, style: GoogleFonts.poppins(color: isSelected ? AppColors.primaryMint(context) : AppColors.textDark(context).withOpacity(0.6), fontWeight: FontWeight.w600)), if (isSelected && isPrayerChip) ...[ const SizedBox(width: 6), Icon(_isAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: AppColors.primaryMint(context)) ] ])))); }).toList()));
  }

  Widget _buildFavoritesWidget(List<Masjid> favMasjids) {
    return Container(
      height: 160,
      margin: const EdgeInsets.only(bottom: 20),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: favMasjids.length,
        itemBuilder: (context, index) {
          final masjid = favMasjids[index];
          final next = _getNextPrayerInfo(masjid.timings);
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MasjidDetailsScreen(masjid: masjid))),
            child: Container(
              width: 240,
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
                border: Border.all(color: const Color(0xFF2E2E2E)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Flexible(child: Text(masjid.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))), const Icon(Icons.favorite, color: Colors.redAccent, size: 18)]),
                Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [Text(next['time'] ?? "--:--", style: GoogleFonts.poppins(color: const Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 28)), const SizedBox(width: 8), Text(next['name'] ?? "Prayer", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14))]),
                Row(children: [const Icon(Icons.near_me, color: Colors.grey, size: 14), const SizedBox(width: 6), Text(masjid.distance, style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12))])
              ]),
            ),
          );
        },
      ),
    );
  }

  // --- FIXED: Display Distance as "..." if "New" or "0 km" + Better Layout ---
  Widget _buildMasjidCard(Masjid masjid) {
    final next = _getNextPrayerInfo(masjid.timings);
    String displayLabel;
    const prayers = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha", "Jummah"];
    bool isPrayerFilter = prayers.contains(_selectedFilter);
    if (isPrayerFilter) { String time = masjid.timings[_selectedFilter] ?? "--:--"; displayLabel = "$_selectedFilter: $time"; } else { displayLabel = next['name'] == "Info" ? "Join to update timings" : "Next: ${next['name']} ${next['time']}"; }

    // FIX: Clean distance text logic
    String displayDistance = masjid.distance;
    if (masjid.distance == "New" || masjid.distance == "0 km") {
      displayDistance = "..."; // Or "Locating"
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: AppColors.creamCard(context), borderRadius: BorderRadius.circular(24)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _searchFocusNode.unfocus();
            Navigator.push(context, MaterialPageRoute(builder: (context) => MasjidDetailsScreen(masjid: masjid)));
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Flexible(child: Text(masjid.name, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark(context)), overflow: TextOverflow.ellipsis)),
                            if (masjid.isVerified) ...[const SizedBox(width: 6), const Icon(Icons.verified, color: AppColors.verifiedBlue, size: 16)],
                          ]),
                          const SizedBox(height: 4),
                          Text(masjid.address, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textDark(context).withOpacity(0.5)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        InkWell(
                          onTap: () => _toggleFavorite(masjid.id),
                          child: Icon(masjid.isFavorite ? Icons.favorite : Icons.favorite_border, color: masjid.isFavorite ? Colors.red : AppColors.accentBeige(context), size: 22),
                        ),
                        if (masjid.hasPendingChanges) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), shape: BoxShape.circle),
                            child: const Icon(Icons.pending_actions, color: Colors.orange, size: 16),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: AppColors.background(context), borderRadius: BorderRadius.circular(10)), child: Text(displayLabel, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark(context)))),
                  const Spacer(),
                  Icon(Icons.location_on_outlined, size: 14, color: AppColors.accentBeige(context)),
                  const SizedBox(width: 4),
                  Text(displayDistance, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textDark(context)))
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapPreview() { return GestureDetector(onTap: _openMasjidsNearMe, child: Container(height: 180, margin: const EdgeInsets.only(top: 20, bottom: 80), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 4))]), child: Stack(children: [ ClipRRect(borderRadius: BorderRadius.circular(24), child: Container(color: Colors.blue[50])), Center(child: Column(mainAxisSize: MainAxisSize.min, children: [ Icon(Icons.map_outlined, size: 40, color: AppColors.textDark(context)), const SizedBox(height: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: AppColors.textDark(context), borderRadius: BorderRadius.circular(20)), child: Text("View Nearby Masjids on Map", style: GoogleFonts.poppins(color: AppColors.primaryMint(context), fontWeight: FontWeight.w600))) ])) ]))); }
}