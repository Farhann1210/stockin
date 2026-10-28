import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants.dart';
import '../models/business_model.dart';
import '../models/membership_payment_model.dart';

class MembershipAdminService {
  MembershipAdminService([FirebaseFirestore? firestore])
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<void> reviewPayment({
    required MembershipPaymentModel payment,
    required bool approve,
  }) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) {
      throw StateError('Admin harus login untuk memproses membership.');
    }
    final businessRef = _db
        .collection(businessesCollection)
        .doc(payment.businessId);
    final paymentRef = _db
        .collection(membershipPaymentsCollection)
        .doc(payment.id);
    await _db.runTransaction((transaction) async {
      final businessDoc = await transaction.get(businessRef);
      final paymentDoc = await transaction.get(paymentRef);
      if (!businessDoc.exists || !paymentDoc.exists) {
        throw StateError('Data usaha atau pengajuan tidak ditemukan.');
      }
      final business = BusinessModel.fromMap(
        businessDoc.id,
        businessDoc.data()!,
      );
      final currentPayment = MembershipPaymentModel.fromDocument(paymentDoc);
      if (currentPayment.status != 'pending') {
        throw StateError('Pengajuan ini sudah diproses.');
      }
      if (business.pendingPaymentId != currentPayment.id ||
          business.membershipTier != currentPayment.tier) {
        throw StateError(
          'Pengajuan bukan membership aktif yang sedang menunggu.',
        );
      }
      final now = DateTime.now();
      final durationMonths =
          membershipTierForId(currentPayment.tier)?.durationMonths ??
          switch (currentPayment.tier) {
            '100k' => 6,
            '200k' => 12,
            _ => 1,
          };
      transaction.update(paymentRef, {
        'status': approve ? 'approved' : 'rejected',
        'approvedAt': approve ? FieldValue.serverTimestamp() : null,
        'reviewedBy': adminUid,
      });
      transaction.update(businessRef, {
        'membershipStatus': approve ? 'active' : 'inactive',
        'membershipStartDate': approve
            ? FieldValue.serverTimestamp()
            : business.membershipStartDate,
        'membershipEndDate': approve
            ? Timestamp.fromDate(addCalendarMonths(now, durationMonths))
            : business.membershipEndDate,
      });
    });
  }

  Future<void> setMembershipStatus({
    required BusinessModel business,
    required String status,
  }) async {
    if (status != 'inactive' && status != 'expired') {
      throw ArgumentError.value(status, 'status');
    }
    await _db.collection(businessesCollection).doc(business.id).update({
      'membershipStatus': status,
    });
  }

  Future<void> deleteBusiness(BusinessModel business) async {
    final businessRef = _db.collection(businessesCollection).doc(business.id);
    if (!business.isDeleting) {
      await businessRef.update({'isDeleting': true});
    }

    await _banTenantUsers(business.id);
    for (final collection in [
      productsCollection,
      transactionsCollection,
      stockLogsCollection,
      membershipPaymentsCollection,
    ]) {
      await _deleteTenantDocuments(collection, business.id);
    }
    await businessRef.delete();
  }

  Future<void> _banTenantUsers(String businessId) async {
    final collection = _db.collection(usersCollection);
    DocumentSnapshot<Map<String, dynamic>>? lastDocument;
    while (true) {
      var query = collection
          .where('businessId', isEqualTo: businessId)
          .limit(400);
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      final page = await query.get();
      if (page.docs.isEmpty) return;
      final batch = _db.batch();
      var updateCount = 0;
      for (final user in page.docs) {
        if (user.data()['isBanned'] == true) continue;
        batch.update(user.reference, {'isBanned': true});
        updateCount++;
      }
      if (updateCount > 0) await batch.commit();
      lastDocument = page.docs.last;
    }
  }

  Future<void> _deleteTenantDocuments(
    String collectionName,
    String businessId,
  ) async {
    final collection = _db.collection(collectionName);
    while (true) {
      final page = await collection
          .where('businessId', isEqualTo: businessId)
          .limit(400)
          .get();
      if (page.docs.isEmpty) return;

      final batch = _db.batch();
      for (final document in page.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }
}
