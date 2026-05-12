import 'package:cloud_firestore/cloud_firestore.dart';

class ChangeRequestModel {
  final String id;
  final String masjidId;
  final String masjidName;
  final String userId; // Who suggested it
  final String userName;
  final Map<String, dynamic> oldData; // Snapshot of data before change
  final Map<String, dynamic> newData; // The proposed changes
  final DateTime timestamp;

  ChangeRequestModel({
    required this.id,
    required this.masjidId,
    required this.masjidName,
    required this.userId,
    required this.userName,
    required this.oldData,
    required this.newData,
    required this.timestamp,
  });

  factory ChangeRequestModel.fromMap(Map<String, dynamic> map, String id) {
    return ChangeRequestModel(
      id: id,
      masjidId: map['masjidId'] ?? '',
      masjidName: map['masjidName'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Unknown',
      oldData: Map<String, dynamic>.from(map['oldData'] ?? {}),
      newData: Map<String, dynamic>.from(map['newData'] ?? {}),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'masjidId': masjidId,
      'masjidName': masjidName,
      'userId': userId,
      'userName': userName,
      'oldData': oldData,
      'newData': newData,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}