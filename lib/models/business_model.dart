import 'package:cloud_firestore/cloud_firestore.dart';

class BusinessModel {
  const BusinessModel({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.membershipTier,
    required this.maxKasirAccounts,
    required this.maxStokAccounts,
    required this.activeKasirAccounts,
    required this.activeStokAccounts,
    required this.membershipStatus,
    this.isDeleting = false,
    this.seatChangeUid,
    this.pendingPaymentId,
    this.membershipStartDate,
    this.membershipEndDate,
  });

  final String id;
  final String name;
  final String ownerId;
  final String membershipTier;
  final int maxKasirAccounts;
  final int maxStokAccounts;
  final int activeKasirAccounts;
  final int activeStokAccounts;
  final String membershipStatus;
  final bool isDeleting;
  final String? seatChangeUid;
  final String? pendingPaymentId;
  final DateTime? membershipStartDate;
  final DateTime? membershipEndDate;

  factory BusinessModel.fromMap(String id, Map<String, dynamic> data) {
    return BusinessModel(
      id: id,
      name: data['name'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      membershipTier: data['membershipTier'] as String? ?? 'none',
      maxKasirAccounts: data['maxKasirAccounts'] as int? ?? 0,
      maxStokAccounts: data['maxStokAccounts'] as int? ?? 0,
      activeKasirAccounts: data['activeKasirAccounts'] as int? ?? 0,
      activeStokAccounts: data['activeStokAccounts'] as int? ?? 0,
      membershipStatus: data['membershipStatus'] as String? ?? 'inactive',
      isDeleting: data['isDeleting'] as bool? ?? false,
      seatChangeUid: data['seatChangeUid'] as String?,
      pendingPaymentId: data['pendingPaymentId'] as String?,
      membershipStartDate: (data['membershipStartDate'] as Timestamp?)
          ?.toDate(),
      membershipEndDate: (data['membershipEndDate'] as Timestamp?)?.toDate(),
    );
  }
}
