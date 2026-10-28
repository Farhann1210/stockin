import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  const ProductModel({
    required this.id,
    required this.businessId,
    required this.barcode,
    required this.name,
    required this.price,
    required this.costPrice,
    required this.stock,
    required this.unit,
    this.piecesPerPack = 1,
    required this.category,
    required this.minStock,
  });

  final String id;
  final String businessId;
  final String barcode;
  final String name;
  final double price;
  final double costPrice;
  final int stock;
  final String unit;
  final int piecesPerPack;
  final String category;
  final int minStock;

  factory ProductModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ProductModel(
      id: doc.id,
      businessId: data['businessId'] as String? ?? '',
      barcode: data['barcode'] as String? ?? '',
      name: data['name'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      costPrice: (data['costPrice'] as num?)?.toDouble() ?? 0,
      stock: data['stock'] as int? ?? 0,
      unit: data['unit'] as String? ?? 'pcs',
      piecesPerPack: data['piecesPerPack'] as int? ?? 1,
      category: data['category'] as String? ?? '',
      minStock: data['minStock'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'businessId': businessId,
    'barcode': barcode,
    'name': name,
    'price': price,
    'costPrice': costPrice,
    'stock': stock,
    'unit': unit,
    'piecesPerPack': piecesPerPack,
    'category': category,
    'minStock': minStock,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
