import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';

class FullSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const FullSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  static const Color primaryGreen = Color(0xFF164E2E);
  static const Color accentGreen = Color(0xFF1E874B);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Drawer(
      width: screenWidth, // Full screen width sidebar as requested
      elevation: 0,
      backgroundColor: const Color(0xFFF8F9FA),
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          children: [
            // Header: Store identity & close button
            _buildHeader(context),
            const Divider(color: Color(0xFFE2E8F0), height: 1, thickness: 1),

            // Navigation Items Column
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 6, bottom: 12),
                      child: Text(
                        'MENU UTAMA',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),

                    // 1. Dashboard
                    _SidebarMenuItem(
                      icon: Icons.bar_chart_rounded,
                      title: 'Dashboard',
                      subtitle: 'Ringkasan performa & statistik toko',
                      isSelected: selectedIndex == 0,
                      onTap: () => onItemSelected(0),
                    ),
                    const SizedBox(height: 10),

                    // 2. Produk
                    _SidebarMenuItem(
                      icon: Icons.grid_view_rounded,
                      title: 'Produk',
                      subtitle: 'Katalog barang & manajemen stok',
                      isSelected: selectedIndex == 1,
                      onTap: () => onItemSelected(1),
                    ),
                    const SizedBox(height: 10),

                    // 3. Keranjang (with Cart Counter)
                    ValueListenableBuilder<List<CartItem>>(
                      valueListenable: CartService.cartNotifier,
                      builder: (context, cartItems, _) {
                        final count = CartService.typesCount;
                        return _SidebarMenuItem(
                          icon: Icons.shopping_cart_rounded,
                          title: 'Keranjang',
                          subtitle: 'Kasir & transaksi pembayaran',
                          badgeCount: count,
                          isSelected: selectedIndex == 2,
                          onTap: () => onItemSelected(2),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // 4. Transaksi
                    _SidebarMenuItem(
                      icon: Icons.receipt_long_rounded,
                      title: 'Transaksi',
                      subtitle: 'Riwayat penjualan & sinkronisasi',
                      isSelected: selectedIndex == 3,
                      onTap: () => onItemSelected(3),
                    ),
                    const SizedBox(height: 10),

                    // 5. Profil
                    _SidebarMenuItem(
                      icon: Icons.person_rounded,
                      title: 'Profil',
                      subtitle: 'Pengaturan akun toko & konfigurasi API',
                      isSelected: selectedIndex == 4,
                      onTap: () => onItemSelected(4),
                    ),
                    const SizedBox(height: 28),

                    // Quick System Status Card
                    _buildStatusCard(),
                  ],
                ),
              ),
            ),

            // Footer
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: primaryGreen,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: primaryGreen.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Warung Maju Jaya',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                ValueListenableBuilder<bool?>(
                  valueListenable: ApiService.isConnectedNotifier,
                  builder: (context, isConn, _) {
                    final isOnline = isConn == true;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: isOnline
                                ? const Color(0xFF10B981)
                                : const Color(0xFF94A3B8),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOnline
                              ? 'Sistem Online'
                              : 'Mode Offline Aktif',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          _CloseSidebarButton(
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.offline_pin_rounded,
              color: Color(0xFF166534),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Penyimpanan Lokal Aktif',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Semua data penjualan tersimpan offline & siap disinkronkan.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Aplikasi Kasir POS',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              Text(
                'Versi 1.0.0 \u2022 Mode Minimalist',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Tutup'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF475569),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SIDEBAR MENU ITEM WITH HOVER & ACTIVE STATE
// ─────────────────────────────────────────────
class _SidebarMenuItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final int badgeCount;
  final VoidCallback onTap;

  const _SidebarMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  State<_SidebarMenuItem> createState() => _SidebarMenuItemState();
}

class _SidebarMenuItemState extends State<_SidebarMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final isHovered = _isHovered;

    Color backgroundColor;
    Color iconColor;
    Color iconBgColor;
    Color titleColor;
    Color subtitleColor;
    Border? border;

    if (isSelected) {
      backgroundColor = const Color(0xFFDCFCE7); // Light Emerald
      iconBgColor = const Color(0xFF164E2E);
      iconColor = Colors.white;
      titleColor = const Color(0xFF14532D);
      subtitleColor = const Color(0xFF15803D);
      border = Border.all(color: const Color(0xFF86EFAC), width: 1.2);
    } else if (isHovered) {
      backgroundColor = const Color(0xFFF1F5F9);
      iconBgColor = const Color(0xFFE2E8F0);
      iconColor = const Color(0xFF0F172A);
      titleColor = const Color(0xFF0F172A);
      subtitleColor = const Color(0xFF64748B);
      border = Border.all(color: const Color(0xFFCBD5E1), width: 1);
    } else {
      backgroundColor = Colors.white;
      iconBgColor = const Color(0xFFF8FAFC);
      iconColor = const Color(0xFF475569);
      titleColor = const Color(0xFF1E293B);
      subtitleColor = const Color(0xFF94A3B8);
      border = Border.all(color: const Color(0xFFE2E8F0), width: 1);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: border,
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x12164E2E),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: titleColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: subtitleColor,
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (widget.badgeCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.badgeCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isSelected
                    ? const Color(0xFF15803D)
                    : const Color(0xFFCBD5E1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CLOSE SIDEBAR BUTTON WITH HOVER
// ─────────────────────────────────────────────
class _CloseSidebarButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _CloseSidebarButton({required this.onPressed});

  @override
  State<_CloseSidebarButton> createState() => _CloseSidebarButtonState();
}

class _CloseSidebarButtonState extends State<_CloseSidebarButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Tutup Menu',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isHovered
                  ? const Color(0xFFF1F5F9)
                  : const Color(0xFFE2E8F0).withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.close_rounded,
              color: _isHovered
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF475569),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
