import 'package:flutter/material.dart';

import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../services/product_service.dart';
import '../../services/stock_service.dart';
import '../barcode_scanner_screen.dart';
import '../common.dart';

class ScanStokScreen extends StatefulWidget {
  const ScanStokScreen({super.key, required this.profile});
  final UserModel profile;

  @override
  State<ScanStokScreen> createState() => _ScanStokScreenState();
}

class _ScanStokScreenState extends State<ScanStokScreen> {
  final _barcode = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _note = TextEditingController();
  ProductModel? _product;
  String _type = 'in';
  bool _busy = false;

  @override
  void dispose() {
    _barcode.dispose();
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _lookup(String code) async {
    try {
      final product = await ProductService().findByBarcode(
        widget.profile.businessId,
        code.trim(),
      );
      if (!mounted) return;
      setState(() {
        _product = product;
        _barcode.text = code;
      });
      if (product == null) {
        showAppMessage(context, 'Barcode tidak ditemukan.', error: true);
      }
    } catch (error) {
      if (mounted) showAppMessage(context, error.toString(), error: true);
    }
  }

  Future<void> _save() async {
    final product = _product;
    final qty = int.tryParse(_quantity.text);
    if (product == null) {
      showAppMessage(
        context,
        'Pilih produk dengan memindai barcode.',
        error: true,
      );
      return;
    }
    if (qty == null || qty <= 0) {
      showAppMessage(context, 'Jumlah harus lebih dari nol.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await StockService().adjustStock(
        product: product,
        userId: widget.profile.id,
        type: _type,
        quantity: qty,
        note: _note.text,
      );
      if (mounted) {
        showAppMessage(context, 'Perubahan stok berhasil disimpan.');
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) showAppMessage(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan Perubahan Stok')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _barcode,
                decoration: const InputDecoration(labelText: 'Barcode produk'),
                onSubmitted: _lookup,
              ),
            ),
            IconButton.filledTonal(
              onPressed: () async {
                final code = await Navigator.push<String>(
                  context,
                  MaterialPageRoute<String>(
                    builder: (_) => const BarcodeScannerScreen(),
                  ),
                );
                if (code != null) await _lookup(code);
              },
              icon: const Icon(Icons.camera_alt),
            ),
          ],
        ),
        if (_product != null)
          Card(
            child: ListTile(
              title: Text(_product!.name),
              subtitle: Text(
                'Stok saat ini: ${_product!.stock} pcs'
                '${_product!.unit == 'dus' ? ' (${_product!.piecesPerPack} pcs/dus)' : ''}',
              ),
            ),
          ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'in',
              label: Text('Stok Masuk'),
              icon: Icon(Icons.add),
            ),
            ButtonSegment(
              value: 'out',
              label: Text('Stok Keluar'),
              icon: Icon(Icons.remove),
            ),
          ],
          selected: {_type},
          onSelectionChanged: (selection) =>
              setState(() => _type = selection.first),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _quantity,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Jumlah ${_product?.unit == 'dus' ? '(dus)' : '(pcs)'}',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          maxLength: 300,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const CircularProgressIndicator()
              : const Text('Simpan Perubahan Stok'),
        ),
      ],
    ),
  );
}
