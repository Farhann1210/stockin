import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../models/business_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/business_service.dart';
import '../../services/product_service.dart';
import '../common.dart';
import '../kasir/kasir_dashboard.dart';
import '../stok/stok_dashboard.dart';
import '../owner/manage_employees_screen.dart';
import 'membership_screen.dart';

class OwnerDashboard extends StatelessWidget {
  const OwnerDashboard({super.key, required this.profile});
  final UserModel profile;

  Future<void> _openFeature(
    BuildContext context,
    BusinessModel business,
    WidgetBuilder builder,
  ) async {
    if (business.membershipStatus != 'active') {
      final openMembership = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Membership tidak aktif'),
          content: Text(
            'Fitur ini tidak dapat digunakan karena status membership '
            'usaha Anda ${business.membershipStatus}. Aktifkan membership '
            'terlebih dahulu untuk menggunakan Kasir dan Manajemen Stok.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Nanti'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Lihat Membership'),
            ),
          ],
        ),
      );
      if (openMembership == true && context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => MembershipScreen(business: business),
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      await Navigator.push(context, MaterialPageRoute<void>(builder: builder));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: BusinessService().watchBusiness(profile.businessId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Stockin')),
            body: Center(
              child: Text('Gagal memuat data usaha: ${snapshot.error}'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final business = snapshot.data!;
        return Scaffold(
          appBar: AppBar(
            title: Text(business.name),
            actions: [
              IconButton(
                tooltip: 'Keluar',
                onPressed: () => confirmSignOut(
                  context,
                  context.read<AuthProvider>().logout,
                ),
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Status membership'),
                      const SizedBox(height: 6),
                      Text(
                        business.membershipStatus.toUpperCase(),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (business.membershipTier != 'none')
                        Text('Paket ${business.membershipTier}'),
                      if (business.membershipStatus == 'active' &&
                          business.membershipEndDate != null)
                        Text(
                          'Aktif s.d. ${formatMembershipEndDate(business.membershipEndDate!)}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _TodaySales(businessId: business.id),
              const SizedBox(height: 12),
              _LowStockSummary(businessId: business.id),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Membership',
                subtitle: 'Pilih paket dan kirim bukti pembayaran',
                icon: Icons.workspace_premium,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => MembershipScreen(business: business),
                  ),
                ),
              ),
              SectionCard(
                title: 'Kasir',
                subtitle: 'Buka fitur transaksi penjualan',
                icon: Icons.point_of_sale,
                onTap: () => _openFeature(
                  context,
                  business,
                  (_) => KasirDashboard(
                    profile: profile,
                    auditUserId: profile.id,
                    ownerMode: true,
                  ),
                ),
              ),
              SectionCard(
                title: 'Manajemen Stok',
                subtitle: 'Catat stok masuk, stok keluar, dan lihat log mutasi',
                icon: Icons.swap_vert,
                onTap: () => _openFeature(
                  context,
                  business,
                  (_) => StokDashboard(
                    profile: profile,
                    auditUserId: profile.id,
                    ownerMode: true,
                  ),
                ),
              ),
              SectionCard(
                title: 'Karyawan',
                subtitle:
                    'Kasir ${business.activeKasirAccounts}/${business.maxKasirAccounts} · '
                    'Stok ${business.activeStokAccounts}/${business.maxStokAccounts}',
                icon: Icons.people_alt_outlined,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ManageEmployeesScreen(
                      business: business,
                      owner: profile,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _TodayTransactions(businessId: business.id),
            ],
          ),
        );
      },
    );
  }
}

class _LowStockSummary extends StatelessWidget {
  const _LowStockSummary({required this.businessId});
  final String businessId;

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: ProductService().watchProducts(businessId),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Card(
          child: ListTile(title: Text('Gagal memuat stok: ${snapshot.error}')),
        );
      }
      final count = (snapshot.data ?? [])
          .where((product) => product.stock <= product.minStock)
          .length;
      return Card(
        child: ListTile(
          leading: const Icon(Icons.warning_amber_outlined),
          title: const Text('Produk di bawah stok minimum'),
          trailing: Text('$count'),
        ),
      );
    },
  );
}

