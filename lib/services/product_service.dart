import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../models/product_model.dart';

class ProductService {
  ProductService([FirebaseFirestore? firestore])
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection(productsCollection);

  Stream<List<ProductModel>> watchProducts(String businessId) => _products
      .where('businessId', isEqualTo: businessId)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(ProductModel.fromDocument).toList());

  Future<ProductModel?> findByBarcode(String businessId, String barcode) async {
    final result = await _products
        .where('businessId', isEqualTo: businessId)
        .where('barcode', isEqualTo: barcode)
        .limit(1)
        .get();
    return result.docs.isEmpty
        ? null
        : ProductModel.fromDocument(result.docs.first);
  }

  Future<void> saveProduct({
    String? id,
    required String businessId,
    required String name,
    required String barcode,
    required double price,
    required double costPrice,
    required int stock,
    required int minStock,
    required String unit,
    required int piecesPerPack,
    required String category,
  }) async {
    if (unit != 'pcs' && unit != 'dus') {
      throw ArgumentError.value(unit, 'unit');
    }
    if (unit == 'pcs' && piecesPerPack != 1) {
      throw ArgumentError.value(piecesPerPack, 'piecesPerPack');
    }
    if (unit == 'dus' && (piecesPerPack < 1 || piecesPerPack > 100000)) {
      throw ArgumentError.value(piecesPerPack, 'piecesPerPack');
    }
    final stockInPieces = id == null
        ? convertStockToPieces(
            quantity: stock,
            unit: unit,
            piecesPerPack: piecesPerPack,
          )
        : stock;
    final duplicate = await findByBarcode(businessId, barcode.trim());
    if (duplicate != null && duplicate.id != id) {
      throw StateError('Barcode sudah digunakan oleh produk lain.');
    }
    final docId = id ?? _uuid.v4();
    final ref = _products.doc(docId);
    final payload = ProductModel(
      id: docId,
      businessId: businessId,
      barcode: barcode.trim(),
      name: name.trim(),
      price: price,
      costPrice: costPrice,
      stock: stockInPieces,
      unit: unit,
      piecesPerPack: unit == 'dus' ? piecesPerPack : 1,
      category: category.trim(),
      minStock: minStock,
    ).toMap();
    if (id == null) {
      payload['createdAt'] = FieldValue.serverTimestamp();
      await ref.set(payload);
    } else {
      await ref.update(payload);
    }
  }
}
