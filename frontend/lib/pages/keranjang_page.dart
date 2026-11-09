import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../widgets/custom_app_bar.dart';

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

  Future<void> _handleCheckout() async {
    final cartItems = CartService.cartNotifier.value;
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keranjang belanja kosong!')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    final summary =
        cartItems.map((i) => '${i.name} (${i.qty}x)').join(', ');
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

    if (success) {
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
                    ? 'Transaksi berhasil dicatat ke server Localhost!'
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
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CartItem>>(
      valueListenable: CartService.cartNotifier,
      builder: (context, cartItems, _) {
        final totalCount = CartService.totalCount;
        final typesCount = CartService.typesCount;
        final subtotal = CartService.subtotal;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: CustomAppBar(
            title: 'Keranjang',
            subtitle:
                '$typesCount jenis \u2022 $totalCount item \u2022 Mode Offline',
            onSearchPressed: () {},
            onNotificationPressed: () {},
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer Card (Matching Image 2 - Pale Blue)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9E6FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEFF6FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          color: Color(0xFF2563EB),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pelanggan',
                              style: TextStyle(
                                fontSize: 12,
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Ganti',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Cart Items (Matching Image 2)
                if (cartItems.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF3F4F6)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Keranjang masih kosong', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                else
                  ...cartItems.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
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
                          // Item info row
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE0B2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  color: Color(0xFFD97706),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_formatRp(item.price)} / ${item.unit}',
                                      style: const TextStyle(
                                        fontSize: 13,
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
                                  size: 22,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Quantity Stepper & Subtotal row
                          Row(
                            children: [
                              // Minus Button
                              GestureDetector(
                                onTap: () => CartService.updateQty(idx, -1),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFD1D5DB)),
                                  ),
                                  child: const Icon(
                                    Icons.remove,
                                    color: Color(0xFF4B5563),
                                    size: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 24,
                                child: Text(
                                  '${item.qty}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Plus Button
                              GestureDetector(
                                onTap: () => CartService.updateQty(idx, 1),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: kGreen,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatRp(item.price * item.qty),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E874B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 8),

                // Metode Pembayaran (Matching Image 2)
                if (cartItems.isNotEmpty) ...[
                  const Text(
                    'Metode Pembayaran',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: _paymentMethods.asMap().entries.map((e) {
                      final bool isSelected = _selectedPayment == e.key;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedPayment = e.key),
                          child: Container(
                            margin: EdgeInsets.only(right: e.key < 2 ? 8 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFE8F5E9)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? kGreen
                                    : const Color(0xFFE5E7EB),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                e.value,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? kGreen
                                      : const Color(0xFF374151),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Ringkasan Pembayaran Card (Pale Green, matching Image 2)
                  Container(
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Action Button: Solid Green Pill with Checkmark
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _handleCheckout,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check, color: Colors.white, size: 22),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _isProcessing
                              ? 'Memproses...'
                              : 'Bayar  ${_formatRp(subtotal)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
