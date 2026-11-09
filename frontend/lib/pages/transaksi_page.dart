import 'package:flutter/material.dart';
import '../services/api_config.dart';
import '../services/api_service.dart';
import '../widgets/custom_app_bar.dart';

class TransaksiPage extends StatefulWidget {
  const TransaksiPage({super.key});

  @override
  State<TransaksiPage> createState() => _TransaksiPageState();
}

class _TransaksiPageState extends State<TransaksiPage> {
  static const Color kGreen = Color(0xFF1E874B);
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    ApiConfig.baseUrlNotifier.addListener(_onUrlChanged);
    ApiService.dataChangedNotifier.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    ApiConfig.baseUrlNotifier.removeListener(_onUrlChanged);
    ApiService.dataChangedNotifier.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _loadTransactions();
  }

  void _onUrlChanged() {
    if (mounted) _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getTransactions();
    if (!mounted) return;
    setState(() {
      _transactions = data;
      _isLoading = false;
    });
  }

  String _formatRp(int v) {
    String s = v.toString();
    String r = '';
    int c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (c > 0 && c % 3 == 0) r = '.$r';
      r = s[i] + r;
      c++;
    }
    return 'Rp$r';
  }

  int get _totalOmzet {
    final sum = _transactions.fold(0, (s, t) => s + ((t['amount'] as int?) ?? 0));
    return sum;
  }

  int get _pendingCount => _transactions.where((t) => t['synced'] != true).length;

  void _showTransactionDetail(Map<String, dynamic> trx) {
    final String trxId = trx['id']?.toString() ?? '-';
    final int amount = (trx['amount'] as int?) ?? 0;
    final List cartItems = trx['cartItems'] as List? ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Detail $trxId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Item Belanja:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6B7280), fontSize: 12)),
            const SizedBox(height: 8),
            if (cartItems.isEmpty)
              Text(trx['items'] ?? '-', style: const TextStyle(fontSize: 14))
            else
              ...cartItems.map((item) {
                final name = item['name'] ?? '-';
                final qty = item['qty'] ?? 1;
                final price = item['price'] ?? 0;
                final subtotal = (price as int) * (qty as int);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${qty}x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$name', style: const TextStyle(fontSize: 14)),
                            Text('@ ${_formatRp(price)}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                          ],
                        ),
                      ),
                      Text(_formatRp(subtotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                );
              }),
            const Divider(height: 24, thickness: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Belanja', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(_formatRp(amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kGreen)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(color: kGreen)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: CustomAppBar(
        title: 'Transaksi',
        subtitle: 'Hari Ini \u2022 Mode Offline',
        onSearchPressed: () {},
        onNotificationPressed: () {},
      ),
      body: RefreshIndicator(
        color: kGreen,
        onRefresh: _loadTransactions,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards Row (matching Image 4)
              Row(
                children: [
                  // Omzet Hari Ini (Mint Green)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA5D6A7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Omzet Hari Ini',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _formatRp(_totalOmzet),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Jumlah Transaksi (Lavender / Soft Blue)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB8C7FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Jumlah Transaksi',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${_transactions.length} Transaksi',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Sync Banner (Orange / Peach Banner matching Image 4)
              if (_pendingCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFE0B2), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sync_rounded, color: Color(0xFFD97706), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$_pendingCount transaksi (QRIS/Kasbon) menunggu sinkron',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Riwayat Hari Ini Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Riwayat Hari Ini',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Color(0xFF111827),
                    ),
                  ),
                  Text(
                    '${_transactions.length} Transaksi',
                    style: const TextStyle(
                      fontSize: 14,
                      color: kGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Transaction List
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: kGreen),
                  ),
                )
              else if (_transactions.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Belum ada transaksi', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              else
                Column(
                  children: _transactions.map((trx) {
                    return GestureDetector(
                      onTap: () => _showTransactionDetail(trx),
                      child: _TransactionCard(trx: trx, formatRp: _formatRp),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TRANSACTION CARD (Exact match to Image 4)
// ─────────────────────────────────────────────
class _TransactionCard extends StatelessWidget {
  final Map<String, dynamic> trx;
  final String Function(int) formatRp;

  const _TransactionCard({required this.trx, required this.formatRp});

  @override
  Widget build(BuildContext context) {
    final bool isSynced = trx['synced'] == true;
    final String method = trx['method']?.toString() ?? 'Tunai';
    final int amount = (trx['amount'] as int?) ?? 0;
    final String trxId = trx['id']?.toString() ?? 'TRX-001';
    final String time = trx['time']?.toString() ?? '12:00';
    final String items = trx['items']?.toString() ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: ID & status pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#$trxId \u2022 $time',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF374151),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSynced
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isSynced ? 'Tersinkron' : 'Menunggu sinkron',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSynced
                        ? const Color(0xFF166534)
                        : const Color(0xFF9A3412),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Items Summary
          Text(
            items,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),

          // Footer row: Method pill & Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMethodPill(method),
              Text(
                formatRp(amount),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E874B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMethodPill(String method) {
    Color bg;
    Color text;

    switch (method.toUpperCase()) {
      case 'QRIS':
        bg = const Color(0xFFDBEAFE);
        text = const Color(0xFF1E40AF);
        break;
      case 'KASBON':
        bg = const Color(0xFFFFEDD5);
        text = const Color(0xFF9A3412);
        break;
      case 'TUNAI':
      default:
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF166534);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        method,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }
}
