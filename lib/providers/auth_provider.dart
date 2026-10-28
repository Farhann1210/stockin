import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _service = AuthService();
  UserModel? profile;
  bool loading = true;
  String? errorMessage;

  Stream<User?> get authStateChanges => _service.authStateChanges;

  Future<void> refreshProfile(String uid) async {
    loading = true;
    notifyListeners();
    profile = await _service.loadProfile(uid);
    loading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    errorMessage = null;
    profile = await _service.signIn(email, password);
    notifyListeners();
  }

  Future<void> register({
    required String businessName,
    required String ownerName,
    required String email,
    required String password,
  }) async {
    errorMessage = null;
    await _service.registerBusiness(
      businessName: businessName,
      ownerName: ownerName,
      email: email,
      password: password,
    );
    final user = _service.currentUser;
    if (user != null) await refreshProfile(user.uid);
  }

  Future<void> logout() async {
    profile = null;
    await _service.signOut();
    notifyListeners();
  }
}
