import 'package:flutter/material.dart';

class KeranjangUI extends StatelessWidget {
  const KeranjangUI({super.key});

  final Color kGreen = const Color(0xFF1E874B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildCustomerCard(),
            const SizedBox(height: 16),
            _buildCartItem(
              title: 'Beras 5kg',
              priceInfo: 'Rp75.000 / kemasan',
              qty: 1,
              totalPrice: 'Rp75.000',
            ),
            const SizedBox(height: 12),
            _buildCartItem(
              title: 'Gula Pasir 1kg',
              priceInfo: 'Rp17.000 / kemasan',
              qty: 3,
              totalPrice: 'Rp51.000',
            ),
            const SizedBox(height: 24),
            const Text('Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildPaymentMethods(),
            const SizedBox(height: 24),
            _buildSummaryCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Keranjang',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Warung Maju Jaya',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: const Icon(Icons.menu, size: 20),
        ),
      ],
    );
  }

  Widget _buildCustomerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD), // Light blue
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.person_outline, color: Colors.blue),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pelanggan', style: TextStyle(fontSize: 12, color: Colors.black54)),
                SizedBox(height: 4),
                Text('Pelanggan Umum', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue.shade700,
              side: BorderSide(color: Colors.blue.shade700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Ganti'),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem({
    required String title,
    required String priceInfo,
    required int qty,
    required String totalPrice,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE0B2), // Light orange
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF8D6E63), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(priceInfo, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildQtyBtn(Icons.remove, Colors.black54, Colors.white, true),
                  SizedBox(
                    width: 40,
                    child: Text(qty.toString(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  _buildQtyBtn(Icons.add, Colors.white, kGreen, false),
                ],
              ),
              Text(totalPrice, style: TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, Color iconColor, Color bgColor, bool isBordered) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: isBordered ? Border.all(color: Colors.grey.shade300) : null,
      ),
      child: IconButton(
        onPressed: () {},
        icon: Icon(icon, color: iconColor, size: 20),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return Row(
      children: [
        Expanded(child: _buildPaymentMethodBtn('Tunai', true)),
        const SizedBox(width: 8),
        Expanded(child: _buildPaymentMethodBtn('QRIS', false)),
        const SizedBox(width: 8),
        Expanded(child: _buildPaymentMethodBtn('Kasbon', false)),
      ],
    );
  }

  Widget _buildPaymentMethodBtn(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? kGreen : Colors.grey.shade300,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? kGreen : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFA5D6A7), // Light green
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal (4 item)', style: TextStyle(fontSize: 14)),
              const Text('Rp126.000', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Diskon', style: TextStyle(fontSize: 14)),
              const Text('Rp0', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const Divider(height: 24, color: Colors.white, thickness: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Bayar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Text('Rp126.000', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Color(0xFF1B5E20))),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('Bayar Rp126.000', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20), // Dark green
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Transaksi tersimpan di perangkat dan disinkronkan saat online',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF1B5E20)),
          ),
        ],
      ),
    );
  }
}