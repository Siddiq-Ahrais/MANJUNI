import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/navigation_service.dart';

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSearchPressed;
  final VoidCallback? onNotificationPressed;
  final VoidCallback? onMenuPressed;
  final Widget? trailingExtra;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback? onSearchClosed;
  final TextEditingController? searchController;
  final String? searchHint;

  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onSearchPressed,
    this.onNotificationPressed,
    this.onMenuPressed,
    this.trailingExtra,
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.onSearchClosed,
    this.searchController,
    this.searchHint,
  });

  static const Color primaryGreen = Color(0xFF164E2E);

  @override
  Size get preferredSize => subtitle != null
      ? const Size.fromHeight(64)
      : const Size.fromHeight(56);

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();
}

class _CustomAppBarState extends State<CustomAppBar> {
  bool _isSearching = false;
  late final TextEditingController _internalSearchController;
  late final FocusNode _searchFocusNode;

  TextEditingController get _effectiveController =>
      widget.searchController ?? _internalSearchController;

  @override
  void initState() {
    super.initState();
    _internalSearchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _effectiveController.addListener(_onTextChange);
  }

  @override
  void didUpdateWidget(CustomAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController != widget.searchController) {
      (oldWidget.searchController ?? _internalSearchController)
          .removeListener(_onTextChange);
      _effectiveController.addListener(_onTextChange);
    }
  }

  @override
  void dispose() {
    _effectiveController.removeListener(_onTextChange);
    _internalSearchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onTextChange() {
    if (mounted) setState(() {});
  }

  void _openSearch() {
    setState(() {
      _isSearching = true;
    });
    widget.onSearchPressed?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _closeSearch() {
    _effectiveController.clear();
    widget.onSearchChanged?.call('');
    widget.onSearchClosed?.call();
    setState(() {
      _isSearching = false;
    });
  }

  void _clearSearch() {
    _effectiveController.clear();
    widget.onSearchChanged?.call('');
    setState(() {});
  }

  void _handleMenu(BuildContext context) {
    if (widget.onMenuPressed != null) {
      widget.onMenuPressed!();
    } else {
      final scaffold = Scaffold.maybeOf(context);
      if (scaffold != null && scaffold.hasDrawer) {
        scaffold.openDrawer();
      } else {
        NavigationService.openDrawer();
      }
    }
  }

  Widget _buildTitleSection() {
    return Column(
      key: const ValueKey('title_section'),
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            color: Color(0xFF0F172A), // Minimalist Dark Slate
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.4,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981), // Emerald indicator dot
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.subtitle!,
                  style: const TextStyle(
                    color: Color(0xFF64748B), // Slate 500
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      key: const ValueKey('search_field'),
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // Subtle minimalist slate-100
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: TextField(
        controller: _effectiveController,
        focusNode: _searchFocusNode,
        autofocus: true,
        style: const TextStyle(
          fontSize: 13.5,
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w500,
        ),
        cursorColor: const Color(0xFF0F172A),
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.searchHint ?? 'Cari nama produk, nota, dll...',
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 13.5,
            fontWeight: FontWeight.normal,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF64748B),
            size: 19,
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 38, minHeight: 38),
          suffixIcon: _effectiveController.text.isNotEmpty
              ? GestureDetector(
                  onTap: _clearSearch,
                  child: const MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Icon(
                      Icons.cancel_rounded,
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                  ),
                )
              : null,
          suffixIconConstraints:
              const BoxConstraints(minWidth: 36, minHeight: 36),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        onChanged: (val) {
          widget.onSearchChanged?.call(val);
        },
        onSubmitted: (val) {
          widget.onSearchSubmitted?.call(val);
        },
      ),
    );
  }

  void _showNotificationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Notifikasi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '2 Baru',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildNotificationItem(
                icon: Icons.check_circle_outline_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'Sistem Kasir Berjalan Normal',
                subtitle:
                    'Penyimpanan database lokal dan offline cache siap bertransaksi.',
                time: 'Baru saja',
              ),
              const SizedBox(height: 12),
              _buildNotificationItem(
                icon: Icons.cloud_done_outlined,
                iconColor: const Color(0xFF3B82F6),
                title: 'Sinkronisasi Otomatis',
                subtitle:
                    'Semua transaksi dicatat dan siap dikirim ke backend saat online.',
                time: '5 mnt lalu',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Tutup',
                    style: TextStyle(
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Container(
        color: Colors.transparent, // Completely transparent navbar
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                if (!_isSearching) ...[
                  _HoverIconButton(
                    icon: Icons.menu_rounded,
                    tooltip: 'Menu',
                    onPressed: () => _handleMenu(context),
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  _HoverIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Kembali',
                    onPressed: _closeSearch,
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.04, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _isSearching
                        ? _buildSearchField()
                        : _buildTitleSection(),
                  ),
                ),
                if (widget.trailingExtra != null && !_isSearching) ...[
                  const SizedBox(width: 8),
                  widget.trailingExtra!,
                ],
                const SizedBox(width: 8),
                if (!_isSearching) ...[
                  _HoverIconButton(
                    key: const ValueKey('open_search_btn'),
                    icon: Icons.search_rounded,
                    tooltip: 'Cari',
                    onPressed: _openSearch,
                  ),
                ] else ...[
                  _HoverIconButton(
                    key: const ValueKey('close_search_btn'),
                    icon: Icons.close_rounded,
                    tooltip: 'Tutup Pencarian',
                    onPressed: _closeSearch,
                  ),
                ],
                const SizedBox(width: 6),
                _NotificationButton(
                  onPressed: () {
                    if (widget.onNotificationPressed != null) {
                      widget.onNotificationPressed!();
                    } else {
                      _showNotificationSheet(context);
                    }
                  },
                ),
                const SizedBox(width: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HOVERABLE NOTIFICATION BUTTON
// ─────────────────────────────────────────────
class _NotificationButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _NotificationButton({required this.onPressed});

  @override
  State<_NotificationButton> createState() => _NotificationButtonState();
}

class _NotificationButtonState extends State<_NotificationButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Notifikasi\n\u2022 Sistem Kasir: Siap Digunakan\n\u2022 Mode Offline: Aktif',
      preferBelow: true,
      verticalOffset: 24,
      waitDuration: const Duration(milliseconds: 120),
      showDuration: const Duration(seconds: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        height: 1.45,
        fontWeight: FontWeight.w500,
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isHovered
                  ? const Color(0xFFF1F5F9)
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: _isHovered
                    ? const Color(0xFFE2E8F0)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: _isHovered ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    _isHovered
                        ? Icons.notifications_rounded
                        : Icons.notifications_none_rounded,
                    color: _isHovered
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF334155),
                    size: 23,
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isHovered
                            ? const Color(0xFFF1F5F9)
                            : const Color(0xFFF8F9FA),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// REUSABLE HOVER ICON BUTTON (Minimalist)
// ─────────────────────────────────────────────
class _HoverIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _HoverIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 200),
      preferBelow: true,
      verticalOffset: 22,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isHovered
                  ? const Color(0xFFF1F5F9)
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: _isHovered
                    ? const Color(0xFFE2E8F0)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: AnimatedScale(
              scale: _isHovered ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: Icon(
                widget.icon,
                color: _isHovered
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF334155),
                size: 23,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
