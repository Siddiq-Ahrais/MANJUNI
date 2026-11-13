import 'package:flutter/material.dart';

import 'main.dart';
import 'pages/keranjang_page.dart';
import 'pages/produk_page.dart';
import 'pages/transaksi_page.dart';
import 'pages/analytics_page.dart';
import 'pages/profil_page.dart';
import 'services/api_service.dart';
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
  }

  @override
  void dispose() {
    NavigationService.selectedIndex.removeListener(_onNavigationChanged);
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
    AnalyticsPage(),
    ProfilPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = NavigationService.selectedIndex.value;

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
    );
  }
}
