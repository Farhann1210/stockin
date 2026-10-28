import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../models/business_model.dart';
import '../../models/membership_payment_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/membership_admin_service.dart';
import '../common.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key, required this.profile});

  final UserModel profile;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Admin Stockin'),
      actions: [
        IconButton(
          tooltip: 'Keluar',
          onPressed: () =>
              confirmSignOut(context, context.read<AuthProvider>().logout),
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(membershipPaymentsCollection)
          .snapshots(),
      builder: (context, paymentSnapshot) {
        if (paymentSnapshot.hasError) {
          return _LoadError(
            message: 'Gagal memuat pengajuan: ${paymentSnapshot.error}',
          );
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(businessesCollection)
              .snapshots(),
          builder: (context, businessSnapshot) {
            if (businessSnapshot.hasError) {
              return _LoadError(
                message: 'Gagal memuat usaha: ${businessSnapshot.error}',
              );
            }
            if (!paymentSnapshot.hasData || !businessSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final payments =
                paymentSnapshot.data!.docs
                    .map(MembershipPaymentModel.fromDocument)
                    .toList()
                  ..sort(
                    (a, b) => (b.submittedAt ?? DateTime(1970)).compareTo(
                      a.submittedAt ?? DateTime(1970),
                    ),
                  );
            final businesses =
                businessSnapshot.data!.docs
                    .map((doc) => BusinessModel.fromMap(doc.id, doc.data()))
                    .toList()
                  ..sort((a, b) => a.name.compareTo(b.name));
            final pending = payments
                .where((payment) => payment.status == 'pending')
                .toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Halo, ${profile.name}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Kelola pengajuan dan status membership semua usaha.',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Total Usaha',
                        value: '${businesses.length}',
                        icon: Icons.storefront,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Menunggu',
                        value: '${pending.length}',
                        icon: Icons.pending_actions,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Pengajuan Membership',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (pending.isEmpty)
                  const Card(
                    child: ListTile(
                      title: Text('Tidak ada pengajuan yang menunggu.'),
                    ),
                  ),
                for (final payment in pending) _PaymentCard(payment: payment),
                const SizedBox(height: 24),
                Text(
                  'Semua Usaha',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (businesses.isEmpty)
                  const Card(
                    child: ListTile(title: Text('Belum ada usaha terdaftar.')),
                  ),
                for (final business in businesses)
                  _BusinessCard(business: business),
              ],
            );
          },
        );
      },
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ],
      ),
    ),
  );
}

class _PaymentCard extends StatefulWidget {
  const _PaymentCard({required this.payment});
  final MembershipPaymentModel payment;

  @override
  State<_PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<_PaymentCard> {
  bool _busy = false;

  Future<void> _setApproved(bool approve) async {
    setState(() => _busy = true);
    try {
      await MembershipAdminService().reviewPayment(
        payment: widget.payment,
        approve: approve,
      );
      if (mounted) {
        showAppMessage(
          context,
          approve ? 'Membership berhasil diaktifkan.' : 'Pengajuan ditolak.',
        );
      }
    } catch (error) {
      if (mounted) showAppMessage(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection(businessesCollection)
                .doc(widget.payment.businessId)
                .snapshots(),
            builder: (context, snapshot) {
              final businessName =
                  snapshot.data?.data()?['name'] as String? ??
                  widget.payment.businessId;
              return Text(
                businessName,
                style: Theme.of(context).textTheme.titleMedium,
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            'Paket ${widget.payment.tier} · '
            '${formatRupiah(widget.payment.amount)} · '
            '${membershipDurationLabel(widget.payment.tier)}',
          ),
          if (widget.payment.proofNote.isNotEmpty)
            Text('Catatan bukti: ${widget.payment.proofNote}'),
          if (widget.payment.proofImagePath != null) ...[
            const SizedBox(height: 10),
            _PaymentProofImage(path: widget.payment.proofImagePath!),
          ],
          if (widget.payment.submittedAt != null)
            Text(
              'Diajukan: ${DateFormatters.dateTime(widget.payment.submittedAt!)}',
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: _busy ? null : () => _setApproved(false),
                child: const Text('Tolak'),
              ),
              FilledButton(
                onPressed: _busy ? null : () => _setApproved(true),
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Setujui & Aktifkan sesuai paket'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _PaymentProofImage extends StatelessWidget {
  const _PaymentProofImage({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: FirebaseStorage.instance
        .ref(path)
        .getData(maxMembershipProofImageBytes),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Text('Gagal memuat gambar bukti: ${snapshot.error}');
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final bytes = snapshot.data;
      if (bytes == null) return const Text('Gambar bukti tidak ditemukan.');
      return InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => Dialog(
            child: InteractiveViewer(
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      );
    },
  );
}

class _BusinessCard extends StatefulWidget {
  const _BusinessCard({required this.business});
  final BusinessModel business;

  @override
  State<_BusinessCard> createState() => _BusinessCardState();
}

class _BusinessCardState extends State<_BusinessCard> {
  bool _busy = false;

  Future<void> _changeStatus() async {
    final status = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Ubah status membership'),
        children: [
          for (final value in const ['inactive', 'expired'])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value),
              child: Text(
                value == 'inactive' ? 'Nonaktifkan' : 'Tandai kedaluwarsa',
              ),
            ),
        ],
      ),
    );
    if (status == null) return;
    setState(() => _busy = true);
    try {
      await MembershipAdminService().setMembershipStatus(
        business: widget.business,
        status: status,
      );
      if (mounted) {
        showAppMessage(context, 'Status membership diperbarui.');
      }
    } catch (error) {
      if (mounted) showAppMessage(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deletePermanently() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus usaha secara permanen?'),
        content: const Text(
          'Semua data Firestore usaha ini akan dihapus: produk, transaksi, '
          'riwayat stok, dan pengajuan membership. Data profil owner dan '
          'karyawan tetap disimpan serta dibanned agar akun tidak dapat '
          'digunakan untuk login kembali. Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus permanen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await MembershipAdminService().deleteBusiness(widget.business);
      if (mounted) {
        showAppMessage(
          context,
          'Usaha berhasil dihapus. Profil pengguna tetap tersimpan dan dibanned.',
        );
      }
    } catch (error) {
      if (mounted) {
        showAppMessage(
          context,
          'Penghapusan belum selesai. Usaha tetap terkunci; coba hapus lagi. $error',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(widget.business.name),
      subtitle: Text(
        '${widget.business.isDeleting ? 'PENGHAPUSAN TERTUNDA · ' : ''}'
        '${widget.business.membershipStatus.toUpperCase()} · '
        'Paket ${widget.business.membershipTier} · '
        '${widget.business.membershipEndDate == null ? '' : 'Aktif s.d. ${formatMembershipEndDate(widget.business.membershipEndDate!)} · '}'
        'Kasir ${widget.business.activeKasirAccounts}/${widget.business.maxKasirAccounts} · '
        'Stok ${widget.business.activeStokAccounts}/${widget.business.maxStokAccounts}',
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        enabled: !_busy,
        tooltip: 'Kelola usaha',
        onSelected: (value) {
          if (value == 'change') _changeStatus();
          if (value == 'delete') _deletePermanently();
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'change',
            child: Text('Ubah status membership'),
          ),
          if (widget.business.isDeleting)
            const PopupMenuItem(
              value: 'delete',
              child: Text('Lanjutkan penghapusan'),
            )
          else
            const PopupMenuItem(
              value: 'delete',
              child: Text('Hapus usaha permanen'),
            ),
        ],
      ),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

class DateFormatters {
  static String dateTime(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
