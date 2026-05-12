import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone; // Optional
  final String role;
  final DateTime createdAt;
  final int points; // Reputation Score

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.role = 'user',
    required this.createdAt,
    this.points = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'createdAt': createdAt,
      'points': points,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'user',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2024),
      points: map['points'] ?? 0,
    );
  }
}