// services/auth_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Sign up with email/password and create Firestore user doc
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String name,
    UserRole role = UserRole.member,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;
    final user = UserModel(
      id: uid,
      email: email,
      name: name,
      role: role,
      projectIds: const [],
      createdAt: DateTime.now(),
    );
    await _db.collection('users').doc(uid).set({
      ...user.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return user;
  }

  /// Sign in and return UserModel from Firestore
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) throw Exception('User document not found');
    return UserModel.fromMap(doc.data()!, uid);
  }

  Future<void> signOut() => _auth.signOut();

  /// Update user profile (name and photoUrl)
  Future<void> updateUserProfile(String uid, {String? name, String? photoUrl}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (updates.isNotEmpty) {
      await _db.collection('users').doc(uid).update(updates);
    }
  }

  /// Fetch UserModel by ID (used to display assignee names, etc.)
  Future<UserModel?> getUserById(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, uid);
  }

  Stream<UserModel?> userStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserModel.fromMap(snap.data()!, uid);
    });
  }
}