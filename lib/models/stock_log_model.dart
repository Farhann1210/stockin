import 'package:cloud_firestore/cloud_firestore.dart';

class StockLogModel {
  const StockLogModel({
    required this.id,
    required this.businessId,
    required this.productId,
    required this.userId,
    required this.type,
    required this.quantity,
    required this.note,
    this.createdAt,
  });

  final String id;
  final String businessId;
  final String productId;
  final String userId;
  final String type;
  final int quantity;
  final String note;
  final DateTime? createdAt;

  factory StockLogModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return StockLogModel(
      id: doc.id,
      businessId: data['businessId'] as String? ?? '',
      productId: data['productId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      type: data['type'] as String? ?? '',
      quantity: data['quantity'] as int? ?? 0,
      note: data['note'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
