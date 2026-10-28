import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../models/product_model.dart';
import '../models/stock_log_model.dart';

class StockService {
  StockService([FirebaseFirestore? firestore])
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final _uuid = const Uuid();

  Future<void> adjustStock({
    required ProductModel product,
    required String userId,
    required String type,
    required int quantity,
    required String note,
  }) async {
    if (quantity <= 0) throw ArgumentError.value(quantity, 'quantity');
    if (type != 'in' && type != 'out') {
      throw ArgumentError.value(type, 'type');
    }
    final quantityInPieces = convertStockToPieces(
      quantity: quantity,
      unit: product.unit,
      piecesPerPack: product.piecesPerPack,
    );
    final productRef = _db.collection(productsCollection).doc(product.id);
    final logRef = _db.collection(stockLogsCollection).doc(_uuid.v4());
    await _db.runTransaction((transaction) async {
      final doc = await transaction.get(productRef);
      if (!doc.exists) throw StateError('Produk tidak ditemukan.');
      final current = ProductModel.fromDocument(doc);
      if (current.businessId != product.businessId) {
        throw StateError('Produk tidak berasal dari usaha ini.');
      }
      if (current.unit != product.unit ||
          current.piecesPerPack != product.piecesPerPack) {
        throw StateError('Satuan produk berubah. Pindai ulang produk.');
      }
      final newStock =
          current.stock + (type == 'in' ? quantityInPieces : -quantityInPieces);
      if (newStock < 0) throw StateError('Stok tidak boleh kurang dari nol.');
      transaction.update(productRef, {
        'stock': newStock,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastStockLogId': logRef.id,
      });
      transaction.set(logRef, {
        'businessId': current.businessId,
        'productId': current.id,
        'userId': userId,
        'type': type,
        'quantity': quantityInPieces,
        'note': note.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<List<StockLogModel>> watchLogs(String businessId) => _db
      .collection(stockLogsCollection)
      .where('businessId', isEqualTo: businessId)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map(StockLogModel.fromDocument).toList(),
      );
}
