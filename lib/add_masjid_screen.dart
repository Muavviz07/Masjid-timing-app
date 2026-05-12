import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // Required
import 'app_colors.dart';
import 'masjid_model.dart';
import 'animations.dart';
import 'firestore_service.dart';
import 'map_picker_screen.dart';
import 'main.dart';

class AddMasjidScreen extends StatefulWidget {
  final Function(Masjid) onAdd;
  const AddMasjidScreen({super.key, required this.onAdd});

  @override
  State<AddMasjidScreen> createState() => _AddMasjidScreenState();
}

class _AddMasjidScreenState extends State<AddMasjidScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _db = FirestoreService();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();

  // --- LOCATION STATE ---
  double _lat = 0.0;
  double _lng = 0.0;
  bool _locationPicked = false;

  final Map<String, String> _timings = {
    "Fajr": "5:00 AM", "Dhuhr": "1:00 PM", "Asr": "4:30 PM", "Maghrib": "6:30 PM", "Isha": "8:00 PM", "Jummah": "1:30 PM",
  };

  // --- TIME PICKER ---
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
    DateTime initialTime = _parseToDateTime(_timings[prayer] ?? "12:00 PM");
    DateTime tempPickedTime = initialTime;

    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          height: 300,
          decoration: BoxDecoration(
              color: AppColors.isDark(c) ? const Color(0xFFF3ECD0) : Colors.white,
              borderRadius: BorderRadius.circular(20)
          ),
          child: Column(
              children: [
                Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Set $prayer", style: GoogleFonts.poppins(color: Colors.black54, fontWeight: FontWeight.w500)),
                          GestureDetector(
                              onTap: () {
                                setState(() => _timings[prayer] = DateFormat('h:mm a').format(tempPickedTime));
                                Navigator.pop(c);
                              },
                              child: Text("Done", style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold))
                          )
                        ]
                    )
                ),
                Expanded(
                    child: CupertinoTheme(
                        data: const CupertinoThemeData(textTheme: CupertinoTextThemeData(dateTimePickerTextStyle: TextStyle(color: Colors.black, fontSize: 22))),
                        child: CupertinoDatePicker(
                            mode: CupertinoDatePickerMode.time,
                            initialDateTime: initialTime,
                            use24hFormat: false,
                            onDateTimeChanged: (val) => tempPickedTime = val
                        )
                    )
                )
              ]
          ),
        ),
      ),
    );
  }

  // --- OPEN MAP PICKER ---
  Future<void> _openMapPicker() async {
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => MapPickerScreen(
              // Pass existing location if picked, else null (user GPS)
              initialLat: _locationPicked ? _lat : null,
              initialLng: _locationPicked ? _lng : null,
            )
        )
    );

    if (result != null && result is Map) {
      setState(() {
        _lat = result['lat'];
        _lng = result['lng'];
        _locationPicked = true;
      });
    }
  }

  // --- VERIFY LOCATION LINK ---
  Future<void> _launchGoogleMaps() async {
    final uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$_lat,$_lng");
    try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (e) { debugPrint("Could not open map"); }
  }

  // --- SUBMIT FORM ---
  Future<void> _submitForm() async {
    if (!_locationPicked) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location Required: Please pick on map.")));
      return;
    }

    if (_formKey.currentState!.validate()) {
      final newMasjid = Masjid(
        name: _nameController.text,
        address: "${_addressController.text}, ${_cityController.text}",
        city: _cityController.text,
        pincode: _pincodeController.text,
        distance: "New",
        timings: _timings,
        isVerified: false,
        lat: _lat,
        lng: _lng,
        gmapsLink: null,
      );

      String newId = await _db.addMasjid(newMasjid);
      await _db.logActivity(userNameNotifier.value, newMasjid.name, "Added new Masjid", newId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Masjid Added!")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: AppColors.textDark(context)),
              onPressed: () => Navigator.pop(context)
          ),
          title: Text("Add New Masjid", style: GoogleFonts.poppins(color: AppColors.textDark(context), fontWeight: FontWeight.w600))
      ),
      body: FadeInSlide(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              Text("Details", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark(context))),
              const SizedBox(height: 16),
              _buildTextField("Name", _nameController, icon: Icons.mosque),
              const SizedBox(height: 20),

              // --- MAP PICKER BUTTON ---
              GestureDetector(
                onTap: _openMapPicker,
                child: Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: _locationPicked ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _locationPicked ? Colors.green : Colors.red.shade300)
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(_locationPicked ? Icons.check_circle : Icons.map_outlined, size: 30, color: _locationPicked ? Colors.green : Colors.red),
                    const SizedBox(height: 8),
                    Text(
                        _locationPicked ? "Location Selected!" : "Tap to Pick Location (Required)",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _locationPicked ? Colors.green : Colors.red)
                    ),
                  ]),
                ),
              ),

              // --- VERIFY BUTTON ---
              if (_locationPicked)
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

              const SizedBox(height: 20),
              _buildTextField("Address", _addressController, icon: Icons.location_on),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: _buildTextField("City", _cityController)), const SizedBox(width: 12), Expanded(child: _buildTextField("Pincode", _pincodeController, isNumber: true))]),

              const SizedBox(height: 32),
              Text("Timings", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark(context))),
              const SizedBox(height: 16),

              GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.5),
                  itemCount: _timings.length,
                  itemBuilder: (c, i) {
                    String k = _timings.keys.elementAt(i);
                    return InkWell(
                        onTap: () => _pickTime(k),
                        child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(color: AppColors.creamCard(c), borderRadius: BorderRadius.circular(12)),
                            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text(k, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark(c))),
                              Text(_timings[k]!, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDark(c), fontWeight: FontWeight.bold))
                            ])
                        )
                    );
                  }
              ),

              const SizedBox(height: 40),
              SizedBox(
                  width: double.infinity, height: 56,
                  child: ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.textDark(context), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: Text("Add Masjid", style: GoogleFonts.poppins(color: AppColors.primaryMint(context), fontSize: 16, fontWeight: FontWeight.w600))
                  )
              ),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController c, {IconData? icon, bool isNumber = false, bool isRequired = true}) {
    return TextFormField(
        controller: c,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        validator: (v) => isRequired && (v == null || v.isEmpty) ? "Required" : null,
        style: TextStyle(color: AppColors.textDark(context)),
        decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: AppColors.accentBeige(context)), prefixIcon: icon != null ? Icon(icon, color: AppColors.accentBeige(context), size: 20) : null, filled: true, fillColor: AppColors.creamCard(context), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16))
    );
  }
}