import 'package:cloud_firestore/cloud_firestore.dart';

class LogModel {
  final String id;
  final String userName;
  final String masjidName;
  final String? masjidId; // Critical for filtering favorites
  final String action;
  final DateTime timestamp;

  LogModel({
    required this.id,
    required this.userName,
    required this.masjidName,
    this.masjidId,
    required this.action,
    required this.timestamp,
  });

  factory LogModel.fromMap(Map<String, dynamic> map, String id) {
    return LogModel(
      id: id,
      userName: map['userName'] ?? 'Unknown',
      masjidName: map['masjidName'] ?? 'Unknown',
      masjidId: map['masjidId'],
      action: map['action'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userName': userName,
      'masjidName': masjidName,
      'masjidId': masjidId,
      'action': action,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}