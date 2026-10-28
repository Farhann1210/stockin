import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants.dart';
import '../models/support_request_model.dart';
import '../models/user_model.dart';

class SupportService {
  SupportService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection(supportRequestsCollection);

  Future<void> submitFeedback({
    required UserModel profile,
    required String message,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != profile.id) {
      throw StateError('Sesi login tidak valid. Silakan masuk kembali.');
    }
    await _requests.add({
      'requestType': 'feedback',
      'userId': profile.id,
      'businessId': profile.businessId,
      'role': profile.role,
      'email': user.email,
      'message': message.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> requestAccountDeletion({required UserModel profile}) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != profile.id) {
      throw StateError('Sesi login tidak valid. Silakan masuk kembali.');
    }
    await _requests.add({
      'requestType': profile.role == roleOwner
          ? 'business_deletion'
          : 'account_deletion',
      'userId': profile.id,
      'businessId': profile.businessId,
      'role': profile.role,
      'email': user.email,
      'message': '',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<SupportRequestModel>> watchRequests() => _requests
      .snapshots()
      .map((snapshot) {
        final requests = snapshot.docs
            .map(SupportRequestModel.fromDocument)
            .toList()
          ..sort(
            (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
              a.createdAt ?? DateTime(1970),
            ),
          );
        return requests;
      });

  Future<void> resolveRequest(String requestId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Admin harus login untuk memproses permintaan.');
    }
    await _requests.doc(requestId).update({
      'status': 'completed',
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': uid,
    });
  }
}
