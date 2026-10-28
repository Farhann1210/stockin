import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants.dart';
import '../../models/business_model.dart';
import '../../services/membership_service.dart';
import '../common.dart';

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key, required this.business});
  final BusinessModel business;

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  String _tier = membershipTiers.first.id;
  final _proof = TextEditingController();
  Uint8List? _proofImageBytes;
  String? _proofImageContentType;
  bool _busy = false;

  @override
  void dispose() {
    _proof.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_proof.text.trim().isEmpty && _proofImageBytes == null) {
      showAppMessage(
        context,
        'Tambahkan catatan atau gambar bukti pembayaran.',
        error: true,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await MembershipService().submitPayment(
        businessId: widget.business.id,
        tier: _tier,
        proofNote: _proof.text,
        proofImageBytes: _proofImageBytes,
        proofImageContentType: _proofImageContentType,
      );
      if (mounted) {
        showAppMessage(context, 'Pengajuan pembayaran berhasil dikirim.');
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) showAppMessage(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickProofImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      if (bytes.length > maxMembershipProofImageBytes) {
        showAppMessage(
          context,
          'Ukuran gambar bukti maksimal 5 MB.',
          error: true,
        );
        return;
      }
      setState(() {
        _proofImageBytes = bytes;
        _proofImageContentType = image.mimeType ?? 'image/jpeg';
      });
    } catch (error) {
      if (mounted) {
        showAppMessage(
          context,
          'Gagal memilih gambar bukti: $error',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = membershipTiers.firstWhere((tier) => tier.id == _tier);
    return Scaffold(
      appBar: AppBar(title: const Text('Membership')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('Status saat ini'),
              subtitle: Text(
                '${widget.business.membershipStatus.toUpperCase()}'
                ' · Paket ${widget.business.membershipTier}'
                '${widget.business.membershipStatus == 'active' && widget.business.membershipEndDate != null ? ' · Aktif s.d. ${formatMembershipEndDate(widget.business.membershipEndDate!)}' : ''}',
              ),
            ),
          ),
          RadioGroup<String>(
            groupValue: _tier,
            onChanged: (value) {
              if (value != null) setState(() => _tier = value);
            },
            child: Column(
              children: [
                for (final tier in membershipTiers)
                  Card(
                    child: RadioListTile<String>(
                      value: tier.id,
                      title: Text(
                        '${formatRupiah(tier.price)} / ${tier.durationLabel}',
                      ),
                      subtitle: Text(
                        'Maks. ${tier.cashierLimit} akun kasir dan '
                        '${tier.stockLimit} akun manajemen stok',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _proof,
            maxLength: 300,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Nomor referensi / catatan transfer (opsional)',
              hintText: 'Contoh: transfer BCA atas nama ...',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickProofImage,
            icon: const Icon(Icons.image_outlined),
            label: Text(
              _proofImageBytes == null ? 'Tambah gambar bukti' : 'Ganti gambar',
            ),
          ),
          if (_proofImageBytes case final imageBytes?) ...[
            const SizedBox(height: 12),
            Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    imageBytes,
                    height: 190,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Hapus gambar bukti',
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _proofImageBytes = null;
                          _proofImageContentType = null;
                        }),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Sertakan gambar bukti atau catatan transfer. Pembayaran diproses '
            'manual dan membership aktif setelah pengelola menyetujuinya.',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const CircularProgressIndicator()
                : Text(
                    'Kirim pengajuan ${formatRupiah(selected.price)} '
                    '/ ${selected.durationLabel}',
                  ),
          ),
        ],
      ),
    );
  }
}
