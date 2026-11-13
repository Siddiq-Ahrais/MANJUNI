import 'package:flutter/material.dart';
import '../services/api_config.dart';
import '../services/api_service.dart';
import '../services/navigation_service.dart';

class TransaksiPage extends StatefulWidget {
  const TransaksiPage({super.key});

  @override
  State<TransaksiPage> createState() => _TransaksiPageState();
}

class _TransaksiPageState extends State<TransaksiPage> {
  static const Color kGreen = Color(0xFF1E874B);
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];
  String _searchQuery = '';

  List<Map<String, dynamic>> get _filteredTransactions {
    if (_searchQuery.trim().isEmpty) return _transactions;
    final q = _searchQuery.toLowerCase();
    return _transactions.where((t) {
      final invoice = (t['invoice_id'] ?? t['id'] ?? '').toString().toLowerCase();
      final customer = (t['customer'] ?? '').toString().toLowerCase();
      final method = (t['payment_method'] ?? t['method'] ?? '').toString().toLowerCase();
      final items = (t['items'] is List)
          ? (t['items'] as List).map((i) => i['name']?.toString().toLowerCase() ?? '').join(' ')
          : (t['items']?.toString().toLowerCase() ?? '');
      return invoice.contains(q) ||
          customer.contains(q) ||
          method.contains(q) ||
          items.contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    ApiConfig.baseUrlNotifier.addListener(_onUrlChanged);
    ApiService.dataChangedNotifier.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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
    if (v <= 0) return 'Rp0';
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
    return _transactions.fold(0, (s, t) => s + ((t['amount'] as int?) ?? 0));
  }

  int get _pendingCount => _transactions.where((t) => t['synced'] != true).length;

  void _showTransactionDetail(Map<String, dynamic> trx) {
    final String trxId = trx['id']?.toString() ?? '-';
    final int amount = (trx['amount'] as num?)?.toInt() ??
        (trx['total_amount'] as num?)?.toInt() ??
        0;
    final String method = (trx['method'] ?? trx['payment_method'] ?? 'Tunai').toString();
    final String time = trx['time']?.toString() ?? '-';
    final bool isSynced = trx['synced'] == true;
    final List rawCartItems = trx['cartItems'] is List
        ? trx['cartItems'] as List
        : (trx['items'] is List ? trx['items'] as List : const []);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: kGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Detail $trxId',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Waktu: $time', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSynced ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isSynced ? 'Tersinkron' : 'Menunggu sinkron',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSynced ? const Color(0xFF166534) : const Color(0xFF9A3412),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Metode Pembayaran: $method', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const Divider(height: 20),
              const Text('Rincian Produk:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              if (rawCartItems.isNotEmpty)
                ...rawCartItems.map((ci) {
                  final Map itemMap = ci is Map ? ci : const {};
                  final Map productMap = itemMap['product'] is Map ? itemMap['product'] as Map : const {};
                  final String name = (itemMap['name'] ??
                          itemMap['item_name'] ??
                          productMap['name'] ??
                          '-')
                      .toString();
                  final int price = (itemMap['price'] as num?)?.toInt() ??
                      (itemMap['unit_price'] as num?)?.toInt() ??
                      (productMap['selling_price'] as num?)?.toInt() ??
                      0;
                  final int qty = (itemMap['qty'] as num?)?.toInt() ??
                      (itemMap['quantity'] as num?)?.toInt() ??
                      1;
                  final String unit =
                      (itemMap['unit'] ?? productMap['unit'] ?? '').toString().trim();
                  final int lineSubtotal =
                      (itemMap['subtotal'] as num?)?.toInt() ?? (price * qty);
                  final String qtyLabel = unit.isNotEmpty ? '$qty $unit' : '$qty x';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              Text(
                                price > 0 ? '$qtyLabel × ${_formatRp(price)}' : qtyLabel,
                                style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatRp(lineSubtotal),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                })
              else
                Text(trx['items']?.toString() ?? '-', style: const TextStyle(fontSize: 13)),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(_formatRp(amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kGreen)),
                ],
              ),
            ],
          ),
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
      body: SafeArea(
        child: RefreshIndicator(
          color: kGreen,
          onRefresh: _loadTransactions,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),

                // Summary Cards Row
                _buildSummaryCards(),
                const SizedBox(height: 16),

                // Sync Warning Banner (Only when there are pending transactions)
                if (_pendingCount > 0) ...[
                  _buildSyncBanner(),
                  const SizedBox(height: 16),
                ],

                // Search Bar
                _buildSearchBar(),
                const SizedBox(height: 16),

                // History Header
                _buildHistoryHeader(),
                const SizedBox(height: 12),

                // Transaction List or Empty State
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: kGreen),
                    ),
                  )
                else if (_transactions.isEmpty)
                  _buildEmptyState()
                else if (_filteredTransactions.isEmpty)
                  _buildSearchEmptyState()
                else
                  Column(
                    children: _filteredTransactions.map((trx) {
                      return GestureDetector(
                        onTap: () => _showTransactionDetail(trx),
                        child: _TransactionCard(trx: trx, formatRp: _formatRp),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
                Icons.receipt_long_outlined,
                color: kGreen,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Transaksi',
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
        if (_transactions.isNotEmpty)
          TextButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Reset Riwayat', style: TextStyle(fontWeight: FontWeight.bold)),
                  content: const Text('Apakah Anda yakin ingin mengosongkan riwayat transaksi?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        // Kosongkan riwayat transaksi (lokal & backend); produk tetap ada.
                        await ApiService.resetTransactions();
                        if (!mounted) return;
                        _searchCtrl.clear();
                        _searchQuery = '';
                        await _loadTransactions();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Riwayat transaksi berhasil direset'),
                            backgroundColor: kGreen,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: Colors.red),
            label: const Text('Reset', style: TextStyle(color: Colors.red, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return Row(
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
                const SizedBox(height: 6),
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
                const SizedBox(height: 4),
                Text(
                  _transactions.isEmpty ? 'Belum ada omzet' : '${_transactions.length} transaksi selesai',
                  style: const TextStyle(
                    color: Color(0xFF1B5E20),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Jumlah Transaksi (Light Blue)
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFBBDEFB),
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
                const SizedBox(height: 6),
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
                const SizedBox(height: 4),
                Text(
                  _transactions.isEmpty ? 'User baru' : 'Hari ini',
                  style: const TextStyle(
                    color: Color(0xFF0D47A1),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSyncBanner() {
    return Container(
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
              '$_pendingCount transaksi menunggu sinkron saat online',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Cari invoice, pelanggan, atau produk...',
          hintStyle: const TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 13.5,
          ),
          icon: const Icon(Icons.search, color: Color(0xFF6B7280), size: 22),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildHistoryHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Riwayat Transaksi',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: Color(0xFF111827),
          ),
        ),
        Text(
          _searchQuery.isNotEmpty
              ? '${_filteredTransactions.length} Ditemukan'
              : '${_transactions.length} Transaksi',
          style: const TextStyle(
            fontSize: 14,
            color: kGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
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
              Icons.receipt_long_outlined,
              size: 34,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Belum Ada Riwayat Transaksi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Riwayat transaksi masih kosong untuk user baru.\nTransaksi akan otomatis tercatat setelah Anda melakukan pembayaran di keranjang.',
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
              NavigationService.navigateTo(1); // Go to Produk tab
            },
            icon: const Icon(Icons.storefront_outlined, size: 18),
            label: const Text('Mulai Belanja Produk'),
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

  Widget _buildSearchEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            'Tidak ditemukan transaksi untuk "$_searchQuery"',
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TRANSACTION CARD
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

    // Color based on method
    Color methodColor = Colors.green;
    if (method.toLowerCase().contains('qris')) {
      methodColor = Colors.blue;
    } else if (method.toLowerCase().contains('kasbon')) {
      methodColor = Colors.orange;
    }

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
          const SizedBox(height: 10),

          // Items Summary
          Text(
            items,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),

          // Footer: Method tag & Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: methodColor.withAlpha(38),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  method,
                  style: TextStyle(
                    color: methodColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                formatRp(amount),
                style: const TextStyle(
                  color: Color(0xFF1E874B),
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
