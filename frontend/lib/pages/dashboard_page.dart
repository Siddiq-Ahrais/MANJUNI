import 'package:flutter/material.dart';

import '../services/api_config.dart';
import '../services/api_service.dart';
import '../services/navigation_service.dart';
import 'analytics_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  /// Saat `true`, konten di bawah toggle menampilkan statistik Analytics
  /// (dari `AnalyticsView`) alih-alih konten Overview. Dibuka in-place
  /// supaya navbar bawah (Profil, dst.) tetap tampil.
  bool _showAnalytics = false;

  /// Filter periode aktif pada bagian Overview (P1: option 'This week' aktif)
  String _selectedOverviewPeriod = 'This week';
  static const List<String> _overviewPeriodOptions = [
    'Today',
    'This week',
    'This month',
    'All time',
  ];

  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _products = [];
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _syncLocalImmediately();
    _loadOverviewData();
    ApiConfig.baseUrlNotifier.addListener(_onUrlChanged);
    ApiService.dataChangedNotifier.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    ApiConfig.baseUrlNotifier.removeListener(_onUrlChanged);
    ApiService.dataChangedNotifier.removeListener(_onDataChanged);
    super.dispose();
  }

  void _syncLocalImmediately() {
    _transactions = ApiService.localTransactions;
    _products = ApiService.localProducts;
  }

  void _onDataChanged() {
    if (!mounted) return;
    setState(() {
      _syncLocalImmediately();
    });
    _loadOverviewData();
  }

  void _onUrlChanged() {
    if (!mounted) return;
    _loadOverviewData();
  }

  Future<void> _loadOverviewData() async {
    final results = await Future.wait([
      ApiService.getTransactions(),
      ApiService.getProducts(),
      ApiService.getDashboardStats(),
    ]);
    if (!mounted) return;
    setState(() {
      _transactions = results[0] as List<Map<String, dynamic>>;
      _products = results[1] as List<Map<String, dynamic>>;
      _stats = results[2] as Map<String, dynamic>;
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

  /// Filter transaksi sesuai opsi periode ('Today', 'This week', 'This month', 'All time')
  List<Map<String, dynamic>> get _filteredTransactions {
    if (_selectedOverviewPeriod == 'All time') {
      return _transactions;
    }
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return _transactions.where((t) {
      final rawDate = (t['date'] ?? '').toString().trim();
      if (rawDate.isEmpty) return true;
      final parsed = DateTime.tryParse(
        rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate,
      );
      if (parsed == null) return true;
      final txDay = DateTime(parsed.year, parsed.month, parsed.day);
      final diffDays = todayStart.difference(txDay).inDays;

      if (_selectedOverviewPeriod == 'Today') {
        return diffDays == 0;
      } else if (_selectedOverviewPeriod == 'This week') {
        return diffDays >= -1 && diffDays < 7;
      } else if (_selectedOverviewPeriod == 'This month') {
        return (parsed.year == now.year && parsed.month == now.month) ||
            (diffDays >= -1 && diffDays < 30);
      }
      return true;
    }).toList();
  }

  int get _totalOrders {
    final filteredCount = _filteredTransactions.length;
    if (filteredCount > 0) return filteredCount;
    if (_transactions.isEmpty) {
      return (_stats['total_transaksi'] as int?) ?? 0;
    }
    return filteredCount;
  }

  int get _totalRevenue {
    final filteredRev = _filteredTransactions.fold<int>(
      0,
      (sum, t) => sum + ((t['amount'] as num?)?.toInt() ?? 0),
    );
    if (filteredRev > 0) return filteredRev;
    if (_transactions.isEmpty) {
      return (_stats['omzet'] as int?) ?? 0;
    }
    return filteredRev;
  }

  List<Map<String, dynamic>> get _topCategories {
    final Map<String, Map<String, dynamic>> catMap = {};
    for (final t in _filteredTransactions) {
      final items = t['cartItems'] as List? ?? [];
      if (items.isNotEmpty) {
        for (final item in items) {
          if (item is Map) {
            final String pName = (item['name'] ?? '').toString();
            final int qty = (item['qty'] as num?)?.toInt() ?? (item['quantity'] as num?)?.toInt() ?? 1;
            final int price = (item['price'] as num?)?.toInt() ?? (item['unit_price'] as num?)?.toInt() ?? 0;
            String cat = (item['category'] ?? '').toString();
            if (cat.isEmpty) {
              final match = _products.firstWhere(
                (p) => (p['name'] as String? ?? '').toLowerCase() == pName.toLowerCase(),
                orElse: () => <String, dynamic>{},
              );
              cat = (match['category'] ?? match['jenis'] ?? 'Umum').toString();
            }
            if (cat.isEmpty) cat = 'Umum';
            final entry = catMap[cat] ?? {'category': cat, 'qty': 0, 'revenue': 0};
            entry['qty'] = (entry['qty'] as int) + qty;
            entry['revenue'] = (entry['revenue'] as int) + (price * qty);
            catMap[cat] = entry;
          }
        }
      } else {
        final int amount = (t['amount'] as num?)?.toInt() ?? 0;
        if (amount > 0) {
          final entry = catMap['Penjualan Umum'] ?? {'category': 'Penjualan Umum', 'qty': 1, 'revenue': 0};
          entry['qty'] = (entry['qty'] as int) + 1;
          entry['revenue'] = (entry['revenue'] as int) + amount;
          catMap['Penjualan Umum'] = entry;
        }
      }
    }
    final list = catMap.values.toList()
      ..sort((a, b) => (b['revenue'] as int).compareTo(a['revenue'] as int));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildHeader(),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildTabButtons(),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _showAnalytics
                  ? Container(
                      width: double.infinity,
                      color: const Color(0xFFF8F9FA),
                      child: const AnalyticsView(),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFF1E874B),
                      onRefresh: _loadOverviewData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildOverviewSection(),
                              const SizedBox(height: 24),
                              _buildTopSellingSection(),
                              const SizedBox(height: 24),
                              _buildRecentActivitySection(),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          key: const ValueKey('overview_profile_header'),
          onTap: () {
            NavigationService.navigateTo(4); // P4: Navigasi ke Pengaturan Profil
          },
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded, color: Color(0xFF1E874B), size: 28),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selamat Datang!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Level 12',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      const Text('2,564', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabButtons() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(child: _tabButton('Overview', active: !_showAnalytics)),
          Expanded(child: _tabButton('Analytics', active: _showAnalytics)),
        ],
      ),
    );
  }

  Widget _tabButton(String label, {required bool active}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final target = label == 'Analytics';
        if (_showAnalytics == target) return;
        setState(() => _showAnalytics = target);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: active
              ? const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.black : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewSection() {
    final orders = _totalOrders;
    final revenue = _totalRevenue;
    final ordersGrowth = orders > 0 ? '+${(orders * 10).clamp(10, 100)}%' : '0%';
    final revenueGrowth = revenue > 0 ? '+100%' : '0%';

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            PopupMenuButton<String>(
              initialValue: _selectedOverviewPeriod,
              onSelected: (val) {
                setState(() {
                  _selectedOverviewPeriod = val;
                });
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              itemBuilder: (ctx) => _overviewPeriodOptions.map((opt) {
                final isSel = opt == _selectedOverviewPeriod;
                return PopupMenuItem<String>(
                  value: opt,
                  child: Row(
                    children: [
                      Icon(
                        isSel ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 16,
                        color: isSel ? const Color(0xFF1E874B) : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        opt,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          color: isSel ? const Color(0xFF1E874B) : const Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Text(
                      _selectedOverviewPeriod,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E5F5), // Light purple background
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total orders', style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$orders',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        ordersGrowth,
                        style: const TextStyle(color: Colors.purple, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.bottomRight,
                      child: Icon(Icons.card_giftcard, color: Colors.purple, size: 48),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9), // Light green background
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total revenue', style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _formatRp(revenue),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        revenueGrowth,
                        style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.bottomRight,
                      child: Icon(Icons.monetization_on_outlined, color: Colors.orange, size: 48),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopSellingSection() {
    final categories = _topCategories;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Top-selling categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            GestureDetector(
              onTap: () => NavigationService.navigateTo(1),
              child: const Text('View all', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (categories.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Belum ada data', style: TextStyle(color: Colors.grey, fontSize: 14)),
            ),
          )
        else
          Column(
            children: categories.take(4).map((cat) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F5E9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.category_outlined, color: Color(0xFF1E874B), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat['category'].toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              '${cat['qty']} item terjual',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      _formatRp(cat['revenue'] as int),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E874B),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildRecentActivitySection() {
    final recent = _filteredTransactions.take(5).toList();
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            GestureDetector(
              onTap: () => NavigationService.navigateTo(3),
              child: const Text('View all', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (recent.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Belum ada aktivitas', style: TextStyle(color: Colors.grey, fontSize: 14)),
            ),
          )
        else
          Column(
            children: recent.map((trx) {
              final String id = (trx['id'] ?? 'TRX').toString();
              final String items = (trx['items'] ?? 'Transaksi Penjualan').toString();
              final String method = (trx['method'] ?? 'Tunai').toString();
              final String time = (trx['time'] ?? '-').toString();
              final int amount = (trx['amount'] as num?)?.toInt() ?? 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEDE9FE),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.receipt_long_outlined, color: Color(0xFF7C3AED), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  items,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '#$id • $method • $time',
                                  style: const TextStyle(color: Colors.grey, fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatRp(amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E874B),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}