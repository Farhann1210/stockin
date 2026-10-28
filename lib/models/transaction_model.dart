import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionItem {
  const TransactionItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.price,
  });

  final String productId;
  final String name;
  final int qty;
  final double price;

  double get subtotal => qty * price;

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'name': name,
    'qty': qty,
    'price': price,
    'subtotal': subtotal,
  };
}

class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.cashierId,
    required this.cashierName,
    required this.totalAmount,
    required this.paymentMethod,
    required this.items,
    this.createdAt,
  });

  final String id;
  final String cashierId;
  final String cashierName;
  final double totalAmount;
  final String paymentMethod;
  final List<TransactionItem> items;
  final DateTime? createdAt;

  factory TransactionModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TransactionModel(
      id: doc.id,
      cashierId: data['cashierId'] as String? ?? '',
      cashierName:
          data['cashierName'] as String? ?? data['cashierId'] as String? ?? '',
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      paymentMethod: data['paymentMethod'] as String? ?? 'cash',
      items: (data['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => TransactionItem(
              productId: item['productId'] as String? ?? '',
              name: item['name'] as String? ?? '',
              qty: item['qty'] as int? ?? 0,
              price: (item['price'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
