import 'package:flutter/material.dart';
import '../services/api_config.dart';
import '../services/api_service.dart';
import '../widgets/custom_app_bar.dart';

/// Konten Analytics: diagram statistik penjualan & pembelian.
/// Data diambil dari REST API backend Laravel (/reports/profit-loss
/// dan /dashboard/summary), dengan fallback lokal saat offline.
/// Widget ini bisa ditanam di halaman lain (mis. Overview) maupun
/// dibungkus [AnalyticsPage] sebagai halaman penuh.
class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  static const Color kGreen = Color(0xFF1E874B);
  static const Color kExpense = Color(0xFFDC2626);

  String _selectedTrend = '7 Hari';
  int _selectedPoint = -1;
  bool _isLoading = true;

  // Data dari REST API
  Map<String, dynamic> _profitLoss = {};
  List<dynamic> _trend7 = [];
  List<dynamic> _trend30 = [];
  List<dynamic> _trendMonthly = [];
  List<dynamic> _topProducts = [];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
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
    if (mounted) _loadAnalytics();
  }

  void _onUrlChanged() {
    if (mounted) _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    final results = await Future.wait<Map<String, dynamic>>([
      ApiService.getProfitLossReport(period: 'monthly'),
      ApiService.getSalesTrends(),
    ]);
    if (!mounted) return;
    setState(() {
      _profitLoss = results[0];
      final trends = results[1];
      _trend7 = (trends['trend7'] as List?) ?? [];
      _trend30 = (trends['trend30'] as List?) ?? [];
      _trendMonthly = (trends['monthly'] as List?) ?? [];
      _topProducts = (trends['top_products'] as List?) ?? [];
      _selectedPoint = -1;
      _isLoading = false;
    });
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────
  static int _intOf(dynamic v, [int def = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return def;
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

  String _shortRp(int v) {
    if (v >= 1000000000) {
      final d = v / 1000000000;
      return '${d.toStringAsFixed(d < 10 ? 1 : 0)} M';
    }
    if (v >= 1000000) {
      final d = v / 1000000;
      return '${d.toStringAsFixed(d < 10 ? 1 : 0)} jt';
    }
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)} rb';
    return '$v';
  }

  String _formatSold(int v) => '$v terjual';

  Map<String, dynamic> get _summary =>
      ((_profitLoss['summary'] as Map?) ?? {}).cast<String, dynamic>();

  int get _revenue => _intOf(_summary['revenue']);
  int get _purchases => _intOf(_summary['operational_expenses']);
  int get _netProfit => _intOf(_summary['net_profit']);
  int get _grossProfit => _intOf(_summary['gross_profit'], _revenue - _cogs);
  int get _trxCount => _intOf(_summary['transactions_count']);
  int get _cogs => _intOf(_summary['cogs']);

  double get _grossMargin {
    if (_revenue <= 0) return 0;
    return ((_revenue - _cogs) / _revenue) * 100;
  }

  double get _markupPercentage {
    if (_cogs <= 0) return 0;
    return ((_revenue - _cogs) / _cogs) * 100;
  }

  List<dynamic> get _expenseCategories =>
      (_profitLoss['expense_categories'] as List?) ?? [];

  String get _rangeLabel {
    final s = _profitLoss['start_date']?.toString() ?? '';
    final e = _profitLoss['end_date']?.toString() ?? '';
    if (s.isEmpty || e.isEmpty) return 'Bulan ini';
    return '$s s/d $e';
  }

  // ─────────────────────────────────────────────
  // SERIES BUILDER (isi hari/bulan kosong dengan 0)
  // ─────────────────────────────────────────────
  List<_TrendPoint> _buildSeries() {
    if (_selectedTrend == '7 Hari') return _fillDaily(_trend7, 7);
    if (_selectedTrend == '30 Hari') return _fillDaily(_trend30, 30);
    return _fillMonthly(_trendMonthly, 6);
  }

  List<_TrendPoint> _fillDaily(List<dynamic> raw, int days) {
    final now = DateTime.now();
    final totals = <String, int>{};
    for (final row in raw) {
      if (row is Map) {
        final d = row['date']?.toString() ?? '';
        if (d.isNotEmpty) {
          totals[d] = _intOf(row['sold'], _intOf(row['total']));
        }
      }
    }
    const dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return List.generate(days, (i) {
      final date = now.subtract(Duration(days: days - 1 - i));
      final key = date.toIso8601String().substring(0, 10);
      return _TrendPoint(
        label: days <= 7 ? dayNames[date.weekday - 1] : '${date.day}',
        value: totals[key] ?? 0,
      );
    });
  }

  List<_TrendPoint> _fillMonthly(List<dynamic> raw, int months) {
    final now = DateTime.now();
    final totals = <String, int>{};
    for (final row in raw) {
      if (row is Map) {
        final m = row['month']?.toString() ?? '';
        if (m.isNotEmpty) {
          totals[m] = _intOf(row['sold'], _intOf(row['total']));
        }
      }
    }
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return List.generate(months, (i) {
      final m = DateTime(now.year, now.month - (months - 1 - i));
      final key =
          '${m.year}-${m.month.toString().padLeft(2, '0')}';
      return _TrendPoint(label: monthNames[m.month - 1], value: totals[key] ?? 0);
    });
  }

  void _selectTrendPointByX(double dx, double width) {
    final series = _buildSeries();
    if (series.isEmpty) return;
    final stepX = width / series.length;
    final index = ((dx / stepX).floor()).clamp(0, series.length - 1);
    if (_selectedPoint != index) {
      setState(() => _selectedPoint = index);
    }
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: kGreen))
        : RefreshIndicator(
            color: kGreen,
            onRefresh: _loadAnalytics,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ringkasan periode berjalan
                  _buildStatCards(),
                  const SizedBox(height: 16),
                  _buildCompareCard(),
                  const SizedBox(height: 16),
                  _buildTrendCard(),
                  const SizedBox(height: 16),
                  _buildCategoryCard(),
                  const SizedBox(height: 16),
                  _buildTopProductsCard(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
  }

  // ─────────────────────────────────────────────
  // 1. KARTU STATISTIK RINGKASAN
  // ─────────────────────────────────────────────
  Widget _buildStatCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.trending_up_rounded,
                iconBg: const Color(0xFFD1F2D9),
                iconColor: kGreen,
                title: 'Penjualan',
                value: _formatRp(_revenue),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                icon: Icons.shopping_bag_outlined,
                iconBg: const Color(0xFFFFE0B2),
                iconColor: const Color(0xFFD97706),
                title: 'Pembelian',
                value: _formatRp(_purchases),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.account_balance_wallet_outlined,
                iconBg: _netProfit >= 0
                    ? const Color(0xFFD9E6FF)
                    : const Color(0xFFFFCDD2),
                iconColor: _netProfit >= 0
                    ? const Color(0xFF2563EB)
                    : kExpense,
                title: 'Laba Bersih',
                value: _formatRp(_netProfit),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                icon: Icons.receipt_long_outlined,
                iconBg: const Color(0xFFEDE9FE),
                iconColor: const Color(0xFF7C3AED),
                title: 'Transaksi',
                value: '$_trxCount Transaksi',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
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
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 2. DIAGRAM BATANG: PENJUALAN vs PEMBELIAN
  // ─────────────────────────────────────────────
  Widget _buildCompareCard() {
    return _sectionCard(
      title: 'Penjualan vs Pembelian',
      subtitle: _rangeLabel,
      child: Column(
        children: [
          SizedBox(
            height: 170,
            width: double.infinity,
            child: CustomPaint(
              painter: _CompareBarPainter(
                sales: _revenue,
                purchases: _purchases,
                formatValue: _shortRp,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(const Color(0xFF1E874B), 'Penjualan'),
              const SizedBox(width: 20),
              _legendDot(kExpense, 'Pembelian'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Margin Kotor: ${_grossMargin.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _netProfit >= 0
                            ? 'Laba: ${_shortRp(_netProfit)}'
                            : 'Rugi: ${_shortRp(-_netProfit)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _netProfit >= 0 ? kGreen : kExpense,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Markup (vs HPP): ${_markupPercentage.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Laba Kotor: ${_shortRp(_grossProfit)} (HPP: ${_shortRp(_cogs)})',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4B5563),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // 3. DIAGRAM GARIS: TREN PENJUALAN (PRODUK TERJUAL PER HARI)
  // ─────────────────────────────────────────────
  Widget _buildTrendCard() {
    final series = _buildSeries();
    int peakIndex = -1;
    int maxSold = 0;
    for (int i = 0; i < series.length; i++) {
      if (series[i].value > maxSold) {
        maxSold = series[i].value;
        peakIndex = i;
      }
    }
    final activePoint = _selectedPoint >= 0 ? _selectedPoint : peakIndex;

    return _sectionCard(
      title: 'Tren Penjualan',
      subtitle: 'Periode $_selectedTrend • Produk Terjual',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pilih periode
          Row(
            children: [
              _trendChip('7 Hari'),
              const SizedBox(width: 8),
              _trendChip('30 Hari'),
              const SizedBox(width: 8),
              _trendChip('6 Bulan'),
            ],
          ),
          if (peakIndex >= 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department_rounded,
                      size: 14, color: kGreen),
                  const SizedBox(width: 6),
                  Text(
                    'Terbanyak: ${series[peakIndex].label} (${_formatSold(series[peakIndex].value)})',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: kGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => _selectTrendPointByX(
                  details.localPosition.dx,
                  constraints.maxWidth,
                ),
                onPanUpdate: (details) => _selectTrendPointByX(
                  details.localPosition.dx,
                  constraints.maxWidth,
                ),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _TrendLinePainter(
                      points: series,
                      selectedIndex: activePoint,
                      formatValue: _formatSold,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          // Label sumbu-x
          Row(
            children: List.generate(series.length, (i) {
              final show =
                  series.length <= 8 || i % 5 == 0 || i == series.length - 1;
              return Expanded(
                child: Text(
                  show ? series[i].label : '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: series.length <= 8 ? 11 : 9,
                    fontWeight: activePoint == i ? FontWeight.bold : FontWeight.w500,
                    color: activePoint == i ? kGreen : const Color(0xFF4B5563),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _trendChip(String label) {
    final isSelected = _selectedTrend == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedTrend == label) return;
          setState(() {
            _selectedTrend = label;
            _selectedPoint = -1;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE8F5E9) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? kGreen : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? kGreen : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 4. KOMPOSISI PEMBELIAN PER KATEGORI
  // ─────────────────────────────────────────────
  Widget _buildCategoryCard() {
    final cats = _expenseCategories.take(6).toList();
    return _sectionCard(
      title: 'Komposisi Pembelian',
      subtitle: 'Berdasarkan kategori beban',
      child: cats.isEmpty
          ? _emptyHint('Belum ada data pembelian pada periode ini.')
          : Column(
              children: cats.map((c) {
                final name = c is Map ? (c['category']?.toString() ?? '-') : '-';
                final total = c is Map ? _intOf(c['total']) : 0;
                final pct = c is Map
                    ? ((c['percentage'] as num?)?.toDouble() ?? 0.0)
                    : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_formatRp(total)} (${pct.toStringAsFixed(1)}%)',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          height: 8,
                          color: const Color(0xFFF1F5F9),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: (pct / 100).clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: kExpense,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ─────────────────────────────────────────────
  // 5. PRODUK TERLARIS
  // ─────────────────────────────────────────────
  Widget _buildTopProductsCard() {
    return _sectionCard(
      title: 'Produk Terlaris',
      subtitle: '30 hari terakhir',
      child: _topProducts.isEmpty
          ? _emptyHint('Belum ada penjualan produk tercatat.')
          : Column(
              children: List.generate(_topProducts.length, (i) {
                final p = _topProducts[i];
                if (p is! Map) return const SizedBox.shrink();
                final name = p['name']?.toString() ?? 'Produk';
                final sold = _intOf(p['total_sold']);
                final revenue = _intOf(p['total_revenue']);
                final rank = i + 1;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: rank <= 3 ? kGreen : const Color(0xFFE5E7EB),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: rank <= 3 ? Colors.white : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$sold terjual',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatRp(revenue),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: kGreen,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Halaman Analytics penuh (dipakai di shell desktop): Scaffold dengan
/// CustomAppBar yang membungkus [AnalyticsView].
class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const CustomAppBar(title: 'Analytics'),
      body: const AnalyticsView(),
    );
  }
}

// ─────────────────────────────────────────────
// MODEL TITIK TREN
// ─────────────────────────────────────────────
class _TrendPoint {
  final String label;
  final int value;
  const _TrendPoint({required this.label, required this.value});
}

// ─────────────────────────────────────────────
// PAINTER: DIAGRAM GARIS TREN PENJUALAN
// ─────────────────────────────────────────────
class _TrendLinePainter extends CustomPainter {
  final List<_TrendPoint> points;
  final int selectedIndex;
  final String Function(int) formatValue;

  _TrendLinePainter({
    required this.points,
    required this.selectedIndex,
    required this.formatValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final maxValue = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    const double topPadding = 30;
    const double bottomPadding = 8;
    final double usable = size.height - topPadding - bottomPadding;

    final List<Offset> offsets = List.generate(points.length, (i) {
      final double x = points.length == 1
          ? size.width / 2
          : i * size.width / (points.length - 1);
      final frac = maxValue > 0 ? points[i].value / maxValue : 0.0;
      final y = topPadding + usable - (frac * (usable - 10) + 6);
      return Offset(x, y);
    });

    // Gradient fill di bawah kurva
    final fillPath = Path()..moveTo(offsets.first.dx, size.height);
    for (int i = 0; i < offsets.length - 1; i++) {
      final cp1 = Offset((offsets[i].dx + offsets[i + 1].dx) / 2, offsets[i].dy);
      final cp2 = Offset((offsets[i].dx + offsets[i + 1].dx) / 2, offsets[i + 1].dy);
      fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, offsets[i + 1].dx, offsets[i + 1].dy);
    }
    fillPath
      ..lineTo(offsets.last.dx, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF81C784).withValues(alpha: 0.38),
            const Color(0xFF81C784).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Garis kurva
    final linePath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (int i = 0; i < offsets.length - 1; i++) {
      final cp1 = Offset((offsets[i].dx + offsets[i + 1].dx) / 2, offsets[i].dy);
      final cp2 = Offset((offsets[i].dx + offsets[i + 1].dx) / 2, offsets[i + 1].dy);
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, offsets[i + 1].dx, offsets[i + 1].dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = const Color(0xFF1E874B)
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Titik-titik
    for (int i = 0; i < offsets.length; i++) {
      final p = offsets[i];
      final isSelected = i == selectedIndex;
      if (isSelected) {
        canvas.drawCircle(
          p, 8.5, Paint()..color = const Color(0xFF1E874B).withValues(alpha: 0.22));
        canvas.drawCircle(p, 5.5, Paint()..color = const Color(0xFF1E874B));
        canvas.drawCircle(p, 2.6, Paint()..color = Colors.white);
      } else {
        canvas.drawCircle(p, 3.8, Paint()..color = const Color(0xFF1E874B));
        canvas.drawCircle(p, 1.8, Paint()..color = Colors.white);
      }
    }

    // Tooltip nilai untuk titik terpilih
    if (selectedIndex >= 0 && selectedIndex < offsets.length) {
      final p = offsets[selectedIndex];
      final valueText = formatValue(points[selectedIndex].value);
      final tp = TextPainter(
        text: TextSpan(
          text: valueText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      const double hPadding = 8, vPadding = 4, arrowHeight = 4.5, gap = 4;
      final tooltipWidth = tp.width + hPadding * 2;
      final tooltipHeight = tp.height + vPadding * 2;
      final centerX = p.dx.clamp(tooltipWidth / 2 + 2, size.width - tooltipWidth / 2 - 2);
      final tooltipLeft = centerX - tooltipWidth / 2;
      final tooltipTop = (p.dy - gap - arrowHeight - tooltipHeight).clamp(0.0, size.height);
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tooltipLeft, tooltipTop, tooltipWidth, tooltipHeight),
        const Radius.circular(6),
      );
      canvas.drawRRect(rrect, Paint()..color = const Color(0xFF0F172A));
      tp.paint(canvas, Offset(tooltipLeft + hPadding, tooltipTop + vPadding));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

// ─────────────────────────────────────────────
// PAINTER: DIAGRAM BATANG PENJUALAN vs PEMBELIAN
// ─────────────────────────────────────────────
class _CompareBarPainter extends CustomPainter {
  final int sales;
  final int purchases;
  final String Function(int) formatValue;

  _CompareBarPainter({
    required this.sales,
    required this.purchases,
    required this.formatValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final int maxV = sales > purchases ? sales : purchases;
    const double barWidth = 46;
    final double usable = size.height - 30;
    final double baseY = size.height - 4;

    void drawBar(double centerX, int value, Color color, bool highlightTop) {
      final frac = maxV > 0 ? value / maxV : 0.0;
      final double h = (frac * (usable - 10) + 6).clamp(6.0, usable);
      final rrect = RRect.fromRectAndCorners(
        Rect.fromLTWH(centerX - barWidth / 2, baseY - h, barWidth, h),
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
      );

      // Bayangan halus
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.04)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawRRect(rrect, Paint()..color = color);

      // Label nilai di atas batang
      final tp = TextPainter(
        text: TextSpan(
          text: formatValue(value),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: highlightTop ? const Color(0xFF166534) : const Color(0xFFB91C1C),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(centerX - tp.width / 2, baseY - h - tp.height - 8));
    }

    drawBar(size.width * 0.28, sales, const Color(0xFF1E874B), true);
    drawBar(size.width * 0.72, purchases, const Color(0xFFDC2626), false);

    // Garis dasar
    canvas.drawLine(
      Offset(16, baseY),
      Offset(size.width - 16, baseY),
      Paint()
        ..color = const Color(0xFFE5E7EB)
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _CompareBarPainter oldDelegate) {
    return oldDelegate.sales != sales || oldDelegate.purchases != purchases;
  }
}
