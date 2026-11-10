import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/api_config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/navigation_service.dart';

ImageProvider _getImageProvider(String? source) {
  if (source == null || source.isEmpty) {
    return const NetworkImage(
        'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=600&auto=format&fit=crop&q=80');
  }
  if (source.startsWith('http://') || source.startsWith('https://')) {
    return NetworkImage(source);
  }
  if (source.startsWith('data:image') ||
      (!source.contains(Platform.pathSeparator) && source.length > 300)) {
    try {
      final base64Str = source.contains(',') ? source.split(',').last : source;
      return MemoryImage(base64Decode(base64Str));
    } catch (_) {}
  }
  if (!kIsWeb) {
    try {
      final file = File(source);
      if (file.existsSync()) {
        return FileImage(file);
      }
    } catch (_) {}
  }
  return NetworkImage(source);
}

// ─────────────────────────────────────────────
// DASHBOARD PAGE (Minimalist iOS Style matching UI Mockup)
// ─────────────────────────────────────────────
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // Mode switcher: 0 = Overview (Center Screen), 1 = Analytics (Left Screen)
  int _activeTab = 0;

  // Selected period for Overview
  String _selectedOverviewPeriod = 'This week';

  // Selected period for Analytics
  String _selectedAnalyticsPeriod = '7D';

  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _recentActivities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
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
    if (mounted) _loadData();
  }

  void _onUrlChanged() {
    if (mounted) _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final stats = await ApiService.getDashboardStats();
    final products = await ApiService.getProducts();

    if (!mounted) return;
    setState(() {
      _stats = stats;
      _topProducts = products.take(4).toList();
      _categories = (stats['top_categories'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      _recentActivities = (stats['recent_activities'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      _isLoading = false;
    });
  }

  String _formatCurrency(num value) {
    // Format as $14,012 matching mockup
    final int val = value.toInt();
    final String s = val.toString();
    String r = '';
    int c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (c > 0 && c % 3 == 0) r = ',$r';
      r = s[i] + r;
      c++;
    }
    return '\$$r';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF0F172A),
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header (Avatar + Name + Level Badge + Menu Button)
                _buildHeader(context),
                const SizedBox(height: 16),

                // View Mode Segmented Switcher (Overview vs Analytics)
                _buildSegmentedSwitcher(),
                const SizedBox(height: 20),

                // Active View Content
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF0F172A)),
                    ),
                  )
                else if (_activeTab == 0)
                  _buildOverviewContent(context)
                else
                  _buildAnalyticsContent(context),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HEADER (Alex + Level 12 + Coins + Menu Button)
  // ─────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    final user = AuthService.currentUser;
    final userName = user != null && user.name.isNotEmpty ? user.name : 'Alex';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Tooltip(
          message: 'Buka Profil',
          waitDuration: const Duration(milliseconds: 300),
          child: GestureDetector(
            onTap: () {
              NavigationService.navigateTo(4);
            },
            behavior: HitTestBehavior.opaque,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                children: [
                  // Memoji Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFDCFCE7),
                      image: const DecorationImage(
                        image: NetworkImage(
                          'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=120&auto=format&fit=crop&q=80',
                        ),
                        fit: BoxFit.cover,
                      ),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, $userName!',
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Level 12',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEAB308),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Text(
                                    '🪙',
                                    style: TextStyle(fontSize: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                '2,564',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Circular Menu Button
        GestureDetector(
          onTap: () {
            NavigationService.openDrawer();
          },
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.notes_rounded,
              color: Color(0xFF0F172A),
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // SEGMENTED SWITCHER (Overview vs Analytics)
  // ─────────────────────────────────────────────
  Widget _buildSegmentedSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = 0),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _activeTab == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _activeTab == 0
                      ? const [
                          BoxShadow(
                            color: Color(0x0C000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Overview',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        _activeTab == 0 ? FontWeight.w700 : FontWeight.w600,
                    color: _activeTab == 0
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = 1),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _activeTab == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _activeTab == 1
                      ? const [
                          BoxShadow(
                            color: Color(0x0C000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Analytics',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        _activeTab == 1 ? FontWeight.w700 : FontWeight.w600,
                    color: _activeTab == 1
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 1. OVERVIEW CONTENT (Matching Center Phone)
  // ─────────────────────────────────────────────
  Widget _buildOverviewContent(BuildContext context) {
    final int orders = (_stats['total_orders'] as num?)?.toInt() ?? 1015;
    final int revenue = (_stats['total_revenue'] as num?)?.toInt() ?? 14012;
    final String ordersGrowth = _stats['orders_growth'] as String? ?? '+9%';
    final String revenueGrowth = _stats['revenue_growth'] as String? ?? '+6%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row ("Overview" + Dropdown "This week v")
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Overview',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
            _buildDropdownPill(
              label: _selectedOverviewPeriod,
              onTap: () => _pickOverviewPeriod(context),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Two Hero Cards Side-by-Side (Lavender & Mint)
        Row(
          children: [
            // Card 1: Total orders (Lavender)
            Expanded(
              child: Container(
                height: 172,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EEFE),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total orders',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      orders.toString().replaceAllMapped(
                          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                          (m) => '${m[1]},'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildGrowthBadge(
                      text: ordersGrowth,
                      bgColor: const Color(0xFFEDE9FE),
                      textColor: const Color(0xFF7C3AED),
                    ),
                    const Spacer(),
                    // 3D Gift Box Illustration Icon
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: const Color(0xFFDDD6FE).withValues(alpha: 0.4),
                          image: const DecorationImage(
                            image: NetworkImage(
                              'https://images.unsplash.com/photo-1549465220-1a8b9238cd48?w=200&auto=format&fit=crop&q=80',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Card 2: Total revenue (Mint Green)
            Expanded(
              child: Container(
                height: 172,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8F0),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total revenue',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrency(revenue),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildGrowthBadge(
                      text: revenueGrowth,
                      bgColor: const Color(0xFFDCFCE7),
                      textColor: const Color(0xFF16A34A),
                    ),
                    const Spacer(),
                    // 3D Coins Stack Illustration
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: const Color(0xFFBBF7D0).withValues(alpha: 0.4),
                          image: const DecorationImage(
                            image: NetworkImage(
                              'https://images.unsplash.com/photo-1621416894569-0f39ed31d247?w=200&auto=format&fit=crop&q=80',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),

        // Top-selling categories Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Top-selling categories',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            GestureDetector(
              onTap: () => NavigationService.navigateTo(1), // go to Produk
              child: const Text(
                'View all',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Horizontal Row of 3 Category Cards
        SizedBox(
          height: 126,
          child: Row(
            children: _categories.map((cat) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: const Color(0xFFF1F5F9), width: 1.2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFFF8FAFC),
                          image: DecorationImage(
                            image: NetworkImage(cat['image'] as String? ?? ''),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(cat['color'] as int? ?? 0xFF6366F1),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              cat['name'] as String? ?? '',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${cat['percentage']}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 26),

        // Recent activity Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent activity',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            GestureDetector(
              onTap: () => NavigationService.navigateTo(3), // go to Transaksi
              child: const Text(
                'View all',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Activity List
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: _recentActivities.asMap().entries.map((entry) {
              final idx = entry.key;
              final act = entry.value;
              final isLast = idx == _recentActivities.length - 1;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    child: Row(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFFF1F5F9),
                          backgroundImage: NetworkImage(
                            act['avatar'] as String? ??
                                'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&auto=format&fit=crop&q=80',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                act['customer'] as String? ?? 'Customer',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                act['items'] as String? ?? '',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '+${_formatCurrency(act['amount'] as num? ?? 0)}',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A), // vibrant green
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    const Divider(
                      height: 1,
                      indent: 68,
                      endIndent: 16,
                      color: Color(0xFFF1F5F9),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // 2. ANALYTICS CONTENT (Matching Left Phone)
  // ─────────────────────────────────────────────
  Widget _buildAnalyticsContent(BuildContext context) {
    const revenue = 14012;
    const unitsSold = 1158;
    const returningCustomers = 86;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top row with Title + Filter Pills + Calendar Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Analytics',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
            // Calendar circular icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Period Pills: [ 7D ] 30D 3M 1Y
        Row(
          children: ['7D', '30D', '3M', '1Y'].map((p) {
            final isSelected = _selectedAnalyticsPeriod == p;
            return GestureDetector(
              onTap: () => setState(() => _selectedAnalyticsPeriod = p),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color:
                      isSelected ? const Color(0xFF0F172A) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  p,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Total Revenue Header
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total revenue',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(revenue),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            _buildGrowthBadge(
              text: '+16%',
              bgColor: const Color(0xFFDCFCE7),
              textColor: const Color(0xFF16A34A),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Minimalist Multi-Tone Green Bar Chart
        Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(
                height: 140,
                child: CustomPaint(
                  size: const Size(double.infinity, 140),
                  painter: _MinimalistMultiBarChartPainter(),
                ),
              ),
              const SizedBox(height: 10),
              // Day labels: Mon Tue Wed Thu Fri Sat Sun
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('Mon', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  Text('Tue', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  Text('Wed', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  Text('Thu', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  Text('Fri', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  Text('Sat', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  Text('Sun', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Two Metric Cards Side-by-Side: Units sold & Returning customers
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Units sold',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          unitsSold.toString().replaceAllMapped(
                              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                              (m) => '${m[1]},'),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildGrowthBadge(
                          text: '+18',
                          bgColor: const Color(0xFFDCFCE7),
                          textColor: const Color(0xFF16A34A),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Returning customers',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '$returningCustomers',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildGrowthBadge(
                          text: '+5',
                          bgColor: const Color(0xFFDCFCE7),
                          textColor: const Color(0xFF16A34A),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),

        // Top products Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Top products',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            GestureDetector(
              onTap: () => NavigationService.navigateTo(1), // go to Produk
              child: const Text(
                'View all',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Top products list
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: _topProducts.asMap().entries.map((entry) {
              final idx = entry.key;
              final p = entry.value;
              final isLast = idx == _topProducts.length - 1;

              return Column(
                children: [
                  InkWell(
                    onTap: () => _showProductDetailModal(context, p),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          // Product Image
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: const Color(0xFFF8FAFC),
                              image: DecorationImage(
                                image: _getImageProvider(p['image'] as String?),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['name'] as String? ?? '',
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatCurrency(p['price'] as num? ?? 0),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '+${_formatCurrency(p['revenue'] as num? ?? 5040)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${p['sales'] ?? 56} units sold',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast)
                    const Divider(
                      height: 1,
                      indent: 78,
                      endIndent: 16,
                      color: Color(0xFFF1F5F9),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // HELPERS (Badges, Dropdowns, Modals)
  // ─────────────────────────────────────────────
  Widget _buildGrowthBadge({
    required String text,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildDropdownPill({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 15,
              color: Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }

  void _pickOverviewPeriod(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['This week', 'This month', 'This year', 'All time']
                .map((p) => ListTile(
                      title: Text(p,
                          style: TextStyle(
                              fontWeight: _selectedOverviewPeriod == p
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                      trailing: _selectedOverviewPeriod == p
                          ? const Icon(Icons.check, color: Color(0xFF16A34A))
                          : null,
                      onTap: () {
                        setState(() => _selectedOverviewPeriod = p);
                        Navigator.pop(ctx);
                      },
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // 3. PRODUCT DETAIL MODAL (Matching Right Phone)
  // ─────────────────────────────────────────────
  void _showProductDetailModal(BuildContext context, Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.90,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sheet Handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header: Back button + Title + Barcode Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF8FAFC),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(Icons.chevron_left_rounded,
                          size: 22, color: Color(0xFF0F172A)),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      p['name'] as String? ?? 'Product Detail',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF8FAFC),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded,
                        size: 18, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Large Hero Product Image
                      Container(
                        height: 220,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: const Color(0xFFF8FAFC),
                          image: DecorationImage(
                            image: _getImageProvider(p['image'] as String?),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Variant Thumbnails Carousel
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          p['image'] as String? ?? '',
                          'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=200&auto=format&fit=crop&q=80',
                          'https://images.unsplash.com/photo-1595950653106-6c9ebd614d3a?w=200&auto=format&fit=crop&q=80',
                          'https://images.unsplash.com/photo-1539185441755-769473a23570?w=200&auto=format&fit=crop&q=80',
                        ].asMap().entries.map((entry) {
                          final idx = entry.key;
                          final imgUrl = entry.value;
                          final isSelected = idx == 0;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFE2E8F0),
                                width: isSelected ? 1.8 : 1.0,
                              ),
                              image: DecorationImage(
                                image: _getImageProvider(imgUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 22),

                      // Revenue Section + Mini Sparkline
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Revenue',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Text(
                                      _formatCurrency(
                                          p['revenue'] as num? ?? 12400),
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildGrowthBadge(
                                      text: '+18%',
                                      bgColor: const Color(0xFFDCFCE7),
                                      textColor: const Color(0xFF16A34A),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Mini Green Line Sparkline
                            SizedBox(
                              width: 80,
                              height: 34,
                              child: CustomPaint(
                                painter: _MiniSparklinePainter(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Two Metric Cards (Units sold & Conversion rate)
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Units sold',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        '${p['sales'] ?? 820}',
                                        style: const TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(width: 6),
                                      _buildGrowthBadge(
                                        text: '+20',
                                        bgColor: const Color(0xFFDCFCE7),
                                        textColor: const Color(0xFF16A34A),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Conversion rate',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Text(
                                        '17.2%',
                                        style: TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(width: 6),
                                      _buildGrowthBadge(
                                        text: '+1.2%',
                                        bgColor: const Color(0xFFDCFCE7),
                                        textColor: const Color(0xFF16A34A),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Sales are up banner
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Sales are up 18% vs. last 30 days.',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                size: 18, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Add to Cart Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            CartService.addItem(
                              p['name'] as String,
                              (p['price'] as num).toInt(),
                              p['unit'] as String? ?? 'pcs',
                            );
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '${p['name']} ditambahkan ke keranjang!'),
                                backgroundColor: const Color(0xFF0F172A),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Add to Cart',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// MINIMALIST MULTI-BAR CHART PAINTER (Mon-Sun multi-tone green bars)
// ─────────────────────────────────────────────
class _MinimalistMultiBarChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const int columnCount = 7;
    final double colWidth = size.width / columnCount;
    const double barWidth = 4.5;
    const double barSpacing = 2.5;

    // Heights and counts per day matching the screenshot multi-tone vertical bars
    final List<List<double>> columnHeights = [
      [0.45, 0.70, 0.35, 0.55], // Mon
      [0.30, 0.50, 0.85, 0.40], // Tue
      [0.60, 0.40, 0.75, 0.30], // Wed
      [0.55, 0.80, 0.65, 0.90], // Thu
      [0.70, 0.45, 0.60, 0.50], // Fri
      [0.85, 0.95, 0.70, 0.60], // Sat
      [0.50, 0.65, 0.40, 0.80], // Sun
    ];

    final List<Color> greenShades = [
      const Color(0xFF86EFAC),
      const Color(0xFF22C55E),
      const Color(0xFF15803D),
      const Color(0xFF4ADE80),
    ];

    for (int col = 0; col < columnCount; col++) {
      final heights = columnHeights[col];
      final double totalBarsWidth =
          (heights.length * barWidth) + ((heights.length - 1) * barSpacing);
      final double startX = (col * colWidth) + (colWidth - totalBarsWidth) / 2;

      for (int b = 0; b < heights.length; b++) {
        final double h = heights[b] * (size.height - 10);
        final double x = startX + b * (barWidth + barSpacing);
        final double y = size.height - h;

        final RRect rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, h),
          const Radius.circular(3),
        );

        final paint = Paint()
          ..color = greenShades[b % greenShades.length]
          ..style = PaintingStyle.fill;

        canvas.drawRRect(rrect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────
// MINI SPARKLINE PAINTER (Smooth Green Line)
// ─────────────────────────────────────────────
class _MiniSparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final List<double> pointsFraction = [
      0.3, 0.4, 0.2, 0.5, 0.7, 0.6, 0.85, 0.8, 1.0
    ];

    final double stepX = size.width / (pointsFraction.length - 1);
    final List<Offset> points = List.generate(
      pointsFraction.length,
      (i) => Offset(
        i * stepX,
        size.height - (pointsFraction[i] * (size.height - 8) + 4),
      ),
    );

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final cp1 = Offset((points[i].dx + points[i + 1].dx) / 2, points[i].dy);
      final cp2 =
          Offset((points[i].dx + points[i + 1].dx) / 2, points[i + 1].dy);
      path.cubicTo(
          cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i + 1].dx, points[i + 1].dy);
    }

    final paint = Paint()
      ..color = const Color(0xFF16A34A)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
