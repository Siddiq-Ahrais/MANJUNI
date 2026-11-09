import 'package:flutter/material.dart';
import '../services/api_config.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../widgets/custom_app_bar.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  static const Color kGreen = Color(0xFF1E874B);
  bool _isOfflineMode = true;
  bool _isSyncing = false;
  int _productCount = 0;
  String _lastSyncText = 'Belum ada sinkronisasi';

  @override
  void initState() {
    super.initState();
    _checkStatus(silent: true);
    _loadProductCount();
    ApiService.dataChangedNotifier.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    ApiService.dataChangedNotifier.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _loadProductCount();
  }

  Future<void> _loadProductCount() async {
    final products = await ApiService.getProducts();
    if (!mounted) return;
    setState(() => _productCount = products.length);
  }

  Future<void> _checkStatus({bool silent = false}) async {
    setState(() => _isSyncing = true);
    final res = await ApiService.testConnection();
    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      if (res['success'] == true) {
        final now = DateTime.now();
        _lastSyncText =
            'Hari ini \u2022 ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} \u2022 Tersinkron';
        _isOfflineMode = false;
      } else {
        _isOfflineMode = true;
      }
    });

    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] as String),
          backgroundColor:
              res['success'] == true ? kGreen : const Color(0xFFC62828),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showServerDialog() {
    final ipController = TextEditingController(text: ApiConfig.defaultWifiIp);
    DeviceTarget selected = ApiConfig.target;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.settings_ethernet_rounded,
                              color: kGreen, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pengaturan Server Localhost',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                'Konfigurasi target koneksi backend PHP / MySQL',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Opsi 1: Android Emulator
                    InkWell(
                      onTap: () => setModalState(() => selected = DeviceTarget.emulator),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected == DeviceTarget.emulator
                                      ? kGreen
                                      : const Color(0xFF9E9E9E),
                                  width: selected == DeviceTarget.emulator ? 6 : 2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Android Emulator',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text(
                                      'Menggunakan http://10.0.2.2/api_warung (Emulator)',
                                      style: TextStyle(
                                          fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Opsi 2: HP Fisik via Wi-Fi
                    InkWell(
                      onTap: () => setModalState(() => selected = DeviceTarget.physicalPhone),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selected == DeviceTarget.physicalPhone
                                          ? kGreen
                                          : const Color(0xFF9E9E9E),
                                      width: selected == DeviceTarget.physicalPhone ? 6 : 2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('HP Fisik Android / iOS (Wi-Fi)',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 14)),
                                      Text(
                                          'Laptop dan HP dalam 1 jaringan Wi-Fi',
                                          style: TextStyle(
                                              fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (selected == DeviceTarget.physicalPhone)
                              Padding(
                                padding: const EdgeInsets.only(left: 34, top: 8),
                                child: TextField(
                                  controller: ipController,
                                  decoration: InputDecoration(
                                    labelText: 'IP Laptop',
                                    hintText: '192.168.1.68',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Opsi 3: Windows Desktop / Web
                    InkWell(
                      onTap: () => setModalState(() => selected = DeviceTarget.desktopOrWeb),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected == DeviceTarget.desktopOrWeb
                                      ? kGreen
                                      : const Color(0xFF9E9E9E),
                                  width: selected == DeviceTarget.desktopOrWeb ? 6 : 2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Windows Desktop / Web Browser',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('Menggunakan http://127.0.0.1/api_warung',
                                      style: TextStyle(
                                          fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              ApiConfig.setTarget(selected, customIp: ipController.text);
                              Navigator.pop(ctx);
                              _checkStatus(silent: false);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Simpan & Uji'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: CustomAppBar(
        title: 'Profil',
        subtitle: 'Warung Maju Jaya \u2022 Mode Offline',
        onSearchPressed: () {},
        onNotificationPressed: () {},
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header Profile Card (Mint Green, matching Image 3)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFA5D6A7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E874B),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'MJ',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nama Toko Anda',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Kategori Toko \u2022 UMKM',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF374151),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _showServerDialog,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Two Metric Cards Row (matching Image 3)
            Row(
              children: [
                // Produk Terdaftar (Peach/Orange)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFCC80),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Produk Terdaftar',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4B5563),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '$_productCount',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Pelanggan Kasbon (Lavender/Blue)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB8C7FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pelanggan Kasbon',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4B5563),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '0 Orang',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Settings Card (Mode Offline & Sinkronisasi)
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Column(
                children: [
                  // Row 1: Mode Offline Toggle
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1F2D9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.access_time_rounded,
                          color: Color(0xFF1E874B),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mode Offline',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                            SizedBox(height: 1),
                            Text(
                              'Data disimpan di perangkat',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isOfflineMode,
                        activeThumbColor: Colors.white,
                        activeTrackColor: const Color(0xFF1E874B),
                        onChanged: (val) {
                          setState(() => _isOfflineMode = val);
                          if (!val) {
                            _checkStatus(silent: false);
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Color(0xFFF0F0F0)),

                  // Row 2: Sinkronisasi terakhir & Tombol Sinkron
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sinkronisasi terakhir',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _lastSyncText,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: _isSyncing ? null : () => _checkStatus(silent: false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1E874B),
                          side: const BorderSide(color: Color(0xFF1E874B), width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: _isSyncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF1E874B),
                                ),
                              )
                            : const Text(
                                'Sinkron',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Menu List Card (matching Image 3)
            Container(
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
              child: Column(
                children: [
                  _MenuRowItem(
                    icon: Icons.storefront_outlined,
                    iconBg: const Color(0xFFD1F2D9),
                    iconColor: const Color(0xFF1E874B),
                    title: 'Info Toko',
                    onTap: _showServerDialog,
                  ),
                  const Divider(height: 1, indent: 64, color: Color(0xFFF0F0F0)),
                  _MenuRowItem(
                    icon: Icons.people_outline_rounded,
                    iconBg: const Color(0xFFD9E6FF),
                    iconColor: const Color(0xFF2563EB),
                    title: 'Pelanggan \u0026 Kasbon',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Menu Pelanggan & Kasbon dibuka (2 Orang terdaftar)'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 64, color: Color(0xFFF0F0F0)),
                  _MenuRowItem(
                    icon: Icons.print_outlined,
                    iconBg: const Color(0xFFFFE0B2),
                    iconColor: const Color(0xFFD97706),
                    title: 'Printer \u0026 Struk',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Printer Thermal 58mm / 80mm Siap Digunakan'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 64, color: Color(0xFFF0F0F0)),
                  _MenuRowItem(
                    icon: Icons.upload_outlined,
                    iconBg: const Color(0xFFD1F2D9),
                    iconColor: const Color(0xFF1E874B),
                    title: 'Cadangkan Data',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Data lokal berhasil dicadangkan ke memori'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Logout Button (Red outlined, matching Image 3)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  ApiService.resetAllData();
                  CartService.clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Berhasil keluar. Semua data transaksi & produk di-reset.'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                label: const Text(
                  'Keluar',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Footer Version (matching Image 3)
            const Text(
              'Versi 1.0.0',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _MenuRowItem extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  const _MenuRowItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9CA3AF),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
