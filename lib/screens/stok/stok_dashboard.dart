import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/product_model.dart';
import '../../models/stock_log_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/product_service.dart';
import '../../services/stock_service.dart';
import '../common.dart';
import '../owner/manage_products_screen.dart';
import '../profile_screen.dart';
import '../product_picker_sheet.dart';

class StokDashboard extends StatelessWidget {
  const StokDashboard({
    super.key,
    required this.profile,
    this.auditUserId,
    this.ownerMode = false,
  });
  final UserModel profile;
  final String? auditUserId;
  final bool ownerMode;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Stok'),
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
              tooltip: 'Keluar',
              onPressed: () =>
                  confirmSignOut(context, context.read<AuthProvider>().logout),
              icon: const Icon(Icons.logout),
            ),
          ],
        ],
        bottom: const TabBar(
          tabs: [
            Tab(icon: Icon(Icons.swap_vert), text: 'Input Mutasi'),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Katalog & Stok'),
            Tab(icon: Icon(Icons.history), text: 'Log Mutasi'),
          ],
        ),
      ),
      body: StreamBuilder<List<ProductModel>>(
        stream: ProductService().watchProducts(profile.businessId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Gagal memuat produk: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final products = snapshot.data!;
          return TabBarView(
            children: [
              _StockMutationTab(
                profile: profile,
                auditUserId: auditUserId ?? profile.id,
                ownerMode: ownerMode,
              ),
              _ProductCatalogTab(profile: profile, products: products),
              _StockHistoryTab(profile: profile, products: products),
            ],
          );
        },
      ),
    ),
  );
}

class _StockMutationTab extends StatefulWidget {
  const _StockMutationTab({
    required this.profile,
    required this.auditUserId,
    required this.ownerMode,
  });

  final UserModel profile;
  final String auditUserId;
  final bool ownerMode;

  @override
  State<_StockMutationTab> createState() => _StockMutationTabState();
}

class _StockMutationTabState extends State<_StockMutationTab> {
  final _quantity = TextEditingController(text: '1');
  final _note = TextEditingController();
  ProductModel? _product;
  String _type = 'in';
  bool _busy = false;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _selectProduct() async {
    final product = await showProductPicker(
      context,
      businessId: widget.profile.businessId,
    );
    if (product != null && mounted) setState(() => _product = product);
  }

  Future<void> _save() async {
    final product = _product;
    final quantity = int.tryParse(_quantity.text);
    if (product == null) {
      showAppMessage(context, 'Pilih produk terlebih dahulu.', error: true);
      return;
    }
    if (quantity == null || quantity <= 0) {
      showAppMessage(context, 'Jumlah harus lebih dari nol.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await StockService().adjustStock(
        product: product,
        userId: widget.auditUserId,
        type: _type,
        quantity: quantity,
        note: _note.text,
      );
      if (mounted) {
        setState(() {
          _product = null;
          _quantity.text = '1';
          _note.clear();
        });
        showAppMessage(context, 'Perubahan stok berhasil disimpan.');
      }
    } catch (error) {
      if (mounted) showAppMessage(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.ownerMode)
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Fitur Manajemen Stok untuk Owner'),
              subtitle: Text('Log mutasi akan tercatat atas nama Owner.'),
            ),
          ),
        Text(
          'Pencatatan Stok Masuk / Keluar',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          'Scan barcode barang fisik atau pilih dari katalog untuk memperbarui jumlah persediaan.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'in',
              label: Text('Stok Masuk (+)'),
              icon: Icon(Icons.south),
            ),
            ButtonSegment(
              value: 'out',
              label: Text('Stok Keluar (-)'),
              icon: Icon(Icons.north),
            ),
          ],
          selected: {_type},
          onSelectionChanged: (selection) =>
              setState(() => _type = selection.first),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pilih Produk:',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _selectProduct,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan Barcode'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (product == null)
                  Text(
                    'Belum ada produk dipilih. Scan barcode atau pilih dari daftar produk.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  )
                else
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(product.name),
                    subtitle: Text(
                      'Barcode: ${product.barcode} · Stok saat ini: ${product.stock} pcs',
                    ),
                    trailing: IconButton(
                      tooltip: 'Ganti produk',
                      onPressed: _selectProduct,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _quantity,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Jumlah ${product?.unit == 'dus' ? '(dus)' : '(pcs)'}',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          maxLength: 300,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Catatan (opsional)',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy ? null : _save,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Simpan Perubahan Stok'),
        ),
      ],
    );
  }
}

class _ProductCatalogTab extends StatelessWidget {
  const _ProductCatalogTab({required this.profile, required this.products});

  final UserModel profile;
  final List<ProductModel> products;

  Future<void> _openProducts(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ManageProductsScreen(profile: profile),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final lowStock = products
        .where((product) => product.stock <= product.minStock)
        .length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${products.length} produk · $lowStock perlu restock',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _openProducts(context),
                icon: const Icon(Icons.add),
                label: const Text('Tambah Produk'),
              ),
            ],
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? const Center(child: Text('Belum ada produk.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final low = product.stock <= product.minStock;
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        title: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Barcode: ${product.barcode}\n'
                            'Kategori: ${product.category.isEmpty ? 'Umum' : product.category}',
                          ),
                        ),
                        isThreeLine: true,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: low
                                ? Theme.of(context).colorScheme.errorContainer
                                : Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${product.stock} pcs',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        onTap: () => _openProducts(context),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _StockHistoryTab extends StatelessWidget {
  const _StockHistoryTab({required this.profile, required this.products});

  final UserModel profile;
  final List<ProductModel> products;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<StockLogModel>>(
    stream: StockService().watchLogs(profile.businessId),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Text('Gagal memuat log mutasi: ${snapshot.error}'),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final logs = snapshot.data!.toList()
        ..sort(
          (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
            a.createdAt ?? DateTime(1970),
          ),
        );
      if (logs.isEmpty) {
        return const Center(child: Text('Belum ada riwayat mutasi stok.'));
      }
      final productNames = {
        for (final product in products) product.id: product.name,
      };
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[index];
          final isIncoming = log.type == 'in';
          final color = isIncoming
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error;
          final productName =
              productNames[log.productId] ?? 'Produk tidak ditemukan';
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Icon(
                isIncoming ? Icons.south : Icons.north,
                color: color,
                size: 30,
              ),
              title: Text(
                productName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.createdAt == null
                          ? 'Waktu tidak tersedia'
                          : DateFormat(
                              'd MMM yyyy, HH:mm',
                              'id_ID',
                            ).format(log.createdAt!),
                    ),
                    if (log.note.isNotEmpty) Text(log.note),
                  ],
                ),
              ),
              trailing: Text(
                '${isIncoming ? '+' : '-'}${log.quantity}',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
