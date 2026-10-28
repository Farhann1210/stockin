import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../models/business_model.dart';

class BusinessService {
  BusinessService([FirebaseFirestore? firestore])
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<BusinessModel> watchBusiness(String businessId) => _db
      .collection(businessesCollection)
      .doc(businessId)
      .snapshots()
      .where((doc) => doc.exists)
      .map((doc) => BusinessModel.fromMap(doc.id, doc.data()!));
}
