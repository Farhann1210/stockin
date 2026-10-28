import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../models/user_model.dart';

class UserService {
  UserService([FirebaseFirestore? firestore])
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<UserModel>> watchEmployees(String businessId) => _db
      .collection(usersCollection)
      .where('businessId', isEqualTo: businessId)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(UserModel.fromDocument)
            .where((user) => user.role != roleOwner)
            .toList(),
      );

  Future<void> addEmployee({
    required String uid,
    required String businessId,
    required String name,
    required String role,
  }) async {
    if (role != roleCashier && role != roleStock) {
      throw ArgumentError.value(role, 'role', 'Role karyawan tidak valid.');
    }
    final businessRef = _db.collection(businessesCollection).doc(businessId);
    final userRef = _db.collection(usersCollection).doc(uid);
    await _db.runTransaction((transaction) async {
      final businessDoc = await transaction.get(businessRef);
      if (!businessDoc.exists) throw StateError('Data usaha tidak ditemukan.');
      final business = businessDoc.data()!;
      if (business['membershipStatus'] != 'active') {
        throw StateError('Membership usaha harus aktif untuk menambah akun.');
      }
      final countField = role == roleCashier
          ? 'activeKasirAccounts'
          : 'activeStokAccounts';
      final limitField = role == roleCashier
          ? 'maxKasirAccounts'
          : 'maxStokAccounts';
      final count = business[countField] as int? ?? 0;
      final limit = business[limitField] as int? ?? 0;
      if (count >= limit) {
        throw StateError(
          'Limit akun ${role == roleCashier ? 'kasir' : 'stok'} '
          'tercapai. Silakan upgrade membership.',
        );
      }
      transaction.set(userRef, {
        'businessId': businessId,
        'name': name.trim(),
        'role': role,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(businessRef, {
        countField: count + 1,
        'seatChangeUid': uid,
      });
    });
  }

  Future<void> setEmployeeActive({
    required UserModel employee,
    required bool isActive,
  }) async {
    if (employee.isActive == isActive) return;
    final businessRef = _db
        .collection(businessesCollection)
        .doc(employee.businessId);
    final userRef = _db.collection(usersCollection).doc(employee.id);
    await _db.runTransaction((transaction) async {
      final businessDoc = await transaction.get(businessRef);
      final userDoc = await transaction.get(userRef);
      if (!businessDoc.exists || !userDoc.exists) {
        throw StateError('Data karyawan atau usaha tidak ditemukan.');
      }
      final business = businessDoc.data()!;
      final countField = employee.role == roleCashier
          ? 'activeKasirAccounts'
          : 'activeStokAccounts';
      final limitField = employee.role == roleCashier
          ? 'maxKasirAccounts'
          : 'maxStokAccounts';
      final count = business[countField] as int? ?? 0;
      final limit = business[limitField] as int? ?? 0;
      final delta = isActive ? 1 : -1;
      if (isActive && business['membershipStatus'] != 'active') {
        throw StateError(
          'Membership usaha harus aktif untuk mengaktifkan akun.',
        );
      }
      if (isActive && count >= limit) {
        throw StateError('Limit akun tercapai. Silakan upgrade membership.');
      }
      transaction.update(userRef, {'isActive': isActive});
      transaction.update(businessRef, {
        countField: count + delta,
        'seatChangeUid': employee.id,
      });
    });
  }
}
