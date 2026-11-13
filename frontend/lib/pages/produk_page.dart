import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/api_config.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';

class ProdukPage extends StatefulWidget {
  const ProdukPage({super.key});

  @override
  State<ProdukPage> createState() => _ProdukPageState();
}

class _ProdukPageState extends State<ProdukPage> {
  static const Color kGreen = Color(0xFF1E874B);
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'Semua';
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
    _searchCtrl.dispose();
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

  List<Map<String, dynamic>> get _filtered {
    return _products.where((p) {
      final name = (p['name'] as String? ?? '').toLowerCase();
      final cat = (p['category'] as String? ?? p['jenis'] as String? ?? '').toLowerCase();
      final barcode = (p['barcode'] as String? ?? '').toLowerCase();

      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          cat.contains(_searchQuery.toLowerCase()) ||
          barcode.contains(_searchQuery.toLowerCase());

      final matchesCat = _selectedCategory == 'Semua' ||
          cat.contains(_selectedCategory.toLowerCase());

      return matchesSearch && matchesCat;
    }).toList();
  }

  int get _lowStockCount =>
      _products.where((p) => ApiService.isLowStock(p)).length;

  // Galeri preset gambar produk (base64 PNG 1x1 + kode preset visual)
  static const List<Map<String, String>> _imagePresets = [
    {
      'key': 'preset:beras',
      'label': 'Beras / Sembako',
      'base64':
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    },
    {
      'key': 'preset:minyak',
      'label': 'Minyak / Cairan',
      'base64':
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    },
    {
      'key': 'preset:minuman',
      'label': 'Minuman / Kopi',
      'base64':
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPj/HwADBwIAMCbHYQAAAABJRU5ErkJggg==',
    },
    {
      'key': 'preset:makanan',
      'label': 'Makanan / Snack',
      'base64':
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==',
    },
  ];

