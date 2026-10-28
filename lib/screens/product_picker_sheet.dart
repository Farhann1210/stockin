import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../services/product_service.dart';
import 'barcode_scanner_screen.dart';
import 'common.dart';

Future<ProductModel?> showProductPicker(
  BuildContext context, {
  required String businessId,
}) => showModalBottomSheet<ProductModel>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => ProductPickerSheet(businessId: businessId),
);

class ProductPickerSheet extends StatefulWidget {
  const ProductPickerSheet({super.key, required this.businessId});

  final String businessId;

  @override
  State<ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<ProductPickerSheet> {
  final _barcode = TextEditingController();
  final _search = TextEditingController();
  bool _lookingUp = false;

  @override
  void dispose() {
    _barcode.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _lookupBarcode() async {
    final barcode = _barcode.text.trim();
    if (barcode.isEmpty || _lookingUp) return;
    setState(() => _lookingUp = true);
    try {
      final product = await ProductService().findByBarcode(
        widget.businessId,
        barcode,
      );
      if (!mounted) return;
      if (product == null) {
        showAppMessage(context, 'Barcode tidak ditemukan.', error: true);
        return;
      }
      Navigator.pop(context, product);
    } catch (error) {
      if (mounted) showAppMessage(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(builder: (_) => const BarcodeScannerScreen()),
    );
    if (barcode == null || !mounted) return;
    _barcode.text = barcode;
    await _lookupBarcode();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pilih Produk',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _scanBarcode,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Column(
                    children: [
                      Icon(Icons.qr_code_scanner, size: 36),
                      SizedBox(height: 8),
                      Text('Pindai barcode dengan kamera'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcode,
                    decoration: const InputDecoration(
                      labelText: 'Input barcode manual',
                      prefixIcon: Icon(Icons.barcode_reader),
                    ),
                    onSubmitted: (_) => _lookupBarcode(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Cari barcode',
                  onPressed: _lookingUp ? null : _lookupBarcode,
                  icon: _lookingUp
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Cari produk',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              'Atau pilih produk dari daftar:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<ProductModel>>(
                stream: ProductService().watchProducts(widget.businessId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Gagal memuat produk: ${snapshot.error}'),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final query = _search.text.trim().toLowerCase();
                  final products = snapshot.data!
                      .where(
                        (product) =>
                            product.name.toLowerCase().contains(query) ||
                            product.barcode.toLowerCase().contains(query),
                      )
                      .toList();
                  if (products.isEmpty) {
                    return const Center(child: Text('Produk tidak ditemukan.'));
                  }
                  return ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return Card(
                        child: ListTile(
                          title: Text(product.name),
                          subtitle: Text('Barcode: ${product.barcode}'),
                          trailing: Text(
                            '${product.stock} pcs',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onTap: () => Navigator.pop(context, product),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
