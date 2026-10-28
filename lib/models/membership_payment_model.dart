import 'package:cloud_firestore/cloud_firestore.dart';

class MembershipPaymentModel {
  const MembershipPaymentModel({
    required this.id,
    required this.businessId,
    required this.tier,
    required this.amount,
    required this.proofNote,
    required this.status,
    this.proofImagePath,
    this.submittedAt,
    this.approvedAt,
  });

  final String id;
  final String businessId;
  final String tier;
  final int amount;
  final String proofNote;
  final String status;
  final String? proofImagePath;
  final DateTime? submittedAt;
  final DateTime? approvedAt;

  factory MembershipPaymentModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return MembershipPaymentModel(
      id: doc.id,
      businessId: data['businessId'] as String? ?? '',
      tier: data['tier'] as String? ?? '',
      amount: data['amount'] as int? ?? 0,
      proofNote: data['proofNote'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      proofImagePath: data['proofImagePath'] as String?,
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
    );
  }
}
