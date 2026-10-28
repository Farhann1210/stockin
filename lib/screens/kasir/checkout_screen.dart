import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/product_model.dart';
import '../../models/transaction_model.dart';
import '../../models/user_model.dart';
import '../../services/product_service.dart';
import '../../services/transaction_service.dart';
import '../common.dart';
import '../product_picker_sheet.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.profile, this.auditUserId});
  final UserModel profile;
  final String? auditUserId;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _search = TextEditingController();
  final List<TransactionItem> _cart = [];
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _addProduct(ProductModel product) {
    final index = _cart.indexWhere((item) => item.productId == product.id);
    if (product.stock <= (index < 0 ? 0 : _cart[index].qty)) {
      showAppMessage(
        context,
        'Stok ${product.name} tidak mencukupi.',
        error: true,
      );
      return;
    }
    setState(() {
      if (index < 0) {
        _cart.add(
          TransactionItem(
            productId: product.id,
            name: product.name,
            qty: 1,
            price: product.price,
          ),
        );
      } else {
        final item = _cart[index];
        _cart[index] = TransactionItem(
          productId: item.productId,
          name: item.name,
          qty: item.qty + 1,
          price: item.price,
        );
      }
    });
  }

  void _changeQty(int index, int change) {
    final item = _cart[index];
    final newQty = item.qty + change;
    if (newQty <= 0) {
      setState(() => _cart.removeAt(index));
      return;
    }
    setState(
      () => _cart[index] = TransactionItem(
        productId: item.productId,
        name: item.name,
        qty: newQty,
        price: item.price,
      ),
    );
  }

  Future<void> _pickProduct() async {
    final product = await showProductPicker(
      context,
      businessId: widget.profile.businessId,
    );
    if (product != null && mounted) _addProduct(product);
  }

  Future<void> _finish(double total) async {
    if (_cart.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final payment = await _showPaymentDialog(total);
      if (payment == null) return;
      await TransactionService().completeSale(
        businessId: widget.profile.businessId,
        cashierId: widget.auditUserId ?? widget.profile.id,
        cashierName: widget.profile.name.trim().isEmpty
            ? 'Kasir'
            : widget.profile.name.trim(),
        items: _cart,
        paymentMethod: payment.method,
      );
      if (mounted) {
        setState(_cart.clear);
        showAppMessage(context, 'Transaksi berhasil disimpan.');
      }
    } catch (error) {
      if (mounted) showAppMessage(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<_PaymentDetails?> _showPaymentDialog(double total) async {
    final cashController = TextEditingController();
    var method = 'cash';
    final payment = await showDialog<_PaymentDetails>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final received = double.tryParse(cashController.text.trim()) ?? 0;
          final change = received - total;
          return AlertDialog(
            title: const Text('Pembayaran Kasir'),
            content: SizedBox(
              width: 440,
              child: StatefulBuilder(
                builder: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text('Total yang Harus Dibayar'),
                          const SizedBox(height: 4),
                          Text(
                            formatRupiah(total),
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'cash',
                          label: Text('Tunai'),
                          icon: Icon(Icons.payments_outlined),
                        ),
                        ButtonSegment(
                          value: 'qris',
                          label: Text('QRIS'),
                          icon: Icon(Icons.qr_code_2),
                        ),
                      ],
                      selected: {method},
                      onSelectionChanged: (selection) {
                        setDialogState(() => method = selection.first);
                      },
                    ),
                    if (method == 'cash') ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: cashController,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Uang Tunai Diterima (Rp)',
                          prefixText: 'Rp ',
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _CashSuggestion(
                            label: 'Uang Pas',
                            value: total,
                            onSelected: (value) {
                              cashController.text = value.round().toString();
                              setDialogState(() {});
                            },
                          ),
                          _CashSuggestion(
                            label: 'Rp 150k',
                            value: 150000,
                            onSelected: (value) {
                              cashController.text = value.toString();
                              setDialogState(() {});
                            },
                          ),
                          _CashSuggestion(
                            label: 'Rp 200k',
                            value: 200000,
                            onSelected: (value) {
                              cashController.text = value.toString();
                              setDialogState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Expanded(child: Text('Kembalian:')),
                            Text(
                              formatRupiah(change < 0 ? 0 : change),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (method == 'qris')
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Text(
                          'Konfirmasi pembayaran QRIS sebelum menyelesaikan transaksi.',
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: method == 'qris' || received >= total
                    ? () => Navigator.pop(
                        dialogContext,
                        _PaymentDetails(method: method),
                      )
                    : null,
                child: const Text('Selesai'),
              ),
            ],
          );
        },
      ),
    );
    cashController.dispose();
    return payment;
  }

  @override
  Widget build(BuildContext context) {
    final total = _cart.fold<double>(0, (sum, item) => sum + item.subtotal);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kasir Stockin'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.point_of_sale), text: 'Kasir & Checkout'),
              Tab(
                icon: Icon(Icons.receipt_long_outlined),
                text: 'Riwayat Transaksi Saya',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildCheckoutTab(total),
            _TransactionHistory(
              profile: widget.profile,
              cashierId: widget.auditUserId ?? widget.profile.id,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutTab(double total) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Cari produk / ketik barcode...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Pindai atau pilih produk',
              onPressed: _pickProduct,
              icon: const Icon(Icons.qr_code_scanner),
            ),
          ],
        ),
      ),
      Expanded(
        child: StreamBuilder<List<ProductModel>>(
          stream: ProductService().watchProducts(widget.profile.businessId),
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
              return Center(
                child: Text(
                  query.isEmpty
                      ? 'Belum ada produk.'
                      : 'Produk tidak ditemukan.',
                ),
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 500
                    ? 1
                    : constraints.maxWidth < 900
                    ? 2
                    : 3;
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: columns == 1 ? 184 : 210,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final quantity = _cart
                        .where((item) => item.productId == product.id)
                        .fold<int>(0, (sum, item) => sum + item.qty);
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _addProduct(product),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      product.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  if (quantity == 0)
                                    IconButton.filledTonal(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Tambah ${product.name}',
                                      onPressed: () => _addProduct(product),
                                      icon: const Icon(Icons.add),
                                    )
                                  else
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          tooltip: 'Kurangi ${product.name}',
                                          onPressed: () => _changeQty(
                                            _cart.indexWhere(
                                              (item) =>
                                                  item.productId == product.id,
                                            ),
                                            -1,
                                          ),
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                          ),
                                        ),
                                        Text('$quantity'),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          tooltip: 'Tambah ${product.name}',
                                          onPressed: () => _addProduct(product),
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              Text(
                                'BC: ${product.barcode}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                formatRupiah(product.price),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              _StockBadge(
                                label: quantity > 0
                                    ? 'Stok ${product.stock} · $quantity'
                                    : 'Stok: ${product.stock}',
                                warning: product.stock <= product.minStock,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total Tagihan · ${_cart.fold<int>(0, (sum, item) => sum + item.qty)} item',
                    ),
                    Text(
                      formatRupiah(total),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: _busy || _cart.isEmpty ? null : () => _finish(total),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Bayar (Checkout)'),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.label, required this.warning});

  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: warning
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(label, style: Theme.of(context).textTheme.labelMedium),
  );
}

class _CashSuggestion extends StatelessWidget {
  const _CashSuggestion({
    required this.label,
    required this.value,
    required this.onSelected,
  });

  final String label;
  final double value;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) =>
      OutlinedButton(onPressed: () => onSelected(value), child: Text(label));
}

class _PaymentDetails {
  const _PaymentDetails({required this.method});

  final String method;
}

class _TransactionHistory extends StatelessWidget {
  const _TransactionHistory({required this.profile, required this.cashierId});

  final UserModel profile;
  final String cashierId;

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: TransactionService().watchTransactions(
      profile.businessId,
      cashierId: cashierId,
    ),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Text('Gagal memuat riwayat transaksi: ${snapshot.error}'),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final transactions = snapshot.data!;
      if (transactions.isEmpty) {
        return const Center(child: Text('Belum ada transaksi.'));
      }
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: transactions.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          final itemSummary = transaction.items
              .map((item) => '${item.name} (${item.qty}x)')
              .join(', ');
          final createdAt = transaction.createdAt;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '#TRX-${transaction.id.substring(0, 6).toUpperCase()}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        formatRupiah(transaction.totalAmount),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    createdAt == null
                        ? 'Waktu transaksi tidak tersedia'
                        : DateFormat(
                            'd MMM yyyy, HH:mm',
                            'id_ID',
                          ).format(createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${transaction.items.length} item: $itemSummary',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 6),
                  Text('Kasir: ${transaction.cashierName}'),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
