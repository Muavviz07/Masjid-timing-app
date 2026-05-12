import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'app_colors.dart';

class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const MapPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentCenter;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Check if we have a valid starting point passed in
    if (widget.initialLat != null && widget.initialLng != null &&
        widget.initialLat != 0.0 && widget.initialLng != 0.0) {
      _currentCenter = LatLng(widget.initialLat!, widget.initialLng!);
      _isLoading = false;
    } else {
      // If no valid start point, find the user
      _determinePosition();
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      if (mounted && _currentCenter == null) {
        setState(() { _currentCenter = const LatLng(13.0827, 80.2707); _isLoading = false; });
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted && _currentCenter == null) {
          setState(() { _currentCenter = const LatLng(13.0827, 80.2707); _isLoading = false; });
        }
        return;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        // Only update center if we aren't already looking at a specific place
        // OR if this is triggered by the "My Location" button
        setState(() {
          _currentCenter = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
        // If map is already loaded, move it
        if (_mapController.mapEventStream.isBroadcast) {
          _mapController.move(_currentCenter!, 17.0);
        }
      }
    } catch (e) {
      if (mounted && _currentCenter == null) {
        setState(() { _currentCenter = const LatLng(13.0827, 80.2707); _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text("Drag to Pin Location", style: TextStyle(color: AppColors.textDark(context), fontSize: 18)),
        backgroundColor: AppColors.background(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.textDark(context)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primaryMint(context)))
          : Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter!,
              initialZoom: 17.0,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  setState(() { _currentCenter = position.center; });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.Sujoodly.app',
              ),
            ],
          ),

          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: Icon(Icons.location_pin, color: Colors.red, size: 50),
            ),
          ),

          // LOCATE ME BUTTON (Now calls _determinePosition to force snap back)
          Positioned(
            bottom: 110,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.black87),
              onPressed: _determinePosition,
            ),
          ),

          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  if (_currentCenter != null) {
                    Navigator.pop(context, {
                      'lat': _currentCenter!.latitude,
                      'lng': _currentCenter!.longitude,
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textDark(context),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                ),
                child: Text(
                    "Confirm Location",
                    style: TextStyle(color: AppColors.primaryMint(context), fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}