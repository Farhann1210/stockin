import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.businessId,
    required this.name,
    required this.role,
    required this.isActive,
    this.isBanned = false,
    this.email,
  });

  final String id;
  final String businessId;
  final String name;
  final String role;
  final bool isActive;
  final bool isBanned;
  final String? email;

  factory UserModel.fromMap(String id, Map<String, dynamic> data) {
    return UserModel(
      id: id,
      businessId: data['businessId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      role: data['role'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? false,
      isBanned: data['isBanned'] as bool? ?? false,
      email: data['email'] as String?,
    );
  }

  factory UserModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) =>
      UserModel.fromMap(doc.id, doc.data() ?? const {});
}
