import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_colors.dart';
import 'masjid_model.dart';
import 'firestore_service.dart';
import 'main.dart';
import 'map_picker_screen.dart';
import 'change_request_model.dart';

class EditTimingsScreen extends StatefulWidget {
  final Masjid masjid;
  const EditTimingsScreen({super.key, required this.masjid});

  @override
  State<EditTimingsScreen> createState() => _EditTimingsScreenState();
}

class _EditTimingsScreenState extends State<EditTimingsScreen> {
  final FirestoreService _db = FirestoreService();
  late Map<String, String> _times;

  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _pincodeController;

  late double _lat;
  late double _lng;
  bool _locationUpdated = false;

  final List<String> _orderedPrayers = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha", "Jummah"];

  @override
  void initState() {
    super.initState();
    _times = Map.from(widget.masjid.timings);
    _nameController = TextEditingController(text: widget.masjid.name);
    _addressController = TextEditingController(text: widget.masjid.address);
    _cityController = TextEditingController(text: widget.masjid.city);
    _pincodeController = TextEditingController(text: widget.masjid.pincode);
    _lat = widget.masjid.lat;
    _lng = widget.masjid.lng;
  }

  // --- OPEN MAP PICKER ---
  Future<void> _openMapPicker() async {
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => MapPickerScreen(
                initialLat: _lat,
                initialLng: _lng
            )
        )
    );

    if (result != null && result is Map) {
      setState(() {
        _lat = result['lat'];
        _lng = result['lng'];
        _locationUpdated = true;
      });
    }
  }

  // --- VERIFY LOCATION LINK ---
  Future<void> _launchGoogleMaps() async {
    final uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$_lat,$_lng");
    try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (e) { debugPrint("Could not open map"); }
  }

  DateTime _parseToDateTime(String timeStr) {
    try {
      final now = DateTime.now();
      String cleanTime = timeStr.replaceAll('\u202F', ' ').trim();
      final format = DateFormat('h:mm a');
      final dt = format.parse(cleanTime);
      return DateTime(now.year, now.month, now.day, dt.hour, dt.minute);
    } catch (e) { return DateTime.now(); }
  }

  void _pickTime(String prayer) {
    DateTime initialTime = _parseToDateTime(_times[prayer] ?? "12:00 PM");
    DateTime tempPickedTime = initialTime;
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          height: 300,
          decoration: BoxDecoration(color: AppColors.isDark(c) ? const Color(0xFFF3ECD0) : Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            Container(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text("Set $prayer", style: GoogleFonts.poppins(color: Colors.black54, fontWeight: FontWeight.w500)), GestureDetector(onTap: () { setState(() => _times[prayer] = DateFormat('h:mm a').format(tempPickedTime)); Navigator.pop(c); }, child: Text("Done", style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold))) ])),
            Expanded(child: CupertinoTheme(data: const CupertinoThemeData(textTheme: CupertinoTextThemeData(dateTimePickerTextStyle: TextStyle(color: Colors.black, fontSize: 22))), child: CupertinoDatePicker(mode: CupertinoDatePickerMode.time, initialDateTime: initialTime, use24hFormat: false, onDateTimeChanged: (val) => tempPickedTime = val)))
          ]),
        ),
      ),
    );
  }

  void _saveChanges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    Map<String, dynamic> newData = {};
    Map<String, dynamic> oldData = {};

    if (_times.toString() != widget.masjid.timings.toString()) {
      newData['timings'] = _times;
      oldData['timings'] = widget.masjid.timings;
    }

    if (_nameController.text != widget.masjid.name) { newData['name'] = _nameController.text; oldData['name'] = widget.masjid.name; }
    if (_addressController.text != widget.masjid.address) { newData['address'] = _addressController.text; oldData['address'] = widget.masjid.address; }

    // --- CITY AND PINCODE CHECKS ---
    if (_cityController.text != widget.masjid.city) { newData['city'] = _cityController.text; oldData['city'] = widget.masjid.city; }
    if (_pincodeController.text != widget.masjid.pincode) { newData['pincode'] = _pincodeController.text; oldData['pincode'] = widget.masjid.pincode; }

    if (_locationUpdated) {
      newData['lat'] = _lat; newData['lng'] = _lng;
      oldData['lat'] = widget.masjid.lat; oldData['lng'] = widget.masjid.lng;
    }

    if (newData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No changes detected.")));
      return;
    }

    final request = ChangeRequestModel(
      id: '',
      masjidId: widget.masjid.id,
      masjidName: widget.masjid.name,
      userId: user.uid,
      userName: userNameNotifier.value,
      oldData: oldData,
      newData: newData,
      timestamp: DateTime.now(),
    );

    _db.submitChangeRequest(request);

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Update submitted for verification!")));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: AppColors.textDark(context)), onPressed: () => Navigator.pop(context)), title: Text("Suggest Edits", style: GoogleFonts.poppins(color: AppColors.textDark(context), fontWeight: FontWeight.w600))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("General", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark(context))),
          const SizedBox(height: 16),
          _buildTextField("Name", _nameController),
          const SizedBox(height: 20),

          // Map Update Button
          GestureDetector(
            onTap: _openMapPicker,
            child: Container(
              height: 60, width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: _locationUpdated ? Colors.green[50] : Colors.grey[200], borderRadius: BorderRadius.circular(12), border: Border.all(color: _locationUpdated ? Colors.green : Colors.grey.shade400)),
              child: Row(children: [Icon(_locationUpdated ? Icons.check_circle : Icons.edit_location_alt, color: _locationUpdated ? Colors.green : Colors.grey[700]), const SizedBox(width: 12), Text(_locationUpdated ? "New Location Selected" : "Adjust Location on Map", style: TextStyle(fontWeight: FontWeight.bold, color: _locationUpdated ? Colors.green : Colors.grey[800])), const Spacer(), Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[600])]),
            ),
          ),

          // Check on Maps Button
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Center(
              child: TextButton.icon(
                onPressed: _launchGoogleMaps,
                icon: const Icon(Icons.open_in_new, size: 16, color: Colors.blue),
                label: const Text("Check on Google Maps", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
              ),
            ),
          ),

          const SizedBox(height: 12),
          _buildTextField("Address", _addressController),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: _buildTextField("City", _cityController)), const SizedBox(width: 12), Expanded(child: _buildTextField("Pincode", _pincodeController, isNumber: true))]),
          const SizedBox(height: 32),
          Text("Timings", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark(context))),
          const SizedBox(height: 16),
          ..._orderedPrayers.map((prayer) {
            return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: InkWell(
                    onTap: () => _pickTime(prayer),
                    child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                            color: AppColors.creamCard(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.accentBeige(context).withOpacity(0.3))
                        ),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(prayer, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark(context))),
                              Text(
                                  _times[prayer] ?? "--:--",
                                  style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: AppColors.textDark(context), // Fixed Color
                                      fontWeight: FontWeight.bold
                                  )
                              )
                            ]
                        )
                    )
                )
            );
          }),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _saveChanges, style: ElevatedButton.styleFrom(backgroundColor: AppColors.textDark(context), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: Text("Submit for Review", style: GoogleFonts.poppins(color: AppColors.primaryMint(context), fontSize: 16, fontWeight: FontWeight.w600)))),
          const SizedBox(height: 40)
        ]),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController c, {bool isNumber = false}) {
    return TextFormField(controller: c, keyboardType: isNumber ? TextInputType.number : TextInputType.text, style: TextStyle(color: AppColors.textDark(context)), decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: AppColors.accentBeige(context)), filled: true, fillColor: AppColors.creamCard(context), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)));
  }
}