class _TodaySales extends StatelessWidget {
  const _TodaySales({required this.businessId});
  final String businessId;

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: FirebaseFirestore.instance
        .collection(transactionsCollection)
        .where('businessId', isEqualTo: businessId)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Card(
          child: ListTile(
            title: Text('Gagal memuat penjualan: ${snapshot.error}'),
          ),
        );
      }
      final start = DateTime.now();
      final startToday = DateTime(start.year, start.month, start.day);
      final sales = (snapshot.data?.docs ?? [])
          .where((doc) {
            final created = (doc.data()['createdAt'] as Timestamp?)?.toDate();
            return created != null && !created.isBefore(startToday);
          })
          .fold<double>(
            0,
            (amount, doc) =>
                amount + ((doc.data()['totalAmount'] as num?)?.toDouble() ?? 0),
          );
      return Card(
        child: ListTile(
          leading: const Icon(Icons.payments_outlined),
          title: const Text('Penjualan hari ini'),
          trailing: Text(
            formatRupiah(sales),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    },
  );
}

class _TodayTransactions extends StatelessWidget {
  const _TodayTransactions({required this.businessId});
  final String businessId;

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: FirebaseFirestore.instance
        .collection(transactionsCollection)
        .where('businessId', isEqualTo: businessId)
        .snapshots(),
    builder: (context, snapshot) {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final today = (snapshot.data?.docs ?? []).where((doc) {
        final timestamp = (doc.data()['createdAt'] as Timestamp?)?.toDate();
        return timestamp != null && !timestamp.isBefore(midnight);
      }).length;
      final docs = [...?snapshot.data?.docs];
      docs.sort((first, second) {
        final firstDate =
            (first.data()['createdAt'] as Timestamp?)?.toDate() ??
            DateTime(1970);
        final secondDate =
            (second.data()['createdAt'] as Timestamp?)?.toDate() ??
            DateTime(1970);
        return secondDate.compareTo(firstDate);
      });
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Transaksi terbaru'),
                trailing: Text('Hari ini: $today'),
              ),
              for (final doc in docs.take(10))
                ListTile(
                  key: ValueKey(doc.id),
                  dense: true,
                  title: Text(
                    formatRupiah(
                      (doc.data()['totalAmount'] as num?)?.toDouble() ?? 0,
                    ),
                  ),
                  subtitle: _CashierTransactionSubtitle(
                    cashierId: doc.data()['cashierId'] as String? ?? '',
                    cashierName: doc.data()['cashierName'] as String? ?? '',
                    dateLabel:
                        (doc.data()['createdAt'] as Timestamp?)
                            ?.toDate()
                            .toString()
                            .substring(0, 16) ??
                        'Baru saja',
                  ),
                ),
              if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Belum ada transaksi.'),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _CashierTransactionSubtitle extends StatefulWidget {
  const _CashierTransactionSubtitle({
    required this.cashierId,
    required this.cashierName,
    required this.dateLabel,
  });

  final String cashierId;
  final String cashierName;
  final String dateLabel;

  @override
  State<_CashierTransactionSubtitle> createState() =>
      _CashierTransactionSubtitleState();
}

class _CashierTransactionSubtitleState
    extends State<_CashierTransactionSubtitle> {
  late Future<String> _cashierName;

  @override
  void initState() {
    super.initState();
    _cashierName = _loadCashierName();
  }

  @override
  void didUpdateWidget(covariant _CashierTransactionSubtitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cashierId != widget.cashierId ||
        oldWidget.cashierName != widget.cashierName) {
      _cashierName = _loadCashierName();
    }
  }

  Future<String> _loadCashierName() async {
    final storedName = widget.cashierName.trim();
    if (storedName.isNotEmpty && storedName != widget.cashierId) {
      return storedName;
    }
    if (widget.cashierId.isEmpty) return 'Kasir';
    final user = await FirebaseFirestore.instance
        .collection(usersCollection)
        .doc(widget.cashierId)
        .get();
    final profileName = user.data()?['name'];
    if (profileName is String && profileName.trim().isNotEmpty) {
      return profileName.trim();
    }
    return 'Kasir';
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _cashierName,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Text('Nama kasir tidak dapat dimuat · ${widget.dateLabel}');
      }
      final name = snapshot.data ?? 'Kasir';
      return Text('$name · ${widget.dateLabel}');
    },
  );
}
