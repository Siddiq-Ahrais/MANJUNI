import 'package:flutter/material.dart';

import 'app.dart';
import 'services/api_config.dart';
import 'services/api_service.dart';
import 'widgets/custom_app_bar.dart';

export 'app.dart';
export 'shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Muat produk & data yang tersimpan di perangkat agar tetap ada
  // saat aplikasi dibuka kembali setelah ditutup / user keluar.
  await ApiService.loadLocalData();
  runApp(const MyApp());
}

// ─────────────────────────────────────────────
// DASHBOARD PAGE (Fitted for Android Screens)
// ─────────────────────────────────────────────
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const Color kGreen = Color(0xFF164E2E);
  final PageController _pageController = PageController();
  int _carouselPage = 0;

  Map<String, dynamic> _stats = {
    'omzet': 0,
    'total_transaksi': 0,
    'produk_terlaris': '-',
    'stok_menipis': 0,
    'total_produk': 0,
  };

  List<Map<String, dynamic>> _lowStockList = [];

  // Sales Chart & Floating Calendar Filter State
  final LayerLink _calendarLayerLink = LayerLink();
  OverlayEntry? _calendarOverlayEntry;
  bool _isCalendarOpen = false;

  String _selectedPeriodLabel = 'Okt 2024';
  int _selectedYear = 2024;
  int _selectedMonthIndex = 9; // 0=Jan..9=Okt
  int _selectedPointIndex = 4; // Default highlight: 'Jum' (Friday)

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  // Dynamic chart data per period
  List<double> _chartFractions = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  List<int> _chartValues = [0, 0, 0, 0, 0, 0, 0];
  List<String> _chartDays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  String _chartAvg = 'Rp0';
  String _chartTitle = 'Grafik Penjualan 7 Hari';

  @override
  void initState() {
    super.initState();
    _loadStats();
    ApiConfig.baseUrlNotifier.addListener(_onUrlChanged);
    ApiService.dataChangedNotifier.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _closeCalendarPopup();
    _pageController.dispose();
    ApiConfig.baseUrlNotifier.removeListener(_onUrlChanged);
    ApiService.dataChangedNotifier.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _loadStats();
  }

  void _onUrlChanged() {
    if (mounted) _loadStats();
  }

  Future<void> _loadStats() async {
    final data = await ApiService.getDashboardStats();
    final products = await ApiService.getProducts();
    
    if (!mounted) return;
    setState(() {
      _stats = data;
      _lowStockList = products.where((p) => ApiService.isLowStock(p)).map((p) {
        return {
          'name': p['name'],
          'remaining': p['stock'],
          'unit': p['unit'] ?? 'pcs',
          'icon': Icons.inventory_2_outlined,
          'color': const Color(0xFFFFCDD2),
          'iconColor': const Color(0xFFDC2626),
        };
      }).toList();
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

  void _handleRestock(int index) {
    final item = _lowStockList[index];
    final ctrl = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Restock ${item['name']}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stok saat ini: ${item['remaining']} ${item['unit']}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Jumlah Tambahan Stok (${item['unit']})',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final added = int.tryParse(ctrl.text.trim()) ?? 0;
              if (added > 0) {
                setState(() {
                  _lowStockList[index]['remaining'] =
                      (_lowStockList[index]['remaining'] as int) + added;
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Stok ${item['name']} berhasil ditambah $added!'),
                    backgroundColor: kGreen,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tambah Stok'),
          ),
        ],
      ),
    );
  }

  void _selectChartPointByX(double dx, double width) {
    if (_chartFractions.isEmpty) return;
    final double stepX = width / (_chartFractions.length - 1);
    final int index =
        ((dx + stepX / 2) / stepX).floor().clamp(0, _chartFractions.length - 1);
    if (_selectedPointIndex != index) {
      setState(() {
        _selectedPointIndex = index;
      });
    }
  }

  void _selectPeriodOption(String type) {
    setState(() {
      if (type == '7 Hari') {
        _selectedPeriodLabel = '7 Hari';
        _chartTitle = 'Grafik Penjualan 7 Hari';
        _chartDays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
        _chartFractions = [0.22, 0.35, 0.33, 0.45, 0.68, 0.55, 0.88];
        _chartValues = [220000, 350000, 330000, 450000, 680000, 550000, 880000];
        _chartAvg = 'Rp480rb';
        _selectedPointIndex = 4;
      } else if (type == '30 Hari') {
        _selectedPeriodLabel = '30 Hari';
        _chartTitle = 'Grafik Penjualan 30 Hari';
        _chartDays = ['Mgg 1', 'Mgg 2', 'Mgg 3', 'Mgg 4'];
        _chartFractions = [0.40, 0.65, 0.55, 0.82];
        _chartValues = [2800000, 4500000, 3900000, 5800000];
        _chartAvg = 'Rp4,2jt';
        _selectedPointIndex = 3;
      } else {
        _selectedYear = 2024;
        _selectedMonthIndex = 9;
        _selectedPeriodLabel = 'Okt 2024';
        _chartTitle = 'Grafik Penjualan Okt 2024';
        _chartDays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
        _chartFractions = [0.22, 0.35, 0.33, 0.45, 0.68, 0.55, 0.88];
        _chartValues = [220000, 350000, 330000, 450000, 680000, 550000, 880000];
        _chartAvg = 'Rp480rb';
        _selectedPointIndex = 4;
      }
    });
    _closeCalendarPopup();
  }

  void _selectMonth(int monthIndex) {
    setState(() {
      _selectedMonthIndex = monthIndex;
      final mName = _monthNames[monthIndex];
      _selectedPeriodLabel = '$mName $_selectedYear';
      _chartTitle = 'Grafik Penjualan $mName $_selectedYear';
      _chartDays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
      if (monthIndex == 8) {
        _chartFractions = [0.20, 0.30, 0.35, 0.40, 0.58, 0.50, 0.75];
        _chartValues = [180000, 290000, 310000, 420000, 590000, 510000, 750000];
        _chartAvg = 'Rp435rb';
      } else {
        _chartFractions = [0.25, 0.38, 0.30, 0.48, 0.62, 0.58, 0.80];
        _chartValues = [250000, 380000, 300000, 480000, 620000, 580000, 800000];
        _chartAvg = 'Rp487rb';
      }
      _selectedPointIndex = 4;
    });
    _closeCalendarPopup();
  }

  Future<void> _pickCustomDateRange() async {
    _closeCalendarPopup();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime(2027, 12, 31),
      initialDateRange: DateTimeRange(
        start: DateTime(2024, 10, 1),
        end: DateTime(2024, 10, 7),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF164E2E),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF111827),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      final startStr = '${picked.start.day} ${_monthNames[picked.start.month - 1]}';
      final endStr = '${picked.end.day} ${_monthNames[picked.end.month - 1]}';
      setState(() {
        _selectedPeriodLabel = '$startStr - $endStr';
        _chartTitle = 'Grafik Penjualan $startStr - $endStr';
      });
    }
  }

  void _openCalendarPopup() {
    _closeCalendarPopup();

    _calendarOverlayEntry = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeCalendarPopup,
              ),
            ),
            Positioned(
              child: CompositedTransformFollower(
                link: _calendarLayerLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomRight,
                followerAnchor: Alignment.topRight,
                offset: const Offset(0, 8),
                child: Material(
                  color: Colors.transparent,
                  child: StatefulBuilder(
                    builder: (context, setPopupState) {
                      return _buildFloatingCalendarCard(setPopupState);
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_calendarOverlayEntry!);
    setState(() {
      _isCalendarOpen = true;
    });
  }

  void _closeCalendarPopup() {
    if (_calendarOverlayEntry != null) {
      _calendarOverlayEntry!.remove();
      _calendarOverlayEntry = null;
      if (mounted) {
        setState(() {
          _isCalendarOpen = false;
        });
      }
    }
  }

  void _toggleCalendarPopup() {
    if (_isCalendarOpen) {
      _closeCalendarPopup();
    } else {
      _openCalendarPopup();
    }
  }

  Widget _buildFloatingCalendarCard(StateSetter setPopupState) {
    return Container(
      width: 295,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 15,
                      color: Color(0xFF1E874B),
                    ),
                    SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Pilih Periode',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setPopupState(() {
                          _selectedYear--;
                        });
                      },
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        size: 18,
                        color: Color(0xFF334155),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '$_selectedYear',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setPopupState(() {
                          _selectedYear++;
                        });
                      },
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildQuickChip('7 Hari'),
              const SizedBox(width: 6),
              _buildQuickChip('30 Hari'),
              const SizedBox(width: 6),
              _buildQuickChip('Bulan Ini'),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 12,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.4,
            ),
            itemBuilder: (ctx, idx) {
              final isSelected = idx == _selectedMonthIndex &&
                  _selectedPeriodLabel.contains(_monthNames[idx]) &&
                  _selectedPeriodLabel.contains('$_selectedYear');
              return GestureDetector(
                onTap: () => _selectMonth(idx),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF164E2E)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF164E2E)
                          : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _monthNames[idx],
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF334155),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickCustomDateRange,
            behavior: HitTestBehavior.opaque,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.date_range_outlined,
                  size: 14,
                  color: Color(0xFF1E874B),
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Pilih Rentang Tanggal...',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E874B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label) {
    final bool isSelected = _selectedPeriodLabel == label ||
        (label == 'Bulan Ini' && _selectedPeriodLabel.contains('Okt'));

    return Expanded(
      child: GestureDetector(
        onTap: () => _selectPeriodOption(label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFE8F5E9)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF1E874B)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? const Color(0xFF164E2E)
                  : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int omzet = (_stats['omzet'] as int?) ?? 0;
    final int totalTrx = (_stats['total_transaksi'] as int?) ?? 0;
    final String bestSeller =
        ((_stats['produk_terlaris'] as String?)?.isNotEmpty == true &&
                _stats['produk_terlaris'] != '-')
            ? _stats['produk_terlaris'] as String
            : '-';
    final int lowStock = (_stats['stok_menipis'] as int?) ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const CustomAppBar(
        title: 'Dashboard',
      ),
      body: RefreshIndicator(
        color: kGreen,
        onRefresh: () async {
          await _loadStats();
          await ApiService.testConnection();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting Header (pas tepat di bawah title navbar 'Dashboard')
              const Text(
                'Halo, Selamat Datang!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 16),

              // ─────────────────────────────────────────────────────────────
              // METRICS CARD (100% Fitted for Android - Exact Match to Screenshot)
              // 2-Slide Swipeable Carousel with [━━] [━] Pill Indicator
              // Slide 1: Omzet Hari Ini & Jumlah Transaksi
              // Slide 2: Produk Terlaris & Stok Menipis
              // ─────────────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
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
                  children: [
                    SizedBox(
                      height: 118,
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (idx) => setState(() => _carouselPage = idx),
                        children: [
                          // Slide 1: Omzet Hari Ini & Jumlah Transaksi
                          Row(
                            children: [
                              Expanded(
                                child: _MetricItem(
                                  icon: Icons.account_balance_wallet_outlined,
                                  iconBg: const Color(0xFFD1F2D9),
                                  iconColor: const Color(0xFF1E874B),
                                  title: 'Omzet Hari Ini',
                                  value: _formatRp(omzet),
                                ),
                              ),
                              Expanded(
                                child: _MetricItem(
                                  icon: Icons.receipt_long_outlined,
                                  iconBg: const Color(0xFFD9E6FF),
                                  iconColor: const Color(0xFF2563EB),
                                  title: 'Jumlah Transaksi',
                                  value: '$totalTrx Transaksi',
                                ),
                              ),
                            ],
                          ),

                          // Slide 2: Produk Terlaris & Stok Menipis
                          Row(
                            children: [
                              Expanded(
                                child: _MetricItem(
                                  icon: Icons.inventory_2_outlined,
                                  iconBg: const Color(0xFFFFE0B2),
                                  iconColor: const Color(0xFFD97706),
                                  title: 'Produk Terlaris',
                                  value: bestSeller,
                                ),
                              ),
                              Expanded(
                                child: _MetricItem(
                                  icon: Icons.error_outline_rounded,
                                  iconBg: const Color(0xFFFFCDD2),
                                  iconColor: const Color(0xFFDC2626),
                                  title: 'Stok Menipis',
                                  value: '$lowStock Produk',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Pill Indicators matching screenshot [━━] [━]
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {
                            _pageController.animateToPage(
                              0,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: _carouselPage == 0 ? 32 : 18,
                            height: 5,
                            decoration: BoxDecoration(
                              color: _carouselPage == 0
                                  ? const Color(0xFF164E2E)
                                  : const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            _pageController.animateToPage(
                              1,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: _carouselPage == 1 ? 32 : 18,
                            height: 5,
                            decoration: BoxDecoration(
                              color: _carouselPage == 1
                                  ? const Color(0xFF164E2E)
                                  : const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ─────────────────────────────────────────────────────────────
              // GRAFIK PENJUALAN 7 HARI (matching screenshot)
              // ─────────────────────────────────────────────────────────────
              Container(
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _chartTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF111827),
                          ),
                        ),
                        CompositedTransformTarget(
                          link: _calendarLayerLink,
                          child: GestureDetector(
                            onTap: _toggleCalendarPopup,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: _isCalendarOpen
                                    ? const Color(0xFFF1F5F9)
                                    : Colors.white,
                                border: Border.all(
                                  color: _isCalendarOpen
                                      ? const Color(0xFF164E2E)
                                      : const Color(0xFFE5E7EB),
                                  width: _isCalendarOpen ? 1.5 : 1.0,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.calendar_month,
                                    size: 14,
                                    color: Color(0xFF1E874B),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _selectedPeriodLabel,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    _isCalendarOpen
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    size: 16,
                                    color: const Color(0xFF4B5563),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) {
                            _selectChartPointByX(
                              details.localPosition.dx,
                              constraints.maxWidth,
                            );
                          },
                          onPanUpdate: (details) {
                            _selectChartPointByX(
                              details.localPosition.dx,
                              constraints.maxWidth,
                            );
                          },
                          child: SizedBox(
                            height: 125,
                            width: double.infinity,
                            child: CustomPaint(
                              painter: _SalesChartPainter(
                                data: _chartFractions,
                                values: _chartValues,
                                selectedIndex: _selectedPointIndex,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(_chartDays.length, (idx) {
                        final isSelected = idx == _selectedPointIndex;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedPointIndex = idx;
                            });
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: isSelected
                                ? BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(4),
                                  )
                                : null,
                            child: Text(
                              _chartDays[idx],
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF1E874B)
                                    : const Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            CircleAvatar(
                              radius: 4.5,
                              backgroundColor: Color(0xFF81C784),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Penjualan (Rp)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4B5563),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Rata-rata: $_chartAvg',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ─────────────────────────────────────────────────────────────
              // STOK MENIPIS (Single White Card matching screenshot)
              // ─────────────────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Stok Menipis',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Color(0xFF111827),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate to Produk tab
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Lihat Semua >',
                      style: TextStyle(
                        color: Color(0xFF1E874B),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Container(
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
                  children: _lowStockList.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    final isLast = idx == _lowStockList.length - 1;

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: item['color'] as Color,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  item['icon'] as IconData,
                                  color: item['iconColor'] as Color,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name'] as String,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Stok tersisa: ${item['remaining']} ${item['unit']}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton(
                                onPressed: () => _handleRestock(idx),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1E874B),
                                  side: const BorderSide(
                                    color: Color(0xFF1E874B),
                                    width: 1.2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Restock',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          const Divider(
                            height: 1,
                            thickness: 1,
                            indent: 72,
                            endIndent: 14,
                            color: Color(0xFFF3F4F6),
                          ),
                      ],
                    );
                  }).toList(),
                ),
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
// METRIC ITEM (Circular icon + Title + Bold Value)
// ─────────────────────────────────────────────
class _MetricItem extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String value;

  const _MetricItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF4B5563),
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
                letterSpacing: -0.2,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SALES CHART PAINTER (Curve with Floating Value Tooltip)
// ─────────────────────────────────────────────
class _SalesChartPainter extends CustomPainter {
  final List<double> data;
  final List<int> values;
  final int selectedIndex;

  _SalesChartPainter({
    required this.data,
    required this.values,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Headroom at top for the floating value tooltip
    const double topPadding = 30.0;
    const double bottomPadding = 8.0;
    final double usableHeight = size.height - topPadding - bottomPadding;

    final double stepX = size.width / (data.length - 1);
    final List<Offset> points = List.generate(
      data.length,
      (i) => Offset(
        i * stepX,
        topPadding + usableHeight - (data[i] * (usableHeight - 10) + 5),
      ),
    );

    // Gradient fill under the curve
    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (int i = 0; i < points.length - 1; i++) {
      final cp1 = Offset((points[i].dx + points[i + 1].dx) / 2, points[i].dy);
      final cp2 = Offset((points[i].dx + points[i + 1].dx) / 2, points[i + 1].dy);
      fillPath.cubicTo(
        cp1.dx,
        cp1.dy,
        cp2.dx,
        cp2.dy,
        points[i + 1].dx,
        points[i + 1].dy,
      );
    }
    fillPath
      ..lineTo(size.width, size.height)
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

    // Smooth Green Line
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final cp1 = Offset((points[i].dx + points[i + 1].dx) / 2, points[i].dy);
      final cp2 = Offset((points[i].dx + points[i + 1].dx) / 2, points[i + 1].dy);
      linePath.cubicTo(
        cp1.dx,
        cp1.dy,
        cp2.dx,
        cp2.dy,
        points[i + 1].dx,
        points[i + 1].dy,
      );
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = const Color(0xFF1E874B)
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Dotted vertical guideline for the active selected point
    if (selectedIndex >= 0 && selectedIndex < points.length) {
      final selectedPoint = points[selectedIndex];
      final guidePaint = Paint()
        ..color = const Color(0xFF1E874B).withValues(alpha: 0.30)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      const double dashHeight = 3.5;
      const double dashSpace = 3.0;
      double startY = selectedPoint.dy + 8;
      while (startY < size.height) {
        canvas.drawLine(
          Offset(selectedPoint.dx, startY),
          Offset(selectedPoint.dx, (startY + dashHeight).clamp(0, size.height)),
          guidePaint,
        );
        startY += dashHeight + dashSpace;
      }
    }

    // Dots on points
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final isSelected = i == selectedIndex;

      if (isSelected) {
        // Outer halo glow
        canvas.drawCircle(
          p,
          8.5,
          Paint()..color = const Color(0xFF1E874B).withValues(alpha: 0.22),
        );
        // Outer green dot ring
        canvas.drawCircle(
          p,
          5.5,
          Paint()..color = const Color(0xFF1E874B),
        );
        // Inner white dot
        canvas.drawCircle(
          p,
          2.6,
          Paint()..color = Colors.white,
        );
      } else {
        canvas.drawCircle(p, 4.2, Paint()..color = const Color(0xFF1E874B));
        canvas.drawCircle(p, 2.0, Paint()..color = Colors.white);
      }
    }

    // FLOATING VALUE TOOLTIP (Pill with pointer arrow & shadow)
    if (selectedIndex >= 0 && selectedIndex < points.length) {
      final selectedPoint = points[selectedIndex];
      final int value =
          selectedIndex < values.length ? values[selectedIndex] : 0;
      final String valueText = _formatValue(value);

      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: valueText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      const double hPadding = 8.0;
      const double vPadding = 4.0;
      final double tooltipWidth = tp.width + (hPadding * 2);
      final double tooltipHeight = tp.height + (vPadding * 2);
      const double arrowHeight = 4.5;
      const double arrowWidth = 7.0;
      const double gap = 4.0;

      // Clamp center X so tooltip does not clip left or right
      final double minCenterX = tooltipWidth / 2 + 2;
      final double maxCenterX = size.width - (tooltipWidth / 2) - 2;
      final double tooltipCenterX =
          selectedPoint.dx.clamp(minCenterX, maxCenterX);

      final double tooltipLeft = tooltipCenterX - (tooltipWidth / 2);
      final double tooltipTop =
          (selectedPoint.dy - gap - arrowHeight - tooltipHeight).clamp(0.0, size.height);

      final RRect tooltipRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tooltipLeft, tooltipTop, tooltipWidth, tooltipHeight),
        const Radius.circular(6),
      );

      final double arrowTipX =
          selectedPoint.dx.clamp(tooltipLeft + 6, tooltipLeft + tooltipWidth - 6);
      final double arrowBaseY = tooltipTop + tooltipHeight;
      final Path arrowPath = Path()
        ..moveTo(arrowTipX - arrowWidth / 2, arrowBaseY)
        ..lineTo(arrowTipX, arrowBaseY + arrowHeight)
        ..lineTo(arrowTipX + arrowWidth / 2, arrowBaseY)
        ..close();

      final Path combinedPath = Path()
        ..addRRect(tooltipRRect)
        ..addPath(arrowPath, Offset.zero);

      // Draw soft shadow
      canvas.drawShadow(combinedPath, const Color(0x38000000), 4, false);

      // Draw floating dark slate pill
      final Paint pillPaint = Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(tooltipRRect, pillPaint);
      canvas.drawPath(arrowPath, pillPaint);

      // Draw text centered
      tp.paint(
        canvas,
        Offset(
          tooltipLeft + hPadding,
          tooltipTop + vPadding,
        ),
      );
    }
  }

  static String _formatValue(int v) {
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

  @override
  bool shouldRepaint(covariant _SalesChartPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.data != data ||
        oldDelegate.values != values;
  }
}

