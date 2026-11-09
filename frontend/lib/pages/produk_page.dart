import 'package:flutter/material.dart';
import '../services/api_config.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../widgets/custom_app_bar.dart';

class ProdukPage extends StatefulWidget {
  const ProdukPage({super.key});

  @override
  State<ProdukPage> createState() => _ProdukPageState();
}

class _ProdukPageState extends State<ProdukPage> {
  static const Color kGreen = Color(0xFF1E874B);
  String _searchQuery = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
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
    if (mounted) _loadProducts();
  }

  void _onUrlChanged() {
    if (mounted) _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getProducts();
    if (!mounted) return;
    setState(() {
      _products = data;
      _isLoading = false;
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

  List<Map<String, dynamic>> get _filtered => _searchQuery.isEmpty
      ? _products
      : _products
          .where((p) =>
              (p['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();

  int get _lowStockCount =>
      _products.where((p) => p['low'] == true || (p['stock'] as int) <= 5).length;

  void _showAddProductDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    String unit = 'kemasan';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.add_box_rounded, color: kGreen),
                  SizedBox(width: 8),
                  Text('Tambah Produk Baru',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nama Produk',
                        hintText: 'Misal: Minyak Goreng 2L',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Harga Jual (Rp)',
                        hintText: 'Misal: 35000',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixText: 'Rp ',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: stockCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Stok',
                              hintText: 'Misal: 20',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: unit,
                            decoration: const InputDecoration(
                              labelText: 'Satuan',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'kemasan', child: Text('kemasan')),
                              DropdownMenuItem(value: 'botol', child: Text('botol')),
                              DropdownMenuItem(value: 'bungkus', child: Text('bungkus')),
                              DropdownMenuItem(value: 'sachet', child: Text('sachet')),
                              DropdownMenuItem(value: 'buah', child: Text('buah')),
                              DropdownMenuItem(value: 'kg', child: Text('kg')),
                            ],
                            onChanged: (v) {
                              if (v != null) setDialogState(() => unit = v);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final price = int.tryParse(priceCtrl.text.trim()) ?? 0;
                    final stock = int.tryParse(stockCtrl.text.trim()) ?? 0;

                    if (name.isEmpty || price <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Nama dan harga produk harus diisi dengan benar!')),
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);

                    await ApiService.addProduct(
                      name: name,
                      price: price,
                      stock: stock,
                      unit: unit,
                    );

                    await _loadProducts();

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Produk "$name" berhasil ditambahkan!'),
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
                  child: const Text('Simpan'),
                ),
              ],
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
        title: 'Produk',
        subtitle: 'Toko Anda \u2022 Mode Offline',
        onSearchPressed: () {},
        onNotificationPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak ada notifikasi baru'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 1),
            ),
          );
        },
      ),
      body: RefreshIndicator(
        color: kGreen,
        onRefresh: _loadProducts,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards Row (matching Image 1)
              Row(
                children: [
                  // Total Produk Card (Mint Green)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA5D6A7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8F5E9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              color: Color(0xFF1E874B),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Produk',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF374151),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${_products.length}',
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Stok Menipis Card (Soft Coral / Red)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF8A80),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFEBEE),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFC62828),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Stok Menipis',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF374151),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '$_lowStockCount ',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        const TextSpan(
                                          text: 'Produk',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Bar (Rounded outline, placeholder 'Cari nama produk atau barcode')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(
                    hintText: 'Cari nama produk atau barcode',
                    hintStyle: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 13.5,
                    ),
                    icon: Icon(Icons.search, color: Color(0xFF6B7280), size: 22),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Daftar Produk Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Daftar Produk',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Color(0xFF111827),
                    ),
                  ),
                  Text(
                    '${_filtered.length} produk',
                    style: const TextStyle(
                      fontSize: 14,
                      color: kGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Product List (Individual Cards)
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: kGreen),
                  ),
                )
              else if (_filtered.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Tidak ada produk ditemukan', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              else
                Column(
                  children: _filtered.map((item) {
                    return _ProductCardItem(
                      product: item,
                      formatRp: _formatRp,
                      onAdd: () {
                        CartService.addItem(
                          item['name'] as String,
                          (item['price'] as int?) ?? 0,
                          (item['unit'] as String?) ?? 'kemasan',
                        );
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${item['name']} ditambahkan ke keranjang!'),
                            backgroundColor: kGreen,
                            duration: const Duration(milliseconds: 1200),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProductDialog,
        backgroundColor: kGreen,
        tooltip: 'Tambah Produk',
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// INDIVIDUAL PRODUCT CARD (Exact match to Image 1)
// ─────────────────────────────────────────────
class _ProductCardItem extends StatelessWidget {
  final Map<String, dynamic> product;
  final String Function(int) formatRp;
  final VoidCallback onAdd;

  const _ProductCardItem({
    required this.product,
    required this.formatRp,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final int stock = (product['stock'] as int?) ?? 0;
    final bool low = (product['low'] == true) || stock <= 5;
    final int price = (product['price'] as int?) ?? 0;
    final String unit = (product['unit'] as String?) ?? 'kemasan';
    final String name = product['name']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
      child: Row(
        children: [
          // Icon Container
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: low ? const Color(0xFFFFCDD2) : const Color(0xFFFFE0B2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: low ? const Color(0xFFDC2626) : const Color(0xFFD97706),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),

          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  formatRp(price),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E874B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  low ? 'Stok tersisa: $stock $unit' : 'Stok: $stock $unit',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: low ? FontWeight.w600 : FontWeight.normal,
                    color: low ? const Color(0xFFB91C1C) : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),

          // Action Button: "Tambah"
          OutlinedButton(
            onPressed: onAdd,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E874B),
              side: const BorderSide(color: Color(0xFF1E874B), width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Tambah',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
