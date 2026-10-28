import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../services/product_service.dart';
import '../barcode_scanner_screen.dart';
import '../common.dart';

class ManageProductsScreen extends StatelessWidget {
  const ManageProductsScreen({super.key, required this.profile});
  final UserModel profile;

  Future<void> _edit(BuildContext context, [ProductModel? product]) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: product?.name ?? '');
    final barcode = TextEditingController(text: product?.barcode ?? '');
    final price = TextEditingController(text: product?.price.toString() ?? '');
    final cost = TextEditingController(
      text: product?.costPrice.toString() ?? '',
    );
    final stock = TextEditingController(text: product?.stock.toString() ?? '');
    final minStock = TextEditingController(
      text: product?.minStock.toString() ?? '',
    );
    var selectedUnit = product?.unit == 'dus' ? 'dus' : 'pcs';
    final piecesPerPack = TextEditingController(
      text: product?.piecesPerPack.toString() ?? '1',
    );
    final category = TextEditingController(text: product?.category ?? '');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(product == null ? 'Tambah Produk' : 'Edit Produk'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _input(name, 'Nama produk'),
                    Row(
                      children: [
                        Expanded(child: _input(barcode, 'Barcode')),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Pindai barcode dengan kamera',
                          onPressed: () async {
                            final code = await Navigator.of(context)
                                .push<String>(
                                  MaterialPageRoute<String>(
                                    builder: (_) =>
                                        const BarcodeScannerScreen(),
                                  ),
                                );
                            if (code != null) barcode.text = code;
                          },
                          icon: const Icon(Icons.camera_alt),
                        ),
                      ],
                    ),
                    _input(price, 'Harga jual per pcs', number: true),
                    _input(
                      cost,
                      'Harga modal per pcs',
                      number: true,
                      optional: true,
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _input(
                            stock,
                            product == null
                                ? 'Stok awal ($selectedUnit)'
                                : 'Stok saat ini (pcs)',
                            number: true,
                            readOnly:
                                product != null && profile.role != roleOwner,
                            integer: true,
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: DropdownButtonFormField<String>(
                              key: ValueKey(selectedUnit),
                              initialValue: selectedUnit,
                              decoration: const InputDecoration(
                                labelText: 'Satuan',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'pcs',
                                  child: Text('pcs'),
                                ),
                                DropdownMenuItem(
                                  value: 'dus',
                                  child: Text('dus'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setDialogState(() => selectedUnit = value);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (selectedUnit == 'dus') ...[
                      _input(
                        piecesPerPack,
                        'Banyak pcs per dus',
                        number: true,
                        integer: true,
                        minimumInteger: 1,
                        maximumInteger: 100000,
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      if (product == null)
                        Builder(
                          builder: (context) {
                            final quantity = int.tryParse(stock.text);
                            final packSize = int.tryParse(piecesPerPack.text);
                            final preview =
                                quantity != null &&
                                    packSize != null &&
                                    quantity >= 0 &&
                                    packSize > 0
                                ? quantity * packSize
                                : null;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  preview == null
                                      ? 'Stok akan disimpan dalam pcs.'
                                      : 'Stok tersimpan: $preview pcs',
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                    _input(
                      minStock,
                      'Ambang stok minimum (pcs)',
                      integer: true,
                    ),
                    _input(category, 'Kategori', optional: true),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                if (selectedUnit == 'dus' &&
                    int.tryParse(piecesPerPack.text) == null) {
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && context.mounted) {
      try {
        await ProductService().saveProduct(
          id: product?.id,
          businessId: profile.businessId,
          name: name.text,
          barcode: barcode.text,
          price: double.parse(price.text),
          costPrice: cost.text.trim().isEmpty ? 0 : double.parse(cost.text),
          stock: int.parse(stock.text),
          minStock: int.parse(minStock.text),
          unit: selectedUnit,
          piecesPerPack: selectedUnit == 'dus'
              ? int.parse(piecesPerPack.text)
              : 1,
          category: category.text,
        );
        if (context.mounted) {
          showAppMessage(context, 'Produk berhasil disimpan.');
        }
      } catch (error) {
        if (context.mounted) {
          showAppMessage(context, error.toString(), error: true);
        }
      }
    }
    name.dispose();
    barcode.dispose();
    price.dispose();
    cost.dispose();
    stock.dispose();
    minStock.dispose();
    piecesPerPack.dispose();
    category.dispose();
  }

  static Widget _input(
    TextEditingController controller,
    String label, {
    bool number = false,
    bool integer = false,
    int? minimumInteger,
    int? maximumInteger,
    bool optional = false,
    bool readOnly = false,
    ValueChanged<String>? onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : integer
          ? TextInputType.number
          : null,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (optional && (value == null || value.trim().isEmpty)) return null;
        if (value == null || value.trim().isEmpty) return '$label wajib diisi.';
        if (number && num.tryParse(value) == null) {
          return 'Masukkan angka yang valid.';
        }
        if (integer && int.tryParse(value) == null) {
          return 'Masukkan bilangan bulat.';
        }
        if (number && num.parse(value) < 0) return 'Nilai tidak boleh negatif.';
        if (integer && int.parse(value) < (minimumInteger ?? 0)) {
          return minimumInteger == null
              ? 'Nilai tidak boleh negatif.'
              : 'Nilai minimal $minimumInteger.';
        }
        if (integer &&
            maximumInteger != null &&
            int.parse(value) > maximumInteger) {
          return 'Nilai maksimal $maximumInteger.';
        }
        return null;
      },
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Produk')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(context),
      icon: const Icon(Icons.add),
      label: const Text('Tambah Produk'),
    ),
    body: StreamBuilder<List<ProductModel>>(
      stream: ProductService().watchProducts(profile.businessId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Gagal memuat produk: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final products = snapshot.data!;
        if (products.isEmpty) {
          return const Center(child: Text('Belum ada produk.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return Card(
              child: ListTile(
                title: Text(product.name),
                subtitle: Text(
                  '${product.barcode} · Stok ${product.stock} pcs'
                  '${product.unit == 'dus' ? ' (${product.piecesPerPack} pcs/dus)' : ''}',
                ),
                trailing: Text(formatRupiah(product.price)),
                onTap: () => _edit(context, product),
              ),
            );
          },
        );
      },
    ),
  );
}
