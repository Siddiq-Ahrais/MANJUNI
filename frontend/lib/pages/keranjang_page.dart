import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../services/navigation_service.dart';
import '../widgets/qris_payment_dialog.dart';

class KeranjangPage extends StatefulWidget {
  const KeranjangPage({super.key});

  @override
  State<KeranjangPage> createState() => _KeranjangPageState();
}

class _KeranjangPageState extends State<KeranjangPage> {
  static const Color kGreen = Color(0xFF1E874B);

  int _selectedPayment = 0; // 0=Tunai, 1=QRIS, 2=Kasbon
  final List<String> _paymentMethods = ['Tunai', 'QRIS', 'Kasbon'];
  String _customerName = 'Pelanggan Umum';
  bool _isProcessing = false;

  String _formatRp(int value) {
    if (value <= 0) return 'Rp0';
    String s = value.toString();
    String result = '';
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) result = '.$result';
      result = s[i] + result;
      count++;
    }
    return 'Rp$result';
  }

  void _showChangeCustomerDialog() {
    final ctrl = TextEditingController(text: _customerName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Ganti Nama Pelanggan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Nama Pelanggan',
            hintText: 'Misal: Ibu Ani / Pak Joko',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() => _customerName = ctrl.text.trim());
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<bool> _validateStock(List<CartItem> cartItems) async {
    final latestProducts = await ApiService.getProducts();
    for (final item in cartItems) {
      final match = latestProducts.firstWhere(
        (p) => (p['name'] as String? ?? '').toLowerCase() == item.name.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );
      if (match.isNotEmpty) {
        final availableStock = (match['stock'] as int?) ?? 0;
        if (item.qty > availableStock) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Stok ${item.name} tidak mencukupi (tersisa $availableStock, di keranjang ${item.qty}).',
                ),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return false;
        }
      }
    }
    return true;
  }

  Future<void> _handleCheckout() async {
    final cartItems = CartService.cartNotifier.value;
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keranjang belanja kosong! Silakan pilih produk terlebih dahulu.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    // Validasi stok terbaru sebelum checkout
    final isStockValid = await _validateStock(cartItems);
    if (!isStockValid) {
      if (mounted) setState(() => _isProcessing = false);
      return;
    }

    // Jika metode pembayaran QRIS (index 1), buka alur QRIS & Barcode (Generate / Scan)
    if (_selectedPayment == 1) {
      setState(() => _isProcessing = false);
      await _openQrisPaymentFlow();
      return;
    }

    // Alur Tunai / Kasbon
    final summary = cartItems.map((i) => '${i.name} (${i.qty} ${i.unit})').join(', ');
    final method = _paymentMethods[_selectedPayment];
    final total = CartService.subtotal;

    final success = await ApiService.createTransaction(
      cartItems: cartItems,
      itemsSummary: summary,
      paymentMethod: method,
      totalAmount: total,
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.lastErrorNotifier.value ??
                'Transaksi gagal. Periksa stok produk atau koneksi server.',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _showPaymentSuccessDialog(total: total, method: method);
  }

  /// Buka alur QRIS & Barcode (2 Metode: Generate QR/Barcode & Scan Barcode Pelanggan)
  Future<void> _openQrisPaymentFlow() async {
    final cartItems = CartService.cartNotifier.value;
    if (cartItems.isEmpty) return;

    final isStockValid = await _validateStock(cartItems);
    if (!isStockValid || !mounted) return;

    final summary = cartItems.map((i) => '${i.name} (${i.qty} ${i.unit})').join(', ');
    final total = CartService.subtotal;

    final result = await QrisPaymentDialog.show(
      context,
      totalAmount: total,
      customerName: _customerName,
      itemsSummary: summary,
      onConfirmPayment: ({
        required String barcodeOrQr,
        required String methodDetail,
      }) async {
        return await ApiService.createTransaction(
          cartItems: cartItems,
          itemsSummary: '$summary ($methodDetail)',
          paymentMethod: 'QRIS',
          totalAmount: total,
        );
      },
    );

    if (result == true && mounted) {
      _showPaymentSuccessDialog(
        total: total,
        method: 'QRIS & Barcode Terverifikasi',
      );
    }
  }

  void _showPaymentSuccessDialog({required int total, required String method}) {
    final isOnline = ApiService.isConnectedNotifier.value == true;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: kGreen, size: 48),
            ),
            const SizedBox(height: 16),
            const Text('Pembayaran Berhasil!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Total: ${_formatRp(total)} ($method)',
              style: const TextStyle(fontWeight: FontWeight.bold, color: kGreen),
            ),
            const SizedBox(height: 4),
            Text(
              isOnline
                  ? 'Transaksi berhasil dicatat ke server!'
                  : 'Transaksi tersimpan di perangkat dan disinkronkan saat online.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              CartService.clear();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CartItem>>(
      valueListenable: CartService.cartNotifier,
      builder: (context, cartItems, _) {
        final totalCount = CartService.totalCount;
        final subtotal = CartService.subtotal;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(cartItems.isNotEmpty),
                  const SizedBox(height: 20),

                  // Customer Card
                  _buildCustomerCard(),
                  const SizedBox(height: 16),

                  // Cart Items or Empty State
                  if (cartItems.isEmpty)
                    _buildEmptyCartCard()
                  else
                    ...cartItems.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      return _buildCartItemCard(idx, item);
                    }),

                  const SizedBox(height: 16),

                  // Metode Pembayaran Header & Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Metode Pembayaran',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF111827),
                        ),
                      ),
                      if (_selectedPayment == 1 && cartItems.isNotEmpty)
                        GestureDetector(
                          onTap: _openQrisPaymentFlow,
                          child: const Row(
                            children: [
                              Icon(Icons.qr_code_scanner_rounded, size: 16, color: kGreen),
                              SizedBox(width: 4),
                              Text(
                                'Buka Scanner',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: kGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildPaymentMethodsSelector(),
                  
                  // Quick QRIS Barcode Banner if QRIS selected
                  if (_selectedPayment == 1) ...[
                    const SizedBox(height: 12),
                    _buildQrisQuickBanner(cartItems.isNotEmpty),
                  ],

                  const SizedBox(height: 20),

                  // Ringkasan Pembayaran Card
                  _buildSummaryCard(totalCount, subtotal, cartItems.isNotEmpty),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool hasItems) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                color: kGreen,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Keranjang',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Warung Maju Jaya',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        if (hasItems)
          TextButton.icon(
            onPressed: () {
              CartService.clear();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Keranjang berhasil dikosongkan'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: Colors.red),
            label: const Text('Kosongkan', style: TextStyle(color: Colors.red, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildCustomerCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFD9E6FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: Color(0xFF2563EB),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pelanggan',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _customerName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: _showChangeCustomerDialog,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Ganti',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCartCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_cart_outlined,
              size: 34,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Keranjang Masih Kosong',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Belum ada produk yang ditambahkan ke keranjang belanja.\nSilakan pilih produk dari katalog.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              NavigationService.navigateTo(1);
            },
            icon: const Icon(Icons.storefront_outlined, size: 18),
            label: const Text('Lihat Katalog Produk'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(int idx, CartItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE0B2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: Color(0xFFD97706),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: Color(0xFF111827),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatRp(item.price)} / ${item.unit}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => CartService.removeItem(idx),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444),
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Minus Button
              GestureDetector(
                onTap: () => CartService.updateQty(idx, -1),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                  ),
                  child: const Icon(
                    Icons.remove,
                    color: Color(0xFF4B5563),
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 24,
                child: Text(
                  '${item.qty}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Plus Button
              GestureDetector(
                onTap: () {
                  final updated = CartService.updateQty(idx, 1);
                  if (!updated) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Jumlah ${item.name} mencapai batas stok (${item.maxStock ?? item.qty} ${item.unit})!',
                        ),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(milliseconds: 1400),
                      ),
                    );
                  }
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: kGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.unit,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatRp(item.price * item.qty),
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: kGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsSelector() {
    return Row(
      children: _paymentMethods.asMap().entries.map((e) {
        final bool isSelected = _selectedPayment == e.key;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedPayment = e.key),
            child: Container(
              margin: EdgeInsets.only(right: e.key < 2 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? kGreen : const Color(0xFFE5E7EB),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (e.key == 1) ...[
                      Icon(
                        Icons.qr_code_2_rounded,
                        size: 16,
                        color: isSelected ? kGreen : const Color(0xFF374151),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      e.value,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? kGreen : const Color(0xFF374151),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQrisQuickBanner(bool hasItems) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt_rounded, size: 18, color: kGreen),
              SizedBox(width: 6),
              Text(
                'Dua Metode Pembayaran QRIS Tersedia:',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF166534),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '\u2022 1. Generate: Toko menampilkan QRIS dinamis & Barcode\n\u2022 2. Scan: Kasir memindai barcode / e-wallet pelanggan',
            style: TextStyle(
              fontSize: 11.5,
              color: Color(0xFF15803D),
              height: 1.4,
            ),
          ),
          if (hasItems) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 34,
              child: OutlinedButton.icon(
                onPressed: _openQrisPaymentFlow,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                label: const Text('Buka Layar QRIS & Scanner'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kGreen,
                  side: const BorderSide(color: kGreen),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(int totalCount, int subtotal, bool hasItems) {
    final isQris = _selectedPayment == 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFA5D6A7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal ($totalCount item)',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _formatRp(subtotal),
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Diskon',
                style: TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Rp0',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Color(0xFF81C784), height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Bayar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  _formatRp(subtotal),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: (!hasItems || _isProcessing) ? null : _handleCheckout,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      isQris
                          ? Icons.qr_code_scanner_rounded
                          : hasItems
                              ? Icons.check
                              : Icons.shopping_cart_outlined,
                      color: hasItems ? Colors.white : Colors.grey.shade600,
                      size: 20,
                    ),
              label: Text(
                _isProcessing
                    ? 'Memproses...'
                    : !hasItems
                        ? 'Keranjang Kosong (Rp0)'
                        : isQris
                            ? 'Bayar QRIS / Barcode ${_formatRp(subtotal)}'
                            : 'Bayar  ${_formatRp(subtotal)}',
                style: TextStyle(
                  color: hasItems ? Colors.white : Colors.grey.shade700,
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasItems ? kGreen : Colors.white.withAlpha(180),
                disabledBackgroundColor: Colors.white.withAlpha(150),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Transaksi tersimpan di perangkat dan disinkronkan saat online',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF1B5E20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
