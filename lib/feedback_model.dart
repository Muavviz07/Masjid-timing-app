import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackModel {
  final String id;
  final String userId;
  final String userName;
  final double rating;
  final String message;
  final DateTime timestamp;

  FeedbackModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  factory FeedbackModel.fromMap(Map<String, dynamic> map, String id) {
    return FeedbackModel(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Anonymous',
      rating: (map['rating'] ?? 0.0).toDouble(),
      message: map['message'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}