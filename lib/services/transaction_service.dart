import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../models/product_model.dart';
import '../models/transaction_model.dart';

class TransactionService {
  TransactionService([FirebaseFirestore? firestore])
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final _uuid = const Uuid();

  Future<void> completeSale({
    required String businessId,
    required String cashierId,
    required String cashierName,
    required List<TransactionItem> items,
    required String paymentMethod,
  }) async {
    if (items.isEmpty) throw StateError('Keranjang masih kosong.');
    final transactionId = _uuid.v4();
    final transactionRef = _db
        .collection(transactionsCollection)
        .doc(transactionId);
    final productRefs = items
        .map((item) => _db.collection(productsCollection).doc(item.productId))
        .toSet()
        .toList();
    await _db.runTransaction((transaction) async {
      final snapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final ref in productRefs) {
        snapshots[ref.id] = await transaction.get(ref);
      }
      for (final item in items) {
        final productDoc = snapshots[item.productId];
        if (productDoc == null || !productDoc.exists) {
          throw StateError('Produk ${item.name} tidak ditemukan.');
        }
        final product = ProductModel.fromDocument(productDoc);
        if (product.businessId != businessId) {
          throw StateError('Produk tidak berasal dari usaha ini.');
        }
        if (product.stock < item.qty) {
          throw StateError('Stok ${product.name} tidak mencukupi.');
        }
        transaction.update(productDoc.reference, {
          'stock': product.stock - item.qty,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastTransactionId': transactionId,
        });
      }
      transaction.set(transactionRef, {
        'businessId': businessId,
        'cashierId': cashierId,
        'cashierName': cashierName.trim(),
        'items': items.map((item) => item.toMap()).toList(),
        'stockChanges': {for (final item in items) item.productId: item.qty},
        'totalAmount': items.fold<double>(
          0,
          (amount, item) => amount + item.subtotal,
        ),
        'paymentMethod': paymentMethod,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<List<TransactionModel>> watchTransactions(
    String businessId, {
    String? cashierId,
  }) {
    var query = _db
        .collection(transactionsCollection)
        .where('businessId', isEqualTo: businessId);
    if (cashierId != null) {
      query = query.where('cashierId', isEqualTo: cashierId);
    }
    return query.snapshots().map((snapshot) {
      final items = snapshot.docs.map(TransactionModel.fromDocument).toList();
      items.sort(
        (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
          a.createdAt ?? DateTime(1970),
        ),
      );
      return items;
    });
  }
}
