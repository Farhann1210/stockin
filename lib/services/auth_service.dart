import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/constants.dart';
import '../models/business_model.dart';
import '../models/user_model.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw StateError('Login tidak menghasilkan akun pengguna.');
    }
    try {
      final doc = await _db.collection(usersCollection).doc(user.uid).get();
      if (!doc.exists) {
        throw StateError('Profil akun tidak ditemukan.');
      }
      final profile = UserModel.fromDocument(doc);
      if (profile.isBanned) throw const BannedAccountException();
      if (!profile.isActive) {
        throw StateError('Akun ini sedang dinonaktifkan oleh pemilik usaha.');
      }
      if (profile.role != roleAdmin) {
        final businessDoc = await _db
            .collection(businessesCollection)
            .doc(profile.businessId)
            .get();
        final business = businessDoc.data();
        if (business == null || business['isDeleting'] == true) {
          throw StateError('Usaha sedang dihapus. Hubungi admin Stockin.');
        }
      }
      return profile;
    } catch (_) {
      await _auth.signOut();
      rethrow;
    }
  }

  Future<void> registerBusiness({
    required String businessName,
    required String ownerName,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw StateError('Pendaftaran tidak menghasilkan akun pengguna.');
    }

    final businessRef = _db.collection(businessesCollection).doc();
    final userRef = _db.collection(usersCollection).doc(user.uid);
    final batch = _db.batch();
    batch.set(businessRef, {
      'name': businessName.trim(),
      'ownerId': user.uid,
      'membershipTier': 'none',
      'maxKasirAccounts': 0,
      'maxStokAccounts': 0,
      'activeKasirAccounts': 0,
      'activeStokAccounts': 0,
      'seatChangeUid': null,
      'pendingPaymentId': null,
      'membershipStatus': 'inactive',
      'membershipStartDate': null,
      'membershipEndDate': null,
      'isDeleting': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(userRef, {
      'businessId': businessRef.id,
      'name': ownerName.trim(),
      'role': roleOwner,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    try {
      await batch.commit();
    } catch (_) {
      await user.delete();
      rethrow;
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<UserModel?> loadProfile(String uid) async {
    final doc = await _db.collection(usersCollection).doc(uid).get();
    return doc.exists ? UserModel.fromDocument(doc) : null;
  }

  Future<BusinessModel> loadBusiness(String businessId) async {
    final doc = await _db
        .collection(businessesCollection)
        .doc(businessId)
        .get();
    if (!doc.exists) throw StateError('Data usaha tidak ditemukan.');
    return BusinessModel.fromMap(doc.id, doc.data()!);
  }

  Future<UserCredential> createEmployeeAuthUser({
    required String email,
    required String password,
  }) async {
    final appName = 'stockin-employee-creation';
    FirebaseApp app;
    try {
      app = Firebase.app(appName);
    } on FirebaseException {
      app = await Firebase.initializeApp(
        name: appName,
        options: Firebase.app().options,
      );
    }
    return FirebaseAuth.instanceFor(
      app: app,
    ).createUserWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> deleteEmployeeAuthUser(String uid) async {
    final app = Firebase.app('stockin-employee-creation');
    final auth = FirebaseAuth.instanceFor(app: app);
    if (auth.currentUser?.uid == uid) await auth.currentUser!.delete();
  }
}

class BannedAccountException implements Exception {
  const BannedAccountException();
}
