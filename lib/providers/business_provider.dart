import 'package:flutter/foundation.dart';

import '../models/business_model.dart';
import '../services/business_service.dart';

class BusinessProvider extends ChangeNotifier {
  final BusinessService _service = BusinessService();
  BusinessModel? business;

  void watch(String businessId) {
    _service.watchBusiness(businessId).listen((value) {
      business = value;
      notifyListeners();
    });
  }
}