  /// Dialog untuk memilih / upload gambar produk (dari file perangkat, URL, atau preset galeri)
  Future<void> _showPickImageSheet({
    required BuildContext parentContext,
    required String? currentImage,
    required void Function(String imageValue, String imageLabel) onPicked,
  }) async {
    final pathCtrl = TextEditingController(
      text: (currentImage != null && !currentImage.startsWith('data:image'))
          ? currentImage
          : '',
    );

    await showDialog(
      context: parentContext,
      builder: (dCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.add_photo_alternate_rounded, color: kGreen),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Upload Gambar Produk',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tombol pilih file dari perangkat (Windows native picker jika tersedia)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (!kIsWeb && Platform.isWindows) {
                        try {
                          final result = await Process.run('powershell', [
                            '-NoProfile',
                            '-Command',
                            "Add-Type -AssemblyName System.Windows.Forms; \$f = New-Object System.Windows.Forms.OpenFileDialog; \$f.Filter = 'Image Files (*.png;*.jpg;*.jpeg;*.webp)|*.png;*.jpg;*.jpeg;*.webp'; if (\$f.ShowDialog() -eq 'OK') { Write-Output \$f.FileName }",
                          ]);
                          final pickedPath = result.stdout.toString().trim();
                          if (pickedPath.isNotEmpty) {
                            final file = File(pickedPath);
                            if (await file.exists()) {
                              final bytes = await file.readAsBytes();
                              final b64 = 'data:image/png;base64,${base64Encode(bytes)}';
                              final fileName = pickedPath.split(RegExp(r'[\\/]')).last;
                              if (dCtx.mounted) Navigator.pop(dCtx);
                              onPicked(b64, fileName);
                              return;
                            }
                          }
                        } catch (_) {}
                      }
                      // Fallback: gunakan gambar sample produk langsung jika dialog native tidak dipakai
                      final first = _imagePresets.first;
                      if (dCtx.mounted) Navigator.pop(dCtx);
                      onPicked(
                        'data:image/png;base64,${first['base64']}',
                        first['label']!,
                      );
                    },
                    icon: const Icon(Icons.folder_open_rounded, color: kGreen, size: 18),
                    label: const Text(
                      'Pilih File dari Perangkat',
                      style: TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kGreen),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Atau Pilih Cepat dari Galeri Produk:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _imagePresets.map((preset) {
                    return ActionChip(
                      avatar: const Icon(Icons.image_outlined, size: 16, color: kGreen),
                      label: Text(
                        preset['label']!,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: const Color(0xFFE8F5E9),
                      onPressed: () {
                        Navigator.pop(dCtx);
                        onPicked(
                          'data:image/png;base64,${preset['base64']}',
                          preset['label']!,
                        );
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Atau Path File / URL Gambar:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: pathCtrl,
                  decoration: InputDecoration(
                    hintText: 'Misal: C:/foto/beras.png atau https://...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final raw = pathCtrl.text.trim();
                if (raw.isNotEmpty) {
                  if (!kIsWeb && !raw.startsWith('http')) {
                    try {
                      final f = File(raw);
                      if (await f.exists()) {
                        final bytes = await f.readAsBytes();
                        final name = raw.split(RegExp(r'[\\/]')).last;
                        if (dCtx.mounted) Navigator.pop(dCtx);
                        onPicked('data:image/png;base64,${base64Encode(bytes)}', name);
                        return;
                      }
                    } catch (_) {}
                  }
                  if (dCtx.mounted) Navigator.pop(dCtx);
                  onPicked(raw, raw.split(RegExp(r'[\\/]')).last);
                } else {
                  final first = _imagePresets.first;
                  if (dCtx.mounted) Navigator.pop(dCtx);
                  onPicked('data:image/png;base64,${first['base64']}', first['label']!);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Gunakan Gambar'),
            ),
          ],
        );
      },
    );
  }

  /// Modal dialog / Bottom sheet untuk menambah produk baru lengkap dari gambar, nama, satuan, modal, harga jual, hingga jenis/kategori
  void _showAddProductDialog() {
    final nameCtrl = TextEditingController();
    final weightCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '0');
    final costPriceCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    String selectedCategory = 'Umum';
    bool isCustomCategory = false;
    final customCategoryCtrl = TextEditingController();

    String selectedUnit = 'pcs';
    bool unitManuallySelected = false;
    String? selectedImage;
    String? selectedImageLabel;

    final categories = [
      'Sembako',
      'Makanan',
      'Minuman',
      'Snack',
      'Umum',
      'Lainnya',
    ];

    final units = [
      'pcs',
      'kg',
      'liter',
      'gram',
      'bungkus',
      'botol',
      'kemasan',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header Info
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add_business_rounded, color: kGreen, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tambah Produk Baru',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              Text(
                                'Masukkan nama, berat, harga, dan jenis',
                                style: TextStyle(fontSize: 11.5, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, color: Colors.grey),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // 0. Upload Gambar Produk (P1)
                    const Text(
                      'Gambar Produk',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        _showPickImageSheet(
                          parentContext: context,
                          currentImage: selectedImage,
                          onPicked: (imgVal, imgLabel) {
                            setDialogState(() {
                              selectedImage = imgVal;
                              selectedImageLabel = imgLabel;
                            });
                          },
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: selectedImage != null ? const Color(0xFFE8F5E9) : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedImage != null ? kGreen : const Color(0xFFD1D5DB),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: selectedImage != null ? Colors.white : const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: selectedImage != null
                                  ? _buildProductImageWidget(
                                      selectedImage!,
                                      fallbackIcon: Icons.check_circle_rounded,
                                      fallbackColor: kGreen,
                                    )
                                  : const Icon(Icons.add_photo_alternate_outlined, color: kGreen, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedImage != null
                                        ? 'Gambar Terpilih: ${selectedImageLabel ?? "Foto Produk"}'
                                        : 'Upload Gambar',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: selectedImage != null ? kGreen : const Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    selectedImage != null
                                        ? 'Ketuk untuk mengganti foto produk'
                                        : 'Pilih foto produk dari perangkat atau galeri',
                                    style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            if (selectedImage != null)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                onPressed: () {
                                  setDialogState(() {
                                    selectedImage = null;
                                    selectedImageLabel = null;
                                  });
                                },
                              )
                            else
                              const Icon(Icons.upload_file_rounded, color: kGreen, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 1. Nama Produk
                    const Text(
                      'Nama Produk *',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'Misal: Beras Ramos, Kopi ABC, dll',
                        prefixIcon: const Icon(Icons.shopping_bag_outlined, color: kGreen, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 2. Jenis / Kategori Produk
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Jenis Produk *',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                        ),
                        Text(
                          selectedCategory,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kGreen),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((cat) {
                        final isSel = selectedCategory == cat;
                        return ChoiceChip(
                          label: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              color: isSel ? Colors.white : const Color(0xFF374151),
                            ),
                          ),
                          selected: isSel,
                          selectedColor: kGreen,
                          backgroundColor: Colors.grey.shade100,
                          showCheckmark: false,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSel ? kGreen : Colors.grey.shade300,
                            ),
                          ),
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() {
                                selectedCategory = cat;
                                isCustomCategory = (cat == 'Lainnya');
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),

                    if (isCustomCategory) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: customCategoryCtrl,
                        decoration: InputDecoration(
                          hintText: 'Ketik jenis kustom (misal: ATK)',
                          prefixIcon: const Icon(Icons.edit_note, color: kGreen, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // 2b. Jenis Satuan Produk (P1: kg, liter, gram, pcs, dll)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Jenis Satuan Produk *',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                        ),
                        Text(
                          '/$selectedUnit',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kGreen),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: units.map((u) {
                        final isSel = selectedUnit == u;
                        return ChoiceChip(
                          label: Text(
                            u,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              color: isSel ? Colors.white : const Color(0xFF374151),
                            ),
                          ),
                          selected: isSel,
                          selectedColor: kGreen,
                          backgroundColor: Colors.grey.shade100,
                          showCheckmark: false,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSel ? kGreen : Colors.grey.shade300,
                            ),
                          ),
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() {
                                selectedUnit = u;
                                unitManuallySelected = true;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // 3. Berat & Stok
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Berat / Ukuran',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: weightCtrl,
                                onChanged: (val) {
                                  if (!unitManuallySelected) {
                                    final lower = val.toLowerCase();
                                    if (lower.contains('kg') || lower.contains('kilo')) {
                                      setDialogState(() => selectedUnit = 'kg');
                                    } else if (lower.contains('liter') || RegExp(r'\d+\s*l\b').hasMatch(lower)) {
                                      setDialogState(() => selectedUnit = 'liter');
                                    } else if (lower.contains('gram') || RegExp(r'\d+\s*g\b').hasMatch(lower)) {
                                      setDialogState(() => selectedUnit = 'gram');
                                    }
                                  }
                                },
                                decoration: InputDecoration(
                                  hintText: 'Misal: 5kg, 500g',
                                  prefixIcon: const Icon(Icons.scale, color: Colors.grey, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                                'Stok Awal',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: stockCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'Misal: 10',
                                  prefixIcon: const Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 4. Harga Modal per satuan/pcs (P1) & Harga Jual
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Harga Modal / $selectedUnit',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: costPriceCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: '28000',
                                  prefixText: 'Rp ',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                                'Harga Jual *',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: priceCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: '35000',
                                  prefixText: 'Rp ',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final name = nameCtrl.text.trim();
                              final weight = weightCtrl.text.trim();
                              final costPrice = int.tryParse(costPriceCtrl.text.trim().replaceAll('.', '')) ?? 0;
                              final price = int.tryParse(priceCtrl.text.trim().replaceAll('.', '')) ?? 0;
                              final stock = int.tryParse(stockCtrl.text.trim()) ?? 0;

                              String category = selectedCategory;
                              if (isCustomCategory && customCategoryCtrl.text.trim().isNotEmpty) {
                                category = customCategoryCtrl.text.trim();
                              }

                              if (name.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Nama produk wajib diisi!'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }

                              if (price <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Harga jual harus lebih dari Rp 0!'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }

                              Navigator.pop(ctx);
                              setState(() => _isLoading = true);

                              await ApiService.addProduct(
                                name: name,
                                price: price,
                                costPrice: costPrice,
                                stock: stock,
                                initialStock: stock,
                                unit: selectedUnit,
                                category: category,
                                weight: weight,
                                image: selectedImage,
                              );

                              await _loadProducts();

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle, color: Colors.white),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Produk "$name" berhasil ditambahkan!',
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: kGreen,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.check, size: 20),
                            label: const Text('Simpan Produk', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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

  void _confirmDelete(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Produk', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin menghapus produk "${item['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService.deleteProduct(item['id'] ?? item['name']);
              await _loadProducts();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Produk "${item['name']}" berhasil dihapus'),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: RefreshIndicator(
          color: kGreen,
          onRefresh: _loadProducts,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),

                // Summary Cards Row
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
                                              fontSize: 15,
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

                // Search Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Cari nama produk, jenis, atau barcode...',
                      hintStyle: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 13.5,
                      ),
                      icon: const Icon(Icons.search, color: Color(0xFF6B7280), size: 22),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Kategori Filter Chips Horizontal
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      'Semua',
                      'Sembako',
                      'Makanan',
                      'Minuman',
                      'Snack',
                      'Bumbu Dapur',
                      'Kebutuhan Rumah',
                      'Lainnya',
                    ].map((cat) {
                      final isSel = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                              color: isSel ? Colors.white : const Color(0xFF374151),
                            ),
                          ),
                          selected: isSel,
                          selectedColor: kGreen,
                          backgroundColor: Colors.white,
                          checkmarkColor: Colors.white,
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSel ? kGreen : const Color(0xFFE5E7EB),
                            ),
                          ),
                          onSelected: (val) {
                            setState(() {
                              _selectedCategory = cat;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Daftar Produk Header
                Row(
                  children: [
                    const Text(
                      'Daftar Produk',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_filtered.length} produk',
                        style: const TextStyle(
                          fontSize: 12,
                          color: kGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Product List
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
                    child: Column(
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 54, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          'Belum ada produk ditemukan',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tambahkan produk baru dengan menekan tombol di bawah',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showAddProductDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Tambah Produk', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: [
                      ..._filtered.map((item) {
                        return _ProductCardItem(
                          product: item,
                          formatRp: _formatRp,
                          onAdd: () {
                            final int stock = (item['stock'] as int?) ?? 0;
                            final String unit = (item['unit'] as String?)?.trim().isNotEmpty == true
                                ? (item['unit'] as String).trim()
                                : 'pcs';
                            final int costPrice = (item['cost_price'] as num?)?.toInt() ?? 0;
                            final String? image = item['image'] as String?;
                            final String? category = (item['category'] ?? item['jenis'])?.toString();
                            final added = CartService.addItem(
                              item['name'] as String,
                              (item['price'] as int?) ?? 0,
                              unit,
                              maxStock: stock,
                              productId: item['id'],
                              costPrice: costPrice,
                              image: image,
                              category: category,
                            );
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  added
                                      ? '${item['name']} ($unit) ditambahkan ke keranjang!'
                                      : 'Stok ${item['name']} tidak mencukupi (stok: $stock $unit)!',
                                ),
                                backgroundColor: added ? kGreen : Colors.redAccent,
                                duration: const Duration(milliseconds: 1400),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          onDelete: () => _confirmDelete(item),
                        );
                      }),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _showAddProductDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text(
                          'Tambah Produk',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Color(0xFFE8F5E9),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_rounded,
            color: Color(0xFF1E874B),
            size: 28,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Produk',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_products.length} produk terdaftar',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
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

/// Helper untuk menampilkan gambar produk (base64, URL, atau file lokal)
Widget _buildProductImageWidget(
  String imageSource, {
  required IconData fallbackIcon,
  required Color fallbackColor,
}) {
  final src = imageSource.trim();
  if (src.startsWith('data:image')) {
    try {
      final commaIdx = src.indexOf(',');
      if (commaIdx != -1) {
        final bytes = base64Decode(src.substring(commaIdx + 1));
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, _, _) => Icon(fallbackIcon, color: fallbackColor, size: 24),
        );
      }
    } catch (_) {}
  } else if (src.startsWith('http://') || src.startsWith('https://')) {
    return Image.network(
      src,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => Icon(fallbackIcon, color: fallbackColor, size: 24),
    );
  } else if (!kIsWeb && src.isNotEmpty) {
    final file = File(src);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => Icon(fallbackIcon, color: fallbackColor, size: 24),
      );
    }
  }
  return Icon(fallbackIcon, color: fallbackColor, size: 24);
}

// ─────────────────────────────────────────────
// INDIVIDUAL PRODUCT CARD
// ─────────────────────────────────────────────
class _ProductCardItem extends StatelessWidget {
  final Map<String, dynamic> product;
  final String Function(int) formatRp;
  final VoidCallback onAdd;
  final VoidCallback onDelete;

  const _ProductCardItem({
    required this.product,
    required this.formatRp,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final int stock = (product['stock'] as int?) ?? 0;
    final bool low = ApiService.isLowStock(product);
    final int price = (product['price'] as int?) ?? (product['selling_price'] as int?) ?? 0;
    final int costPrice = (product['cost_price'] as num?)?.toInt() ?? 0;
    final String unit = (product['unit'] as String?)?.trim().isNotEmpty == true
        ? (product['unit'] as String).trim()
        : 'pcs';
    final String name = product['name']?.toString() ?? '';
    final String category = (product['category'] ?? product['jenis'] ?? '').toString();
    final String image = (product['image'] ?? '').toString().trim();

    // Icon & Color according to category
    IconData iconData = Icons.inventory_2_outlined;
    Color iconColor = const Color(0xFFD97706);
    Color bgColor = const Color(0xFFFFE0B2);

    if (low) {
      iconData = Icons.error_outline_rounded;
      iconColor = const Color(0xFFDC2626);
      bgColor = const Color(0xFFFFCDD2);
    } else {
      final catLower = category.toLowerCase();
      if (catLower.contains('minum') || catLower.contains('kopi') || catLower.contains('teh')) {
        iconData = Icons.local_drink_outlined;
        iconColor = const Color(0xFF0284C7);
        bgColor = const Color(0xFFE0F2FE);
      } else if (catLower.contains('makan') || catLower.contains('snack') || catLower.contains('mie')) {
        iconData = Icons.fastfood_outlined;
        iconColor = const Color(0xFFEA580C);
        bgColor = const Color(0xFFFFEDD5);
      } else if (catLower.contains('sembako') || catLower.contains('beras') || catLower.contains('minyak')) {
        iconData = Icons.shopping_basket_outlined;
        iconColor = const Color(0xFF16A34A);
        bgColor = const Color(0xFFDCFCE7);
      }
    }

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
          // Icon or Uploaded Image Container
          Container(
            width: 48,
            height: 48,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: image.isNotEmpty
                ? _buildProductImageWidget(
                    image,
                    fallbackIcon: iconData,
                    fallbackColor: iconColor,
                  )
                : Icon(
                    iconData,
                    color: iconColor,
                    size: 24,
                  ),
          ),
          const SizedBox(width: 14),

          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF111827),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (category.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      formatRp(price),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E874B),
                      ),
                    ),
                    Text(
                      ' / $unit',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                if (costPrice > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Modal: ${formatRp(costPrice)} / $unit',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF4B5563),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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
          const SizedBox(width: 8),

          // Action Button: "Tambah" ke keranjang
          OutlinedButton(
            onPressed: onAdd,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E874B),
              side: const BorderSide(color: Color(0xFF1E874B), width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Tambah',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),

          // Delete options popup
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
            padding: EdgeInsets.zero,
            onSelected: (val) {
              if (val == 'delete') onDelete();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Hapus Produk', style: TextStyle(color: Colors.red, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
