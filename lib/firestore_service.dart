import 'package:flutter/material.dart'; // REQUIRED for debugPrint
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'masjid_model.dart';
import 'user_model.dart';
import 'log_model.dart';
import 'change_request_model.dart';
import 'feedback_model.dart';

class FirestoreService {
  final CollectionReference _masjidCollection = FirebaseFirestore.instance.collection('masjids');
  final CollectionReference _usersCollection = FirebaseFirestore.instance.collection('users');
  final CollectionReference _logsCollection = FirebaseFirestore.instance.collection('logs');
  final CollectionReference _changesCollection = FirebaseFirestore.instance.collection('change_requests');
  final CollectionReference _feedbackCollection = FirebaseFirestore.instance.collection('feedback');
  final CollectionReference _configCollection = FirebaseFirestore.instance.collection('app_config');

  // --- APP CONFIG (VERSION CHECK) ---
  Future<Map<String, dynamic>?> getAppConfig() async {
    try {
      DocumentSnapshot doc = await _configCollection.doc('main').get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("Config Fetch Error: $e"); // Now works
    }
    return null;
  }

  // --- MASJIDS ---
  Stream<List<Masjid>> getMasjids() {
    return _masjidCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Masjid.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Future<String> addMasjid(Masjid masjid) async {
    Map<String, dynamic> data = masjid.toMap();
    data['lastUpdated'] = FieldValue.serverTimestamp();
    DocumentReference docRef = await _masjidCollection.add(data);
    return docRef.id;
  }

  Future<void> updateMasjidDetails(String id, Map<String, String> newTimings, {String? gmapsLink, String? name, String? address, String? city, String? pincode, double? lat, double? lng}) async {
    Map<String, dynamic> data = {'timings': newTimings, 'lastUpdated': FieldValue.serverTimestamp()};
    if (name != null) data['name'] = name;
    if (address != null) data['address'] = address;
    if (city != null) data['city'] = city;
    if (pincode != null) data['pincode'] = pincode;
    if (lat != null) data['lat'] = lat;
    if (lng != null) data['lng'] = lng;
    await _masjidCollection.doc(id).update(data);
  }

  Future<void> deleteMasjid(String id) async {
    await _masjidCollection.doc(id).delete();
  }

  Future<void> deleteAllMasjids() async {
    final snapshot = await _masjidCollection.get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> verifyMasjid(String id) async {
    await _masjidCollection.doc(id).update({'isVerified': true});
  }

  // --- CHANGE REQUESTS ---
  Future<void> submitChangeRequest(ChangeRequestModel request) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();
    DocumentReference newReqRef = _changesCollection.doc();
    batch.set(newReqRef, request.toMap());

    DocumentReference masjidRef = _masjidCollection.doc(request.masjidId);
    batch.update(masjidRef, {'hasPendingChanges': true});

    await batch.commit();
  }

  Stream<List<ChangeRequestModel>> getAllChangeRequests() {
    return _changesCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => ChangeRequestModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList());
  }

  Stream<List<ChangeRequestModel>> getChangesForMasjid(String masjidId) {
    return _changesCollection
        .where('masjidId', isEqualTo: masjidId)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => ChangeRequestModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList());
  }

  Future<void> _updatePendingStatus(String masjidId) async {
    final snapshot = await _changesCollection.where('masjidId', isEqualTo: masjidId).get();
    if (snapshot.docs.isEmpty) {
      await _masjidCollection.doc(masjidId).update({'hasPendingChanges': false});
    }
  }

  Future<void> acceptChangeRequest(ChangeRequestModel request, String verifierName) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && request.userId == currentUser.uid) {
      throw Exception("You cannot verify your own request.");
    }

    WriteBatch batch = FirebaseFirestore.instance.batch();
    DocumentReference masjidRef = _masjidCollection.doc(request.masjidId);

    Map<String, dynamic> updates = Map.from(request.newData);
    updates['lastUpdated'] = FieldValue.serverTimestamp();

    batch.update(masjidRef, updates);
    batch.delete(_changesCollection.doc(request.id));

    if (request.userId.isNotEmpty) {
      DocumentReference userRef = _usersCollection.doc(request.userId);
      batch.update(userRef, {'points': FieldValue.increment(10)});
    }
    if (currentUser != null) {
      DocumentReference verifierRef = _usersCollection.doc(currentUser.uid);
      batch.update(verifierRef, {'points': FieldValue.increment(2)});
    }

    await batch.commit();
    await logActivity(verifierName, request.masjidName, "Verified Update by ${request.userName}", request.masjidId);
    await _updatePendingStatus(request.masjidId);
  }

  Future<void> rejectChangeRequest(ChangeRequestModel request, String verifierName) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();
    batch.delete(_changesCollection.doc(request.id));

    if (request.userId.isNotEmpty) {
      DocumentReference userRef = _usersCollection.doc(request.userId);
      batch.update(userRef, {'points': FieldValue.increment(-5)});
    }

    await batch.commit();
    await logActivity(verifierName, request.masjidName, "Rejected Update by ${request.userName}", request.masjidId);
    await _updatePendingStatus(request.masjidId);
  }

  // --- USERS ---
  Future<bool> checkUserExists(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    return doc.exists;
  }

  Future<void> createGoogleUser(User user, String name, String phone) async {
    await _usersCollection.doc(user.uid).set({
      'name': name,
      'email': user.email ?? "",
      'phone': phone,
      'role': 'user',
      'createdAt': FieldValue.serverTimestamp(),
      'points': 0,
    });
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _usersCollection.doc(uid).update(data);
  }

  Stream<List<UserModel>> getUsers() {
    return _usersCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // --- LOGS ---
  Future<void> logActivity(String userName, String masjidName, String action, String masjidId) async {
    await _logsCollection.add({
      'userName': userName,
      'masjidName': masjidName,
      'masjidId': masjidId,
      'action': action,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<LogModel>> getLogs() {
    return _logsCollection.orderBy('timestamp', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return LogModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // --- FEEDBACK ---
  Future<void> submitFeedback(FeedbackModel feedback) async {
    await _feedbackCollection.add(feedback.toMap());
  }

  Stream<List<FeedbackModel>> getAllFeedback() {
    return _feedbackCollection.orderBy('timestamp', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return FeedbackModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }
}