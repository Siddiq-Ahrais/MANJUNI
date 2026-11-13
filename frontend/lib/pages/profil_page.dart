import 'dart:io' show Directory, File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_config.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';

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
  int _transactionCount = 0;
  String _lastSyncText = 'Belum ada sinkronisasi';
  String _storeName = 'Nama Toko Anda';
  String _storeCategory = 'Kategori Toko \u2022 UMKM';

  String get _storeInitials {
    if (_storeName == 'Nama Toko Anda' || _storeName == 'Warung Maju Jaya') {
      return 'MJ';
    }
    final words = _storeName.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words[0].isEmpty) return 'MJ';
    if (words.length == 1) {
      return words[0].substring(0, words[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _loadStoreInfo();
    _checkStatus(silent: true);
    _loadStats();
    ApiService.dataChangedNotifier.addListener(_onDataChanged);
  }

  Future<void> _loadStoreInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('store_name');
      final cat = prefs.getString('store_category');
      if (!mounted) return;
      setState(() {
        if (name != null && name.trim().isNotEmpty) {
          _storeName = name.trim();
        }
        if (cat != null && cat.trim().isNotEmpty) {
          _storeCategory = cat.trim();
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    ApiService.dataChangedNotifier.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) {
      _loadStoreInfo();
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    final products = await ApiService.getProducts();
    final transactions = await ApiService.getTransactions();

    if (!mounted) return;
    setState(() {
      _productCount = products.length;
      _transactionCount = transactions.length;
    });
  }

  Future<void> _showExportTransactionsDialog() async {
    final transactions = await ApiService.getTransactions();
    final csvData = ApiService.buildTransactionsExportCsv(transactions);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.download_rounded, color: kGreen),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Cadangkan Data Transaksi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total ${transactions.length} transaksi siap diekspor (ID, Waktu, Jenis Pembayaran, Harga Satuan Produk, Total IDR).',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF4B5563)),
              ),
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    csvData,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(color: Colors.grey)),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: csvData));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data CSV transaksi berhasil disalin ke clipboard!'),
                  backgroundColor: kGreen,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Salin CSV'),
          ),
          if (!kIsWeb)
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  final ts = DateTime.now().millisecondsSinceEpoch;
                  final file = File('${Directory.systemTemp.path}/manjuni_transaksi_$ts.csv');
                  await file.writeAsString(csvData);
                  if (!ctx.mounted || !mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Backup CSV tersimpan di: ${file.path}'),
                      backgroundColor: kGreen,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal menyimpan file: $e'),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.save_alt_rounded, size: 16),
              label: const Text('Simpan CSV'),
            ),
        ],
      ),
    );
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

  void _showEditStoreDialog() {
    final nameCtrl = TextEditingController(text: _storeName);
    final categoryCtrl = TextEditingController(text: _storeCategory);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.storefront_rounded, color: kGreen, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ubah Identitas Toko',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Sesuaikan nama toko dan kategori usaha Anda',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                const Text(
                  'Nama Toko',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Warung Maju Jaya',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Kategori Toko / Usaha',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: categoryCtrl,
                  decoration: InputDecoration(
                    hintText: 'Misal: Kategori Toko \u2022 UMKM',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _showServerDialog();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.settings_ethernet_rounded, size: 16, color: kGreen),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Pengaturan Target Server Localhost / IP >',
                            style: TextStyle(
                              fontSize: 12,
                              color: kGreen,
                              fontWeight: FontWeight.w600,
                            ),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final newName = nameCtrl.text.trim();
                          final newCat = categoryCtrl.text.trim();
                          if (newName.isNotEmpty) {
                            setState(() {
                              _storeName = newName;
                              if (newCat.isNotEmpty) {
                                _storeCategory = newCat;
                              }
                            });
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('store_name', newName);
                            if (newCat.isNotEmpty) {
                              await prefs.setString('store_category', newCat);
                            }
                            ApiService.dataChangedNotifier.value++;
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Nama toko berhasil diperbarui: $_storeName'),
                                backgroundColor: kGreen,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Simpan'),
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
                                'Pengaturan Server Laravel',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                'Konfigurasi target koneksi backend Laravel 11 REST API',
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
                                      'Menggunakan http://10.0.2.2:8000/api/v1 (Emulator)',
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
                                  Text('Menggunakan http://127.0.0.1:8000/api/v1',
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              // Header Profile Card (Mint Green, matching Image 3)
            GestureDetector(
              onTap: _showEditStoreDialog,
              behavior: HitTestBehavior.opaque,
              child: Container(
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
                      child: Center(
                        child: Text(
                          _storeInitials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _storeName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _storeCategory,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF374151),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _showEditStoreDialog,
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

                // Total Transaksi (Lavender/Blue)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB8C7FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Transaksi',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4B5563),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '$_transactionCount',
                            style: const TextStyle(
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
                    icon: Icons.upload_outlined,
                    iconBg: const Color(0xFFD1F2D9),
                    iconColor: const Color(0xFF1E874B),
                    title: 'Cadangkan Data',
                    onTap: _showExportTransactionsDialog,
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
                onPressed: () async {
                  // Keluar hanya mengakhiri sesi login; produk & data
                  // terdaftar tetap tersimpan di perangkat.
                  await ApiService.logout();
                  if (!context.mounted) return;
                  CartService.clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Berhasil keluar. Produk terdaftar tetap tersimpan.'),
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
    ),
  );
}

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: kGreen,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profil',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _storeName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
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
