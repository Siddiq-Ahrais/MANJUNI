import 'package:flutter/material.dart';

import 'pages/keranjang_page.dart';
import 'pages/produk_page.dart';
import 'pages/transaksi_page.dart';
import 'pages/profil_page.dart';
import 'services/api_config.dart';
import 'services/api_service.dart';
import 'services/cart_service.dart';
import 'widgets/custom_app_bar.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Toko Kasir',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF164E2E),
          primary: const Color(0xFF164E2E),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.of(context).textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.15,
            ),
          ),
          child: child!,
        );
      },
      home: const MainShell(),
    );
  }
}

// ─────────────────────────────────────────────
// MAIN SHELL - Shared bottom nav controller
// ─────────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    ApiService.testConnection();
  }

  static const List<Widget> _pages = [
    DashboardPage(),
    ProdukPage(),
    KeranjangPage(),
    TransaksiPage(),
    ProfilPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
        child: ValueListenableBuilder<List<CartItem>>(
          valueListenable: CartService.cartNotifier,
          builder: (context, cartItems, _) {
            final cartCount = CartService.typesCount;

            return BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (i) => setState(() => _selectedIndex = i),
              type: BottomNavigationBarType.fixed,
              selectedItemColor: const Color(0xFF1E874B),
              unselectedItemColor: const Color(0xFF6B7280),
              backgroundColor: Colors.white,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 11,
              ),
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart_rounded, size: 24),
                  activeIcon: Icon(Icons.bar_chart_rounded, size: 24),
                  label: 'Dashboard',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.grid_view_rounded, size: 22),
                  activeIcon: Icon(Icons.grid_view_rounded, size: 22),
                  label: 'Produk',
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.shopping_cart_outlined, size: 24),
                      if (cartCount > 0)
                        Positioned(
                          right: -6,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Color(0xFFDC2626),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '$cartCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  activeIcon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.shopping_cart_rounded, size: 24),
                      if (cartCount > 0)
                        Positioned(
                          right: -6,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Color(0xFFDC2626),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '$cartCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: 'Keranjang',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.receipt_long_outlined, size: 23),
                  activeIcon: Icon(Icons.receipt_long_rounded, size: 23),
                  label: 'Transaksi',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline_rounded, size: 24),
                  activeIcon: Icon(Icons.person_rounded, size: 24),
                  label: 'Profil',
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
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
    'omzet': 520000,
    'total_transaksi': 18,
    'produk_terlaris': 'Beras 5kg',
    'stok_menipis': 3,
    'total_produk': 48,
  };

  List<Map<String, dynamic>> _lowStockList = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
    ApiConfig.baseUrlNotifier.addListener(_onUrlChanged);
    ApiService.dataChangedNotifier.addListener(_onDataChanged);
  }

  @override
  void dispose() {
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
      _lowStockList = products.where((p) => p['low'] == true || (p['stock'] as int? ?? 0) <= 5).map((p) {
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
        subtitle: 'Toko Anda \u2022 Mode Offline',
      ),
      body: RefreshIndicator(
        color: kGreen,
        onRefresh: () async {
          await _loadStats();
          await ApiService.testConnection();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting Header (matching screenshot)
              const Text(
                'Halo, Selamat Datang!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              const Row(
                children: [
                  Text(
                    'Hari Ini \u2022 Mode Offline ',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  Icon(
                    Icons.access_time_filled,
                    size: 14,
                    color: Color(0xFF9CA3AF),
                  ),
                ],
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
                        const Text(
                          'Grafik Penjualan 7 Hari',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF111827),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.calendar_month,
                                size: 14,
                                color: Color(0xFF1E874B),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Okt 2024',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(
                                Icons.keyboard_arrow_down,
                                size: 16,
                                color: Color(0xFF4B5563),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 110,
                      width: double.infinity,
                      child: CustomPaint(painter: _SalesChartPainter()),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _DayLabel('Sen'),
                        _DayLabel('Sel'),
                        _DayLabel('Rab'),
                        _DayLabel('Kam'),
                        _DayLabel('Jum'),
                        _DayLabel('Sab'),
                        _DayLabel('Min'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
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
                          'Rata-rata: Rp480rb',
                          style: TextStyle(
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
// DAY LABEL
// ─────────────────────────────────────────────
class _DayLabel extends StatelessWidget {
  final String day;
  const _DayLabel(this.day);

  @override
  Widget build(BuildContext context) {
    return Text(
      day,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: Color(0xFF4B5563),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SALES CHART PAINTER (Curve matching screenshot)
// ─────────────────────────────────────────────
class _SalesChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 7 data points corresponding to 7 days
    final List<double> data = [0.22, 0.35, 0.33, 0.45, 0.68, 0.55, 0.88];
    final double stepX = size.width / (data.length - 1);
    final List<Offset> points = List.generate(
      data.length,
      (i) => Offset(i * stepX, size.height - (data[i] * (size.height - 18) + 8)),
    );

    // Gradient fill under the curve
    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (int i = 0; i < points.length - 1; i++) {
      final cp1 = Offset((points[i].dx + points[i + 1].dx) / 2, points[i].dy);
      final cp2 = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        points[i + 1].dy,
      );
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
            const Color(0xFF81C784).withValues(alpha: 0.4),
            const Color(0xFF81C784).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Smooth Green Line
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final cp1 = Offset((points[i].dx + points[i + 1].dx) / 2, points[i].dy);
      final cp2 = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        points[i + 1].dy,
      );
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

    // Dots on points (Green dots)
    for (final p in points) {
      canvas.drawCircle(p, 4.2, Paint()..color = const Color(0xFF1E874B));
      canvas.drawCircle(p, 2.0, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

