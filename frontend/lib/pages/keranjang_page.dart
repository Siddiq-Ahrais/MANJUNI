import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../services/navigation_service.dart';

class KeranjangPage extends StatefulWidget {
  const KeranjangPage({super.key});

  @override
  State<KeranjangPage> createState() => _KeranjangPageState();
}

class _KeranjangPageState extends State<KeranjangPage> {
  static const Color kGreen = Color(0xFF1E874B);

  int _selectedPayment = 0; // 0=Tunai, 1=QRIS, 2=Kasbon
  final List<String> _paymentMethods = ['Tunai', 'QRIS', 'Kasbon'];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    ApiService.loadStoreProfile();
    ApiService.dataChangedNotifier.addListener(_onProductsChanged);
  }

  @override
  void dispose() {
    ApiService.dataChangedNotifier.removeListener(_onProductsChanged);
    super.dispose();
  }

  void _onProductsChanged() {
    CartService.syncStockLimits(ApiService.localProducts);
    if (mounted) setState(() {});
  }

  int? _resolveAvailableStock(CartItem item, [List<Map<String, dynamic>>? products]) {
    final source = products ?? ApiService.localProducts;
    final match = source.firstWhere(
      (p) {
        final pId = p['id'];
        if (pId != null && item.productId != null && pId.toString() == item.productId.toString()) {
          return true;
        }
        return (p['name']?.toString().trim().toLowerCase() ?? '') ==
            item.name.trim().toLowerCase();
      },
      orElse: () => <String, dynamic>{},
    );
    if (match.isNotEmpty && match['stock'] != null) {
      return (match['stock'] as num).toInt();
    }
    return item.maxStock;
  }

  String _resolveProductImage(CartItem item) {
    final direct = item.image?.trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final match = ApiService.localProducts.firstWhere(
      (p) {
        final pId = p['id'];
        if (pId != null && item.productId != null && pId.toString() == item.productId.toString()) {
          return true;
        }
        return (p['name']?.toString().trim().toLowerCase() ?? '') ==
            item.name.trim().toLowerCase();
      },
      orElse: () => <String, dynamic>{},
    );
    return (match['image'] ?? '').toString().trim();
  }

  String _resolveProductCategory(CartItem item) {
    final direct = item.category?.trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final match = ApiService.localProducts.firstWhere(
      (p) {
        final pId = p['id'];
        if (pId != null && item.productId != null && pId.toString() == item.productId.toString()) {
          return true;
        }
        return (p['name']?.toString().trim().toLowerCase() ?? '') ==
            item.name.trim().toLowerCase();
      },
      orElse: () => <String, dynamic>{},
    );
    return (match['category'] ?? match['jenis'] ?? '').toString().trim();
  }

  Widget _buildCartProductImageWidget(
    String imageSource, {
    required IconData fallbackIcon,
    required Color fallbackColor,
  }) {
    final src = imageSource.trim();
    if (src.startsWith('data:image')) {
      try {
        final commaIdx = src.indexOf(',');
        if (commaIdx != -1) {
          final bytes = base64Decode(src.substring(commaIdx + 1));
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => Icon(fallbackIcon, color: fallbackColor, size: 22),
          );
        }
      } catch (_) {}
    } else if (src.startsWith('http://') || src.startsWith('https://')) {
      return Image.network(
        src,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => Icon(fallbackIcon, color: fallbackColor, size: 22),
      );
    } else if (!kIsWeb && src.isNotEmpty) {
      final file = File(src);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, _, _) => Icon(fallbackIcon, color: fallbackColor, size: 22),
        );
      }
    }
    return Icon(fallbackIcon, color: fallbackColor, size: 22);
  }

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

  Future<bool> _validateStock(List<CartItem> cartItems) async {
    final latestProducts = await ApiService.getProducts();
    CartService.syncStockLimits(latestProducts);

    final Map<String, int> totalQtyByName = {};
    final Map<String, CartItem> itemByName = {};
    for (final item in cartItems) {
      final key = item.name.trim().toLowerCase();
      totalQtyByName[key] = (totalQtyByName[key] ?? 0) + item.qty;
      itemByName.putIfAbsent(key, () => item);
    }

    for (final entry in totalQtyByName.entries) {
      final item = itemByName[entry.key]!;
      final totalRequested = entry.value;
      final availableStock = _resolveAvailableStock(item, latestProducts);
      if (availableStock != null && totalRequested > availableStock) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                availableStock <= 0
                    ? 'Stok ${item.name} sudah habis (0 ${item.unit})!'
                    : 'Stok ${item.name} tidak mencukupi (tersisa $availableStock, di keranjang $totalRequested).',
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return false;
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

    // Aplikasi pencatatan: tombol "Simpan" langsung mencatat transaksi
    // untuk semua metode (Tunai / QRIS / Kasbon) tanpa proses pembayaran.
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

  void _showPaymentSuccessDialog({required int total, required String method}) {
    showDialog(
      context: context,
      barrierDismissible: false,
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
            const Text('Transaksi Tersimpan!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Total: ${_formatRp(total)} ($method)',
              style: const TextStyle(fontWeight: FontWeight.bold, color: kGreen),
            ),
            const SizedBox(height: 4),
            const Text(
              'Transaksi berhasil disimpan di perangkat.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
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

                  // Metode Pencatatan Header & Selector (Tunai, QRIS, Kasbon)
                  const Text(
                    'Metode Pencatatan',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildPaymentMethodsSelector(),

                  const SizedBox(height: 20),

                  // Ringkasan Pencatatan Card
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
        Expanded(
          child: Row(
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Keranjang',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                    ),
                    const SizedBox(height: 2),
                    ValueListenableBuilder<String>(
                      valueListenable: ApiService.storeNameNotifier,
                      builder: (context, storeName, _) => Text(
                        storeName,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    final int? availableStock = _resolveAvailableStock(item);
    final bool overStock = availableStock != null && item.qty > availableStock;
    final bool atStockLimit = availableStock != null && item.qty >= availableStock;
    final String image = _resolveProductImage(item);
    final String category = _resolveProductCategory(item);

    IconData iconData = Icons.inventory_2_outlined;
    Color iconColor = const Color(0xFFD97706);
    Color bgColor = const Color(0xFFFFE0B2);
    final catLower = category.toLowerCase();
    if (catLower.contains('minum') || catLower.contains('kopi') || catLower.contains('teh')) {
      iconData = Icons.local_drink_outlined;
      iconColor = const Color(0xFF0284C7);
      bgColor = const Color(0xFFE0F2FE);
    } else if (catLower.contains('makan') || catLower.contains('snack') || catLower.contains('mie')) {
      iconData = Icons.fastfood_outlined;
      iconColor = const Color(0xFFEA580C);
      bgColor = const Color(0xFFFFEDD5);
    } else if (catLower.contains('sembako') || catLower.contains('beras') || catLower.contains('minyak')) {
      iconData = Icons.shopping_basket_outlined;
      iconColor = const Color(0xFF16A34A);
      bgColor = const Color(0xFFDCFCE7);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: overStock ? const Color(0xFFFCA5A5) : const Color(0xFFF0F0F0),
          width: 1.2,
        ),
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
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: image.isNotEmpty
                    ? _buildCartProductImageWidget(
                        image,
                        fallbackIcon: iconData,
                        fallbackColor: iconColor,
                      )
                    : Icon(
                        iconData,
                        color: iconColor,
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
                    if (availableStock != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        overStock
                            ? 'Melebihi stok! Tersisa $availableStock ${item.unit}'
                            : atStockLimit
                                ? 'Stok habis (batas maksimal $availableStock ${item.unit})'
                                : 'Sisa stok: ${availableStock - item.qty} ${item.unit} (total $availableStock)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: (overStock || atStockLimit) ? FontWeight.w600 : FontWeight.normal,
                          color: overStock
                              ? const Color(0xFFB91C1C)
                              : atStockLimit
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
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
              const SizedBox(width: 12),
              SizedBox(
                width: 28,
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
              const SizedBox(width: 12),
              // Plus Button
              GestureDetector(
                onTap: () {
                  final updated = CartService.updateQty(
                    idx,
                    1,
                    maxStock: availableStock,
                  );
                  if (!updated) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Jumlah ${item.name} mencapai batas stok (${availableStock ?? item.qty} ${item.unit})!',
                        ),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(milliseconds: 1600),
                      ),
                    );
                  }
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: atStockLimit ? Colors.grey.shade400 : kGreen,
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
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.unit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    _formatRp(item.price * item.qty),
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: kGreen,
                    ),
                  ),
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

  Widget _buildSummaryCard(int totalCount, int subtotal, bool hasItems) {
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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Color(0xFF81C784), height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
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
                      hasItems ? Icons.save_rounded : Icons.shopping_cart_outlined,
                      color: hasItems ? Colors.white : Colors.grey.shade600,
                      size: 20,
                    ),
              label: Text(
                _isProcessing
                    ? 'Menyimpan...'
                    : !hasItems
                        ? 'Keranjang Kosong (Rp0)'
                        : 'Simpan',
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
