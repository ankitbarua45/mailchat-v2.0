import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  User? get firebaseUser => _authService.currentUser;

  // Initialize user data
  Future<void> initializeUser() async {
    print('🔄 Initializing user data...');
    if (_authService.currentUser != null) {
      print('✅ Firebase user exists: ${_authService.currentUser!.uid}');
      _currentUser = await _authService.getCurrentUserData();

      // If user data doesn't exist in Firestore, create it
      if (_currentUser == null) {
        print('⚠️ User document not found, creating it...');
        final created = await _authService.createMissingUserDocument();
        if (created) {
          _currentUser = await _authService.getCurrentUserData();
          print(
            '✅ User document created and loaded: ${_currentUser?.username}',
          );
        } else {
          print('❌ Failed to create user document');
        }
      } else {
        print('✅ User data loaded: ${_currentUser!.username}');
      }
      notifyListeners();
    } else {
      print('❌ No Firebase user found');
    }
  }

  // Sign up
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    Map<String, dynamic> result = await _authService.signUp(
      email: email,
      password: password,
    );

    if (result['success']) {
      await initializeUser();
    }

    _isLoading = false;
    notifyListeners();

    return result;
  }

  // Sign in
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    Map<String, dynamic> result = await _authService.signIn(
      email: email,
      password: password,
    );

    if (result['success']) {
      await initializeUser();
    }

    _isLoading = false;
    notifyListeners();

    return result;
  }

  // Sign out
  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }

  // Refresh user data
  Future<void> refreshUserData() async {
    if (_authService.currentUser != null) {
      _currentUser = await _authService.getCurrentUserData();
      notifyListeners();
    }
  }
}
