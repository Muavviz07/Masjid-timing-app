class Masjid {
  final String id;
  final String name;
  final String address;
  final String city;
  final String pincode;
  String distance;
  final bool isVerified;
  final bool hasPendingChanges; // NEW: Tracks if updates are waiting
  bool isFavorite;
  final Map<String, String> timings;
  final double lat;
  final double lng;
  final String? gmapsLink;
  final DateTime? lastUpdated;

  Masjid({
    this.id = '',
    required this.name,
    required this.address,
    required this.city,
    required this.pincode,
    required this.distance,
    this.isVerified = false,
    this.hasPendingChanges = false, // Default false
    this.isFavorite = false,
    required this.timings,
    required this.lat,
    required this.lng,
    this.gmapsLink,
    this.lastUpdated,
  });

  factory Masjid.fromMap(Map<String, dynamic> map, String docId) {
    return Masjid(
      id: docId,
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      pincode: map['pincode'] ?? '',
      distance: map['distance'] ?? '0 km',
      isVerified: map['isVerified'] ?? false,
      hasPendingChanges: map['hasPendingChanges'] ?? false, // Load from DB
      lat: (map['lat'] ?? 0.0).toDouble(),
      lng: (map['lng'] ?? 0.0).toDouble(),
      timings: Map<String, String>.from(map['timings'] ?? {}),
      gmapsLink: map['gmapsLink'],
      lastUpdated: (map['lastUpdated'] as dynamic)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'city': city,
      'pincode': pincode,
      'distance': distance,
      'isVerified': isVerified,
      'hasPendingChanges': hasPendingChanges, // Save to DB
      'lat': lat,
      'lng': lng,
      'timings': timings,
      'gmapsLink': gmapsLink,
      'lastUpdated': lastUpdated,
    };
  }
}