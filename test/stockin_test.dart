import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:stockin/core/constants.dart';
import 'package:stockin/models/user_model.dart';
import 'package:stockin/screens/auth/login_screen.dart';
import 'package:stockin/screens/common.dart';
import 'package:stockin/screens/onboarding_screen.dart';

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

  testWidgets('onboarding has five screens and completes from the last one', (
    tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          onComplete: () async {
            completed = true;
          },
        ),
      ),
    );

    expect(find.text('Kenali Stockin'), findsOneWidget);
    for (var page = 0; page < 4; page++) {
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Mulai bersama Stockin'), findsOneWidget);
    await tester.tap(find.text('Mulai'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
  });

  testWidgets('login can reopen onboarding and return to login', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Logo Stockin'), findsOneWidget);
    await tester.tap(find.text('On Boarding'));
    await tester.pumpAndSettle();
    expect(find.text('Kenali Stockin'), findsOneWidget);

    await tester.tap(find.text('Lewati'));
    await tester.pumpAndSettle();
    expect(find.text('Masuk'), findsOneWidget);
  });
}
