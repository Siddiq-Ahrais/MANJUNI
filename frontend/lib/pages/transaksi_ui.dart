import 'package:flutter/material.dart';

class TransaksiUI extends StatelessWidget {
  const TransaksiUI({super.key});

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
            _buildSummaryCards(),
          const SizedBox(height: 16),
          _buildSyncWarning(),
          const SizedBox(height: 24),
          _buildHistoryHeader(),
          const SizedBox(height: 16),
          _buildTransactionCard(
            id: '#TRX-018',
            time: '14:32',
            items: 'Beras 5kg, Gula Pasir 1kg',
            method: 'Tunai',
            methodColor: Colors.green,
            total: 'Rp92.000',
            status: 'Menunggu sinkron',
            statusColor: Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildTransactionCard(
            id: '#TRX-017',
            time: '14:05',
            items: 'Mie Instan Goreng x10',
            method: 'QRIS',
            methodColor: Colors.blue,
            total: 'Rp35.000',
            status: 'Menunggu sinkron',
            statusColor: Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildTransactionCard(
            id: '#TRX-016',
            time: '13:48',
            items: 'Minyak Goreng 1L x2',
            method: 'Tunai',
            methodColor: Colors.green,
            total: 'Rp39.000',
            status: 'Tersinkron',
            statusColor: Colors.green,
          ),
          const SizedBox(height: 12),
          _buildTransactionCard(
            id: '#TRX-015',
            time: '12:20',
            items: 'Kopi Sachet x6, Teh Botol 450ml x2',
            method: 'QRIS',
            methodColor: Colors.blue,
            total: 'Rp25.000',
            status: 'Tersinkron',
            statusColor: Colors.green,
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFA5D6A7), // Light green
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Omzet Hari Ini', style: TextStyle(fontSize: 12, color: Colors.black87)),
                SizedBox(height: 8),
                Text('Rp520.000', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF1B5E20))),
                SizedBox(height: 8),
                Text('+12% dari kemarin', style: TextStyle(color: Color(0xFF1B5E20), fontSize: 11)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFBBDEFB), // Light blue
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Jumlah Transaksi', style: TextStyle(fontSize: 12, color: Colors.black87)),
                SizedBox(height: 8),
                Text('18 Transaksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF0D47A1))),
                SizedBox(height: 8),
                Text('+3 hari ini', style: TextStyle(color: Color(0xFF0D47A1), fontSize: 11)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSyncWarning() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0), // Light orange
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync, color: Color(0xFFE65100), size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '2 transaksi menunggu sinkron saat online',
              style: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Riwayat Hari Ini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text('8 dari 18', style: TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildTransactionCard({
    required String id,
    required String time,
    required String items,
    required String method,
    required Color methodColor,
    required String total,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$id • $time', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 13)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(status, style: TextStyle(color: statusColor.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(items, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: methodColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(method, style: TextStyle(color: methodColor, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              Text(total, style: TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
        ],
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
              'Transaksi',
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
}