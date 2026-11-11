import 'package:flutter/material.dart';

import 'pages/dashboard_page.dart';
import 'pages/produk_page.dart';
import 'pages/keranjang_ui.dart';
import 'pages/transaksi_ui.dart';
import 'pages/profil_ui.dart';
import 'services/cart_service.dart';

class MobileShell extends StatefulWidget {
  const MobileShell({super.key});

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DashboardPage(),
    const ProdukPage(),
    const KeranjangUI(),
    const TransaksiUI(),
    const ProfilUI(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0D000000),
            blurRadius: 10,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: SafeArea(
        child: ValueListenableBuilder<List<CartItem>>(
          valueListenable: CartService.cartNotifier,
          builder: (context, cart, _) {
            final cartCount = CartService.totalCount;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(0, Icons.grid_view, 'Overview'),
                _buildNavItem(1, Icons.storefront, 'Produk'),
                _buildNavItem(2, Icons.shopping_cart_outlined, 'Keranjang', badgeCount: cartCount),
                _buildNavItem(3, Icons.receipt_long_outlined, 'Transaksi'),
                _buildNavItem(4, Icons.person_outline, 'Profil'),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {int badgeCount = 0}) {
    bool isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isSelected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A), // Dark color from original design
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10),
              child: Icon(icon, color: Colors.grey, size: 24),
            ),
          
          if (badgeCount > 0 && !isSelected)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badgeCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
