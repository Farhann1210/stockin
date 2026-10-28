import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/user_model.dart';
import '../services/support_service.dart';
import 'common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.profile});

  final UserModel profile;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _feedbackController = TextEditingController();
  bool _feedbackBusy = false;
  bool _deletionBusy = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  String get _roleLabel => switch (widget.profile.role) {
    roleOwner => 'Owner',
    roleCashier => 'Kasir',
    roleStock => 'Staf Stok',
    roleAdmin => 'Admin',
    _ => widget.profile.role,
  };

  Future<void> _submitFeedback() async {
    final message = _feedbackController.text.trim();
    if (message.isEmpty) {
      showAppMessage(context, 'Tulis masukan terlebih dahulu.', error: true);
      return;
    }
    if (message.length > 2000) {
      showAppMessage(context, 'Masukan maksimal 2.000 karakter.', error: true);
      return;
    }
    setState(() => _feedbackBusy = true);
    try {
      await SupportService().submitFeedback(
        profile: widget.profile,
        message: message,
      );
      if (mounted) {
        _feedbackController.clear();
        showAppMessage(context, 'Masukan berhasil dikirim.');
      }
    } catch (error) {
      if (mounted) showAppMessage(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _feedbackBusy = false);
    }
  }

  Future<void> _requestDeletion() async {
    final isOwner = widget.profile.role == roleOwner;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isOwner ? 'Ajukan penghapusan usaha?' : 'Hapus akun?'),
        content: Text(
          isOwner
              ? 'Permintaan akan dikirim ke Admin Stockin. Jika disetujui, '
                    'data usaha, produk, transaksi, riwayat stok, dan '
                    'membership akan dihapus serta profil pengguna diblokir. '
                    'Identitas Firebase Auth tetap disimpan dan tidak dapat '
                    'digunakan selama profil diblokir.'
              : 'Permintaan akan dikirim ke Admin Stockin untuk diproses. '
                    'Akun tidak langsung dihapus saat ini. Admin perlu '
                    'menghapus identitas Firebase Auth secara manual.',
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
            child: const Text('Kirim permintaan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deletionBusy = true);
    try {
      await SupportService().requestAccountDeletion(profile: widget.profile);
      if (mounted) {
        showAppMessage(
          context,
          'Permintaan penghapusan berhasil dikirim ke Admin Stockin.',
        );
      }
    } catch (error) {
      if (mounted) showAppMessage(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _deletionBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'Tidak tersedia';
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    child: Text(
                      widget.profile.name.isEmpty
                          ? '?'
                          : widget.profile.name[0].toUpperCase(),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.profile.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(_roleLabel),
                  const Divider(height: 28),
                  _ProfileDetail(label: 'Email', value: email),
                  _ProfileDetail(
                    label: 'ID usaha',
                    value: widget.profile.businessId,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Kirim Feedback',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _feedbackController,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      hintText: 'Bagikan masukan atau kendala Anda',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _feedbackBusy ? null : _submitFeedback,
                    icon: const Icon(Icons.send_outlined),
                    label: _feedbackBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Kirim feedback'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('Hapus akun'),
              subtitle: Text(
                widget.profile.role == roleOwner
                    ? 'Ajukan penghapusan bisnis dan data ke Admin'
                    : 'Ajukan penghapusan akun ke Admin',
              ),
              trailing: _deletionBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _deletionBusy ? null : _requestDeletion,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );
}
