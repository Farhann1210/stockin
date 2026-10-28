import 'package:cloud_firestore/cloud_firestore.dart';

class SupportRequestModel {
  const SupportRequestModel({
    required this.id,
    required this.requestType,
    required this.userId,
    required this.businessId,
    required this.role,
    required this.status,
    required this.message,
    this.email,
    this.createdAt,
  });

  final String id;
  final String requestType;
  final String userId;
  final String businessId;
  final String role;
  final String status;
  final String message;
  final String? email;
  final DateTime? createdAt;

  factory SupportRequestModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return SupportRequestModel(
      id: document.id,
      requestType: data['requestType'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      businessId: data['businessId'] as String? ?? '',
      role: data['role'] as String? ?? '',
      status: data['status'] as String? ?? '',
      message: data['message'] as String? ?? '',
      email: data['email'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
