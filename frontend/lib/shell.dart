import 'package:flutter/material.dart';

import 'pages/dashboard_page.dart';
import 'pages/keranjang_page.dart';
import 'pages/produk_page.dart';
import 'pages/profil_page.dart';
import 'pages/transaksi_page.dart';
import 'services/api_service.dart';
import 'services/cart_service.dart';
import 'services/navigation_service.dart';
import 'widgets/full_sidebar.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  @override
  void initState() {
    super.initState();
    ApiService.testConnection();
    NavigationService.selectedIndex.addListener(_onNavigationChanged);
    CartService.cartNotifier.addListener(_onNavigationChanged);
  }

  @override
  void dispose() {
    NavigationService.selectedIndex.removeListener(_onNavigationChanged);
    CartService.cartNotifier.removeListener(_onNavigationChanged);
    super.dispose();
  }

  void _onNavigationChanged() {
    if (mounted) setState(() {});
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
    final currentIndex = NavigationService.selectedIndex.value;
    final int cartCount = CartService.totalCount;

    return Scaffold(
      key: NavigationService.scaffoldKey,
      drawer: FullSidebar(
        selectedIndex: currentIndex,
        onItemSelected: (index) {
          NavigationService.navigateTo(index);
        },
      ),
      body: IndexedStack(
        index: currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFF1F5F9), width: 1.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  currentIndex: currentIndex,
                  icon: Icons.grid_view_rounded,
                  label: 'Overview',
                ),
                _buildNavItem(
                  index: 1,
                  currentIndex: currentIndex,
                  icon: Icons.storefront_rounded,
                  label: 'Products',
                ),
                _buildNavItem(
                  index: 2,
                  currentIndex: currentIndex,
                  icon: Icons.shopping_bag_outlined,
                  label: 'Cart',
                  badgeCount: cartCount,
                ),
                _buildNavItem(
                  index: 3,
                  currentIndex: currentIndex,
                  icon: Icons.receipt_long_rounded,
                  label: 'Orders',
                ),
                _buildNavItem(
                  index: 4,
                  currentIndex: currentIndex,
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required int currentIndex,
    required IconData icon,
    required String label,
    int badgeCount = 0,
  }) {
    final bool isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () => NavigationService.navigateTo(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFF16A34A),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
