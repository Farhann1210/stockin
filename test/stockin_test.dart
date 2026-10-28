import 'package:flutter_test/flutter_test.dart';
import 'package:stockin/core/constants.dart';
import 'package:stockin/models/user_model.dart';
import 'package:stockin/screens/common.dart';

void main() {
  test('membership tiers match the published employee seat limits', () {
    expect(membershipTiers.map((tier) => tier.price).toList(), [
      50000,
      250000,
      400000,
    ]);
    expect(membershipTiers.map((tier) => tier.durationMonths).toList(), [
      1,
      6,
      12,
    ]);
    expect(membershipTiers.map((tier) => tier.cashierLimit).toList(), [
      2,
      6,
      20,
    ]);
    expect(membershipTiers.map((tier) => tier.stockLimit).toList(), [2, 6, 20]);
  });

  test('calendar membership renewal handles month-end and leap dates', () {
    expect(addCalendarMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    expect(addCalendarMonths(DateTime(2024, 2, 29), 12), DateTime(2025, 2, 28));
  });

  test('stock entered in dus is stored and adjusted as pieces', () {
    expect(
      convertStockToPieces(quantity: 3, unit: 'dus', piecesPerPack: 12),
      36,
    );
    expect(convertStockToPieces(quantity: 3, unit: 'pcs', piecesPerPack: 1), 3);
    expect(
      () => convertStockToPieces(quantity: 1, unit: 'dus', piecesPerPack: 0),
      throwsArgumentError,
    );
  });

  test('membership end date uses Indonesian abbreviated month names', () {
    expect(formatMembershipEndDate(DateTime(2026, 11, 26)), '26 Nov 2026');
  });

  test('banned status is retained when reading user profiles', () {
    final oldProfile = UserModel.fromMap('user-1', {
      'businessId': 'business-1',
      'name': 'Kasir',
      'role': 'kasir',
      'isActive': true,
    });
    final bannedProfile = UserModel.fromMap('user-2', {
      'businessId': 'business-1',
      'name': 'Owner',
      'role': 'owner',
      'isActive': true,
      'isBanned': true,
    });

    expect(oldProfile.isBanned, isFalse);
    expect(bannedProfile.isBanned, isTrue);
  });
}
