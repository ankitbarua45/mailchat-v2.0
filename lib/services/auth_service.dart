import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Generate unique username
  String _generateUsername(String email) {
    String baseUsername = email.split('@')[0];
    String randomSuffix = Random().nextInt(9999).toString().padLeft(4, '0');
    return '$baseUsername$randomSuffix';
  }

  // Check if username already exists
  Future<bool> _isUsernameUnique(String username) async {
    QuerySnapshot query = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .get();
    return query.docs.isEmpty;
  }

  // Generate unique username (recursive if needed)
  Future<String> _generateUniqueUsername(String email) async {
    String username = _generateUsername(email);
    bool isUnique = await _isUsernameUnique(username);

    while (!isUnique) {
      username = _generateUsername(email);
      isUnique = await _isUsernameUnique(username);
    }

    return username;
  }

  // Sign up with email and password
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
  }) async {
    try {
      // Create user with Firebase Auth
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );

      // Generate unique username
      String username = await _generateUniqueUsername(email);

      // Create user model
      UserModel newUser = UserModel(
        uid: userCredential.user!.uid,
        email: email.trim(),
        username: username,
        createdAt: DateTime.now(),
        isOnline: true,
      );

      // Store user data in Firestore
      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(newUser.toMap());

      return {
        'success': true,
        'message': 'Account created successfully!',
        'username': username,
      };
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _getAuthErrorMessage(e.code)};
    } catch (e) {
      return {
        'success': false,
        'message': 'An error occurred. Please try again.',
      };
    }
  }

  // Sign in with email and password
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Update user online status
      await _firestore.collection('users').doc(userCredential.user!.uid).update(
        {'isOnline': true, 'lastSeen': DateTime.now().toIso8601String()},
      );

      return {'success': true, 'message': 'Logged in successfully!'};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _getAuthErrorMessage(e.code)};
    } catch (e) {
      return {
        'success': false,
        'message': 'An error occurred. Please try again.',
      };
    }
  }

  // Sign out
  Future<void> signOut() async {
    if (currentUser != null) {
      // Update user online status
      await _firestore.collection('users').doc(currentUser!.uid).update({
        'isOnline': false,
        'lastSeen': DateTime.now().toIso8601String(),
      });
    }
    await _auth.signOut();
  }

  // Get user data
  Future<UserModel?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get current user data
  Future<UserModel?> getCurrentUserData() async {
    if (currentUser == null) return null;
    return getUserData(currentUser!.uid);
  }

  // Create missing user document for existing Firebase Auth users
  Future<bool> createMissingUserDocument() async {
    try {
      if (currentUser == null) return false;

      // Generate unique username from email
      String email =
          currentUser!.email ?? 'user${Random().nextInt(9999)}@example.com';
      String username = await _generateUniqueUsername(email);

      // Create user model
      UserModel newUser = UserModel(
        uid: currentUser!.uid,
        email: email,
        username: username,
        createdAt: DateTime.now(),
        isOnline: true,
      );

      // Store user data in Firestore
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .set(newUser.toMap());

      return true;
    } catch (e) {
      print('Error creating user document: $e');
      return false;
    }
  }

  // Get authentication error messages
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
