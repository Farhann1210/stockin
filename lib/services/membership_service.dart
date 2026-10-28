import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../models/membership_payment_model.dart';

class MembershipService {
  MembershipService({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _db = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final _uuid = const Uuid();

  Future<void> submitPayment({
    required String businessId,
    required String tier,
    required String proofNote,
    Uint8List? proofImageBytes,
    String? proofImageContentType,
  }) async {
    final selected = membershipTiers
        .where((item) => item.id == tier)
        .firstOrNull;
    if (selected == null) throw ArgumentError.value(tier, 'tier');
    if (proofNote.trim().isEmpty && proofImageBytes == null) {
      throw ArgumentError.value(
        proofNote,
        'proofNote',
        'Tambahkan catatan atau gambar bukti pembayaran.',
      );
    }
    if (proofImageBytes != null &&
        proofImageBytes.length > maxMembershipProofImageBytes) {
      throw ArgumentError.value(
        proofImageBytes.length,
        'proofImageBytes',
        'Ukuran gambar bukti maksimal 5 MB.',
      );
    }
    if (proofImageBytes != null &&
        (proofImageContentType == null ||
            !proofImageContentType.startsWith('image/'))) {
      throw ArgumentError.value(
        proofImageContentType,
        'proofImageContentType',
        'Format gambar bukti tidak valid.',
      );
    }
    final businessRef = _db.collection(businessesCollection).doc(businessId);
    final paymentId = _uuid.v4();
    final paymentRef = _db
        .collection(membershipPaymentsCollection)
        .doc(paymentId);
    final proofImagePath = proofImageBytes == null
        ? null
        : 'membership-payment-proofs/$businessId/$paymentId';
    final paymentData = <String, dynamic>{
      'businessId': businessId,
      'tier': tier,
      'amount': selected.price,
      'proofNote': proofNote.trim(),
      'status': 'pending',
      'submittedAt': FieldValue.serverTimestamp(),
      'approvedAt': null,
    };
    if (proofImagePath != null) {
      paymentData['proofImagePath'] = proofImagePath;
    }
    final batch = _db.batch();
    batch.set(paymentRef, paymentData);
    batch.update(businessRef, {
      'membershipStatus': 'pending',
      'membershipTier': tier,
      'maxKasirAccounts': selected.cashierLimit,
      'maxStokAccounts': selected.stockLimit,
      'pendingPaymentId': paymentRef.id,
    });
    try {
      if (proofImageBytes != null && proofImagePath != null) {
        await _storage
            .ref(proofImagePath)
            .putData(
              proofImageBytes,
              SettableMetadata(contentType: proofImageContentType),
            );
      }
      await batch.commit();
    } catch (error) {
      if (proofImagePath != null) {
        try {
          await _storage.ref(proofImagePath).delete();
        } catch (cleanupError) {
          throw StateError(
            'Pengajuan gagal disimpan ($error), dan gambar sementara gagal '
            'dihapus ($cleanupError).',
          );
        }
      }
      rethrow;
    }
  }

  Stream<List<MembershipPaymentModel>> watchPayments(String businessId) => _db
      .collection(membershipPaymentsCollection)
      .where('businessId', isEqualTo: businessId)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map(MembershipPaymentModel.fromDocument).toList(),
      );
}
