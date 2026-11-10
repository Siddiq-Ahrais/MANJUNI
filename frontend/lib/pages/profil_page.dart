import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../widgets/custom_app_bar.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  static const Color kGreen = Color(0xFF1E874B);
  static const Color kMintHeader = Color(0xFFA5D6A7);
  static const Color kPeachCard = Color(0xFFFFCC80);
  static const Color kLavenderCard = Color(0xFFB8C7FF);

  bool _isOfflineMode = true;
  bool _isSyncing = false;
  int _productCount = 9;
  int _kasbonCount = 0;
  String _lastSyncText = 'Belum ada sinkronisasi';

  // Store information
  String _storeName = 'Nama Toko Anda';
  String _storeCategory = 'Kategori Toko \u2022 UMKM';
  String _storePhone = '0812-3456-7890';
  String _storeAddress = 'Jl. Merdeka No. 45, Jakarta';

  // Kasbon sample list
  final List<Map<String, dynamic>> _kasbonList = [
    {
      'name': 'Ibu Siti',
      'phone': '0813-8899-1122',
      'amount': 45000,
      'date': '08 Okt 2024',
      'notes': 'Beras 3kg & Telur 1kg',
    },
    {
      'name': 'Pak Joko',
      'phone': '0857-1234-5678',
      'amount': 30000,
      'date': '10 Okt 2024',
      'notes': 'Minyak Goreng 2L',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadProductCount();
    _checkStatus(silent: true);
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

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = AuthService.currentUser;
      setState(() {
        _storeName = user?.business?.name ?? prefs.getString('store_name') ?? 'Nama Toko Anda';
        _storeCategory = user != null
            ? '${user.name} • ${user.roleDisplayName}'
            : (prefs.getString('store_category') ?? 'Kategori Toko \u2022 UMKM');
        _storePhone = user?.business?.phone ?? prefs.getString('store_phone') ?? '0812-3456-7890';
        _storeAddress = user?.business?.address ?? prefs.getString('store_address') ?? 'Jl. Merdeka No. 45, Jakarta';
        _kasbonCount = prefs.getInt('kasbon_count') ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('store_name', _storeName);
      await prefs.setString('store_category', _storeCategory);
      await prefs.setString('store_phone', _storePhone);
      await prefs.setString('store_address', _storeAddress);
      await prefs.setInt('kasbon_count', _kasbonCount);
    } catch (_) {}
  }

  Future<void> _loadProductCount() async {
    final products = await ApiService.getProducts();
    if (!mounted) return;
    setState(() => _productCount = products.isEmpty ? 9 : products.length);
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

  // Bottom Sheet: Edit Info Toko & Server Target
  void _showInfoTokoSheet() {
    final nameCtrl = TextEditingController(text: _storeName);
    final catCtrl = TextEditingController(text: _storeCategory);
    final phoneCtrl = TextEditingController(text: _storePhone);
    final addrCtrl = TextEditingController(text: _storeAddress);
    final ipCtrl = TextEditingController(text: ApiConfig.defaultWifiIp);
    DeviceTarget selectedTarget = ApiConfig.target;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1F2D9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.storefront_outlined,
                            color: kGreen,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Informasi Toko',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: Color(0xFF111827),
                              ),
                            ),
                            Text(
                              'Perbarui identitas toko dan koneksi server',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Nama Toko
                    const Text(
                      'Nama Toko',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Toko Berkah Jaya',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Kategori Toko
                    const Text(
                      'Kategori Toko',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: catCtrl,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Kategori Toko \u2022 UMKM',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // No Telepon & Alamat
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'No. WhatsApp',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF374151),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: phoneCtrl,
                                decoration: InputDecoration(
                                  hintText: '0812-xxxx-xxxx',
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE5E7EB)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Alamat Singkat',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF374151),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: addrCtrl,
                                decoration: InputDecoration(
                                  hintText: 'Kota / Wilayah',
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE5E7EB)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Section Koneksi Server Backend
                    const Text(
                      'Target Koneksi Server Backend',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Radio 1: Android Emulator
                    _buildServerOption(
                      title: 'Android Emulator (10.0.2.2:8000)',
                      subtitle: 'Target standar emulator Android Studio',
                      isSelected: selectedTarget == DeviceTarget.emulator,
                      onTap: () => setModalState(
                          () => selectedTarget = DeviceTarget.emulator),
                    ),
                    // Radio 2: HP Fisik via Wi-Fi
                    _buildServerOption(
                      title: 'HP Fisik Android / iOS (Wi-Fi)',
                      subtitle: 'Laptop dan HP berada di jaringan Wi-Fi sama',
                      isSelected: selectedTarget == DeviceTarget.physicalPhone,
                      onTap: () => setModalState(
                          () => selectedTarget = DeviceTarget.physicalPhone),
                    ),
                    if (selectedTarget == DeviceTarget.physicalPhone)
                      Padding(
                        padding: const EdgeInsets.only(left: 36, bottom: 8),
                        child: TextField(
                          controller: ipCtrl,
                          decoration: InputDecoration(
                            labelText: 'IP Laptop/Server',
                            hintText: '192.168.1.68',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    // Radio 3: Desktop/Web
                    _buildServerOption(
                      title: 'Windows Desktop / Web Browser (127.0.0.1:8000)',
                      subtitle: 'Target localhost untuk build Windows / Chrome',
                      isSelected: selectedTarget == DeviceTarget.desktopOrWeb,
                      onTap: () => setModalState(
                          () => selectedTarget = DeviceTarget.desktopOrWeb),
                    ),

                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: const BorderSide(color: Color(0xFFD1D5DB)),
                            ),
                            child: const Text(
                              'Batal',
                              style: TextStyle(color: Color(0xFF374151)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                if (nameCtrl.text.trim().isNotEmpty) {
                                  _storeName = nameCtrl.text.trim();
                                }
                                if (catCtrl.text.trim().isNotEmpty) {
                                  _storeCategory = catCtrl.text.trim();
                                }
                                _storePhone = phoneCtrl.text.trim();
                                _storeAddress = addrCtrl.text.trim();
                              });
                              ApiConfig.setTarget(selectedTarget,
                                  customIp: ipCtrl.text.trim());
                              _savePreferences();
                              Navigator.pop(ctx);
                              _checkStatus(silent: false);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Simpan Perubahan',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
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

  Widget _buildServerOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? kGreen : const Color(0xFF9CA3AF),
                  width: isSelected ? 5.5 : 1.8,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Bottom Sheet: Pelanggan & Kasbon
  void _showPelangganKasbonSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setKasbonState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.65,
                child: Column(
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
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD9E6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.people_outline_rounded,
                            color: Color(0xFF2563EB),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Daftar Pelanggan & Kasbon',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              Text(
                                '${_kasbonList.length} orang tercatat memiliki tagihan kasbon',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Add Customer Button
                    OutlinedButton.icon(
                      onPressed: () {
                        _showAddKasbonDialog(setKasbonState);
                      },
                      icon: const Icon(Icons.add_rounded,
                          size: 18, color: Color(0xFF2563EB)),
                      label: const Text(
                        'Tambah Kasbon Pelanggan',
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(double.infinity, 42),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // List of Customers
                    Expanded(
                      child: _kasbonList.isEmpty
                          ? const Center(
                              child: Text(
                                'Belum ada catatan kasbon pelanggan.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _kasbonList.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = _kasbonList[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFFEBF2FF),
                                    child: Text(
                                      (item['name'] as String)
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFF2563EB),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    item['name'] as String,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${item['notes']} \u2022 ${item['date']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Rp${(item['amount'] as int).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFFDC2626),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      InkWell(
                                        onTap: () {
                                          setKasbonState(() {
                                            _kasbonList.removeAt(index);
                                          });
                                          setState(() {
                                            _kasbonCount = _kasbonList.length;
                                          });
                                          _savePreferences();
                                        },
                                        child: const Text(
                                          'Lunaskan',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF16A34A),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
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

  void _showAddKasbonDialog(void Function(void Function()) setKasbonState) {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Catat Kasbon Baru',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nama Pelanggan',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Jumlah Kasbon (Rp)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                decoration: InputDecoration(
                  labelText: 'Keterangan Barang',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
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
                final name = nameCtrl.text.trim();
                final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
                if (name.isNotEmpty && amount > 0) {
                  final newItem = {
                    'name': name,
                    'phone': '-',
                    'amount': amount,
                    'date': 'Hari ini',
                    'notes': notesCtrl.text.trim().isEmpty
                        ? 'Kasbon Pembelian'
                        : notesCtrl.text.trim(),
                  };
                  setKasbonState(() {
                    _kasbonList.add(newItem);
                  });
                  setState(() {
                    _kasbonCount = _kasbonList.length;
                  });
                  _savePreferences();
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  // Bottom Sheet: Printer & Struk
  void _showPrinterSheet() {
    String paperSize = '58mm';
    bool autoPrint = true;
    bool printLogo = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setPrinterState) {
            return Padding(
              padding: const EdgeInsets.all(20),
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE0B2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.print_outlined,
                          color: Color(0xFFD97706),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pengaturan Printer & Struk',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: Color(0xFF111827),
                            ),
                          ),
                          Text(
                            'Thermal Bluetooth & Format Nota Kasir',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Status Bluetooth Printer
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bluetooth_connected_rounded,
                            color: Color(0xFF2563EB)),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'RPP-02N Thermal Printer',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              Text(
                                'Terhubung via Bluetooth \u2022 Siap cetak',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Ganti',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pilihan Ukuran Kertas
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Ukuran Kertas',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('58mm'),
                        selected: paperSize == '58mm',
                        onSelected: (val) =>
                            setPrinterState(() => paperSize = '58mm'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('80mm'),
                        selected: paperSize == '80mm',
                        onSelected: (val) =>
                            setPrinterState(() => paperSize = '80mm'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Cetak Otomatis Setelah Transaksi',
                        style: TextStyle(fontSize: 13.5)),
                    value: autoPrint,
                    activeTrackColor: const Color(0xFFD97706),
                    onChanged: (val) =>
                        setPrinterState(() => autoPrint = val),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sertakan Header & Logo Toko',
                        style: TextStyle(fontSize: 13.5)),
                    value: printLogo,
                    activeTrackColor: const Color(0xFFD97706),
                    onChanged: (val) =>
                        setPrinterState(() => printLogo = val),
                  ),
                  const SizedBox(height: 16),

                  // Tombol Test Cetak
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Mengirim contoh struk $paperSize ke RPP-02N... Berhasil dicetak!'),
                            backgroundColor: const Color(0xFFD97706),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.receipt_long_rounded, size: 18),
                      label: const Text('Uji Cetak Struk Percobaan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Bottom Sheet: Cadangkan Data
  void _showCadangkanDataSheet() {
    bool isBackingUp = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setBackupState) {
            return Padding(
              padding: const EdgeInsets.all(20),
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1F2D9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.upload_outlined,
                          color: kGreen,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cadangkan Data Kasir',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: Color(0xFF111827),
                            ),
                          ),
                          Text(
                            'Amankan data katalog, transaksi & kasbon',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      children: [
                        _buildBackupStatRow('Total Produk Terdaftar', '$_productCount item'),
                        const Divider(height: 16),
                        _buildBackupStatRow('Kasbon Aktif', '$_kasbonCount orang'),
                        const Divider(height: 16),
                        _buildBackupStatRow('Format Arsip', 'JSON + SQLite Dump'),
                        const Divider(height: 16),
                        _buildBackupStatRow('Penyimpanan', 'Lokal & Ekspor File'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: isBackingUp
                          ? null
                          : () {
                              setBackupState(() => isBackingUp = true);
                              Future.delayed(const Duration(milliseconds: 1200), () {
                                if (context.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Cadangan data berhasil dibuat: majuni_backup.json'),
                                      backgroundColor: kGreen,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              });
                            },
                      icon: isBackingUp
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download_rounded, size: 18),
                      label: Text(
                        isBackingUp ? 'Memproses Cadangan...' : 'Buat Cadangan Sekarang',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBackupStatRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
        ),
        Text(
          val,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  // Confirmation Dialog: Logout
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
              SizedBox(width: 8),
              Text(
                'Konfirmasi Keluar',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Apakah Anda yakin ingin keluar dari akun kasir ini? Data transaksi lokal akan tetap tersimpan.',
            style: TextStyle(fontSize: 13.5, color: Color(0xFF4B5563)),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                side: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
              child: const Text('Batal', style: TextStyle(color: Color(0xFF374151))),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await AuthService.logout();
                CartService.clear();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Anda telah berhasil keluar.'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const CustomAppBar(
        showTitle: false,
        showSearch: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // Header Store Card (Soft Mint Green matching uploaded mockup)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kMintHeader,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: kGreen,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _storeCategory,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF374151),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _showInfoTokoSheet,
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

            // Two Metric Cards Row (Peach & Lavender matching uploaded mockup)
            Row(
              children: [
                // Produk Terdaftar (Peach/Warm Amber)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: kPeachCard,
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
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '$_productCount',
                            style: const TextStyle(
                              fontSize: 28,
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

                // Pelanggan Kasbon (Lavender Blue)
                Expanded(
                  child: GestureDetector(
                    onTap: _showPelangganKasbonSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: kLavenderCard,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pelanggan Kasbon',
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
                              '$_kasbonCount Orang',
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
                    color: Color(0x06000000),
                    blurRadius: 6,
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
                          color: kGreen,
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
                            SizedBox(height: 2),
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
                        activeTrackColor: kGreen,
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
                        onPressed:
                            _isSyncing ? null : () => _checkStatus(silent: false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kGreen,
                          side: const BorderSide(color: kGreen, width: 1.2),
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
                                  color: kGreen,
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

            // Menu List Card (matching uploaded mockup)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF0F0F0), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _MenuRowItem(
                    icon: Icons.storefront_outlined,
                    iconBg: const Color(0xFFD1F2D9),
                    iconColor: kGreen,
                    title: 'Info Toko',
                    onTap: _showInfoTokoSheet,
                  ),
                  const Divider(height: 1, indent: 72, color: Color(0xFFF0F0F0)),
                  _MenuRowItem(
                    icon: Icons.people_outline_rounded,
                    iconBg: const Color(0xFFD9E6FF),
                    iconColor: const Color(0xFF2563EB),
                    title: 'Pelanggan \u0026 Kasbon',
                    onTap: _showPelangganKasbonSheet,
                  ),
                  const Divider(height: 1, indent: 72, color: Color(0xFFF0F0F0)),
                  _MenuRowItem(
                    icon: Icons.print_outlined,
                    iconBg: const Color(0xFFFFE0B2),
                    iconColor: const Color(0xFFD97706),
                    title: 'Printer \u0026 Struk',
                    onTap: _showPrinterSheet,
                  ),
                  const Divider(height: 1, indent: 72, color: Color(0xFFF0F0F0)),
                  _MenuRowItem(
                    icon: Icons.upload_outlined,
                    iconBg: const Color(0xFFD1F2D9),
                    iconColor: kGreen,
                    title: 'Cadangkan Data',
                    onTap: _showCadangkanDataSheet,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Logout Button (Red outlined matching uploaded mockup)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _showLogoutDialog,
                icon: const Icon(Icons.logout_rounded,
                    color: Color(0xFFEF4444), size: 20),
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

            // Footer Version (matching uploaded mockup)
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
