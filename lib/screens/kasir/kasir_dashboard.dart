import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../common.dart';
import '../profile_screen.dart';
import 'checkout_screen.dart';

class KasirDashboard extends StatelessWidget {
  const KasirDashboard({
    super.key,
    required this.profile,
    this.auditUserId,
    this.ownerMode = false,
  });
  final UserModel profile;
  final String? auditUserId;
  final bool ownerMode;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(ownerMode ? 'Kasir' : 'Kasir Stockin'),
      actions: [
        if (!ownerMode) ...[
          IconButton(
            tooltip: 'Profil',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ProfileScreen(profile: profile),
              ),
            ),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          IconButton(
            onPressed: () =>
                confirmSignOut(context, context.read<AuthProvider>().logout),
            icon: const Icon(Icons.logout),
          ),
        ],
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Halo, ${profile.name}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        if (ownerMode)
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Fitur Kasir untuk Owner'),
              subtitle: Text('Transaksi akan tercatat atas nama Owner.'),
            ),
          ),
        _TodaySummary(profile: profile, cashierId: auditUserId ?? profile.id),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  CheckoutScreen(profile: profile, auditUserId: auditUserId),
            ),
          ),
          icon: const Icon(Icons.point_of_sale),
          label: const Text('Mulai Transaksi'),
        ),
      ],
    ),
  );
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.profile, required this.cashierId});
  final UserModel profile;
  final String cashierId;

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: FirebaseFirestore.instance
        .collection(transactionsCollection)
        .where('businessId', isEqualTo: profile.businessId)
        .where('cashierId', isEqualTo: cashierId)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Card(
          child: ListTile(
            title: Text('Gagal memuat transaksi: ${snapshot.error}'),
          ),
        );
      }
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final docs = snapshot.data?.docs ?? [];
      final today = docs.where((doc) {
        final date = (doc.data()['createdAt'] as Timestamp?)?.toDate();
        return date != null && !date.isBefore(midnight);
      }).toList();
      final total = today.fold<double>(
        0,
        (amount, doc) =>
            amount + ((doc.data()['totalAmount'] as num?)?.toDouble() ?? 0),
      );
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text('Transaksi hari ini'),
              Text(
                '${today.length}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text('Total ${formatRupiah(total)}'),
            ],
          ),
        ),
      );
    },
  );
}
