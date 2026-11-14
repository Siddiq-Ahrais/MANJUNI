import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const MethodChannel _deviceChannel =
      MethodChannel('com.example.majunih/file_export');
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
    CartService.cartNotifier.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    ApiConfig.baseUrlNotifier.removeListener(_onUrlChanged);
    ApiService.dataChangedNotifier.removeListener(_onDataChanged);
    CartService.cartNotifier.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
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
    CartService.syncStockLimits(data);
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

  int _remainingStockFor(Map<String, dynamic> p) {
    final int rawStock = (p['stock'] as num?)?.toInt() ?? 0;
    final int inCart = CartService.qtyForProduct(
      productId: p['id'],
      name: p['name']?.toString() ?? '',
    );
    return (rawStock - inCart).clamp(0, rawStock);
  }

  int get _lowStockCount => _products
      .where((p) => ApiService.isLowStock({...p, 'stock': _remainingStockFor(p)}))
      .length;

  Future<Map<String, String>?> _pickImageFromDevice({
    void Function(String message)? onError,
  }) async {
    ApiService.isPickingExternalFile = true;
    try {
      try {
        final picked = await _deviceChannel.invokeMapMethod<String, dynamic>('pickImage');
        if (picked != null && (picked['base64'] as String?)?.isNotEmpty == true) {
          return {
            'base64': picked['base64'] as String,
            'name': (picked['name'] as String?) ?? 'Foto Produk',
          };
        }
        if (!kIsWeb && Platform.isAndroid) {
          return null;
        }
      } on MissingPluginException {
        if (!kIsWeb && Platform.isAndroid) {
          onError?.call(
            'Pemilih file perangkat belum aktif. Silakan build ulang aplikasi Android.',
          );
          return null;
        }
      } catch (e) {
        onError?.call('Gagal memilih file gambar: $e');
        return null;
      }

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
              final ext = pickedPath.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
              final b64 = 'data:image/$ext;base64,${base64Encode(bytes)}';
              final fileName = pickedPath.split(RegExp(r'[\\/]')).last;
              return {'base64': b64, 'name': fileName};
            }
          }
        } catch (e) {
          onError?.call('Gagal membuka pemilih file Windows: $e');
        }
      }
      return null;
    } finally {
      ApiService.isPickingExternalFile = false;
    }
  }

  /// Dialog untuk memilih file gambar produk langsung dari folder perangkat
  Future<void> _showPickImageSheet({
    required BuildContext parentContext,
    required void Function(String imageValue, String imageLabel) onPicked,
  }) async {
    String? errorMsg;

    await showDialog(
      context: parentContext,
      builder: (dCtx) {
        return StatefulBuilder(
          builder: (dCtx, setLocalState) {
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
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pilih file foto produk langsung dari folder di perangkat Anda.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF4B5563)),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        setLocalState(() => errorMsg = null);
                        final picked = await _pickImageFromDevice(
                          onError: (msg) {
                            if (dCtx.mounted) {
                              setLocalState(() => errorMsg = msg);
                            }
                          },
                        );
                        if (picked != null) {
                          if (dCtx.mounted) Navigator.pop(dCtx);
                          onPicked(picked['base64']!, picked['name']!);
                        }
                      },
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: const Text(
                        'Pilih File dari Perangkat',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      ),
                    ),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMsg!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx),
                  child: const Text('Batal'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddProductDialog() => _showProductFormDialog();

  void _showEditProductDialog(Map<String, dynamic> product) =>
      _showProductFormDialog(existingProduct: product);

  /// Modal dialog / Bottom sheet untuk menambah atau mengedit detail & foto produk
  void _showProductFormDialog({Map<String, dynamic>? existingProduct}) {
    final bool isEdit = existingProduct != null;
    final nameCtrl = TextEditingController(
      text: isEdit ? (existingProduct['name']?.toString() ?? '') : '',
    );
    final weightCtrl = TextEditingController(
      text: isEdit ? (existingProduct['weight']?.toString() ?? '') : '',
    );
    final stockCtrl = TextEditingController(
      text: isEdit ? '${(existingProduct['stock'] as num?)?.toInt() ?? 0}' : '0',
    );
    final int existingCost = isEdit
        ? ((existingProduct['base_cost_price'] as num?)?.toInt() ??
            (existingProduct['cost_price'] as num?)?.toInt() ??
            0)
        : 0;
    final costPriceCtrl = TextEditingController(
      text: existingCost > 0 ? '$existingCost' : '',
    );
    final int existingShipping =
        isEdit ? ((existingProduct['shipping_cost'] as num?)?.toInt() ?? 0) : 0;
    final shippingCostCtrl = TextEditingController(
      text: existingShipping > 0 ? '$existingShipping' : '',
    );
    final int existingPrice = isEdit
        ? ((existingProduct['price'] as num?)?.toInt() ??
            (existingProduct['selling_price'] as num?)?.toInt() ??
            0)
        : 0;
    final priceCtrl = TextEditingController(
      text: existingPrice > 0 ? '$existingPrice' : '',
    );

    // FocusNode & GlobalKey untuk mengarahkan kursor otomatis ke kolom wajib yang belum diisi
    final nameFocusNode = FocusNode();
    final customCategoryFocusNode = FocusNode();
    final stockFocusNode = FocusNode();
    final priceFocusNode = FocusNode();
    final nameFieldKey = GlobalKey();
    final customCategoryFieldKey = GlobalKey();
    final stockFieldKey = GlobalKey();
    final priceFieldKey = GlobalKey();

    String? nameError;
    String? customCategoryError;
    String? stockError;
    String? priceError;

    void focusRequiredField(FocusNode focusNode, GlobalKey fieldKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final fieldCtx = fieldKey.currentContext;
        if (fieldCtx != null) {
          Scrollable.ensureVisible(
            fieldCtx,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: 0.25,
          );
        }
        focusNode.requestFocus();
      });
    }

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
      'ml',
      'gram',
      'bungkus',
      'botol',
      'kemasan',
    ];

    final pageContext = context;
    String? dialogError;
    String selectedCategory =
        (_selectedCategory != 'Semua' && categories.contains(_selectedCategory))
            ? _selectedCategory
            : 'Umum';
    bool isCustomCategory = false;
    final customCategoryCtrl = TextEditingController();
    if (isEdit) {
      final rawCat =
          (existingProduct['category'] ?? existingProduct['jenis'] ?? 'Umum')
              .toString()
              .trim();
      if (rawCat.isNotEmpty) {
        final matched = categories.firstWhere(
          (c) => c.toLowerCase() == rawCat.toLowerCase(),
          orElse: () => '',
        );
        if (matched.isNotEmpty) {
          selectedCategory = matched;
          isCustomCategory = (matched == 'Lainnya');
        } else {
          selectedCategory = 'Lainnya';
          isCustomCategory = true;
          customCategoryCtrl.text = rawCat;
        }
      }
    }

    String selectedUnit = 'pcs';
    bool unitManuallySelected = isEdit;
    if (isEdit) {
      final rawUnit = existingProduct['unit']?.toString().trim() ?? '';
      if (rawUnit.isNotEmpty) {
        selectedUnit = rawUnit;
        if (!units.contains(rawUnit)) {
          units.add(rawUnit);
        }
      }
    }

    final rawImg =
        isEdit ? (existingProduct['image']?.toString().trim() ?? '') : '';
    String? selectedImage = rawImg.isNotEmpty ? rawImg : null;
    String? selectedImageLabel =
        selectedImage != null ? 'Foto Produk Tersimpan' : null;

    showModalBottomSheet(
      context: pageContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setDialogState) {
            final int previewBaseCost = int.tryParse(
                  costPriceCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), ''),
                ) ??
                0;
            final int previewShipping = int.tryParse(
                  shippingCostCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), ''),
                ) ??
                0;
            final int previewStock = int.tryParse(
                  stockCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), ''),
                ) ??
                0;
            final int previewSellPrice = int.tryParse(
                  priceCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), ''),
                ) ??
                0;
            final int effectiveQty = previewStock > 0 ? previewStock : 1;
            final int previewShippingPerUnit = previewShipping > 0
                ? (previewShipping / effectiveQty).round()
                : 0;
            final int previewHpp = ApiService.calculateHppPerUnit(
              baseCostPrice: previewBaseCost,
              stockCount: previewStock,
              shippingCost: previewShipping,
            );
            final int previewGrossProfit = previewSellPrice - previewHpp;
            final double previewMarkup = previewHpp > 0
                ? ((previewGrossProfit / previewHpp) * 100)
                : 0.0;
            final double previewMargin = previewSellPrice > 0
                ? ((previewGrossProfit / previewSellPrice) * 100)
                : 0.0;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.98,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 6,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      width: 42,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Header Info
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isEdit ? Icons.edit_note_rounded : Icons.add_business_rounded,
                          color: kGreen,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdit ? 'Edit Produk' : 'Tambah Produk Baru',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                            Text(
                              isEdit
                                  ? 'Perbarui foto, nama, berat, harga, dan stok'
                                  : 'Kolom bertanda (*) wajib diisi, lainnya opsional',
                              style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                      ),
                    ],
                  ),
                  const Divider(height: 8),

                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 0. Upload Gambar Produk (P1 - Opsional)
                          const Text(
                            'Gambar Produk',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                          ),
                          const SizedBox(height: 2),
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              _showPickImageSheet(
                                parentContext: context,
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: selectedImage != null ? const Color(0xFFE8F5E9) : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selectedImage != null ? kGreen : const Color(0xFFD1D5DB),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: selectedImage != null ? Colors.white : const Color(0xFFE8F5E9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: selectedImage != null
                                        ? _buildProductImageWidget(
                                            selectedImage!,
                                            fallbackIcon: Icons.check_circle_rounded,
                                            fallbackColor: kGreen,
                                          )
                                        : const Icon(Icons.add_photo_alternate_outlined, color: kGreen, size: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          selectedImage != null
                                              ? 'Gambar Terpilih: ${selectedImageLabel ?? "Foto Produk"}'
                                              : 'Upload Gambar',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: selectedImage != null ? kGreen : const Color(0xFF111827),
                                          ),
                                        ),
                                        Text(
                                          selectedImage != null
                                              ? 'Ketuk untuk mengganti foto produk'
                                              : 'Pilih file foto produk dari perangkat (opsional)',
                                          style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (selectedImage != null)
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                                      onPressed: () {
                                        setDialogState(() {
                                          selectedImage = null;
                                          selectedImageLabel = null;
                                        });
                                      },
                                    )
                                  else
                                    const Icon(Icons.upload_file_rounded, color: kGreen, size: 16),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),

                          // 1. Nama Produk (Wajib)
                          const Text(
                            'Nama Produk *',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                          ),
                          const SizedBox(height: 2),
                          TextField(
                            key: nameFieldKey,
                            controller: nameCtrl,
                            focusNode: nameFocusNode,
                            onChanged: (_) {
                              if (nameError != null || dialogError != null) {
                                setDialogState(() {
                                  nameError = null;
                                  dialogError = null;
                                });
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'Misal: Beras Ramos, Kopi ABC, dll',
                              errorText: nameError,
                              prefixIcon: const Icon(Icons.shopping_bag_outlined, color: kGreen, size: 16),
                              prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 28),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                          ),
                          const SizedBox(height: 5),

                          // 2. Jenis / Kategori Produk
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Jenis Produk *',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                              ),
                              Text(
                                selectedCategory,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kGreen),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: categories.map((cat) {
                              final isSel = selectedCategory == cat;
                              return ChoiceChip(
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                label: Text(
                                  cat,
                                  style: TextStyle(
                                    fontSize: 11.5,
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
                                      customCategoryError = null;
                                    });
                                  }
                                },
                              );
                            }).toList(),
                          ),

                          if (isCustomCategory) ...[
                            const SizedBox(height: 6),
                            TextField(
                              key: customCategoryFieldKey,
                              controller: customCategoryCtrl,
                              focusNode: customCategoryFocusNode,
                              onChanged: (_) {
                                if (customCategoryError != null || dialogError != null) {
                                  setDialogState(() {
                                    customCategoryError = null;
                                    dialogError = null;
                                  });
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'Ketik jenis kustom * (misal: ATK)',
                                errorText: customCategoryError,
                                prefixIcon: const Icon(Icons.edit_note, color: kGreen, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],

                          const SizedBox(height: 5),

                          // 2b. Jenis Satuan Produk (P1: kg, liter, gram, pcs, dll)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Jenis Satuan Produk *',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                              ),
                              Text(
                                '/$selectedUnit',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kGreen),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: units.map((u) {
                              final isSel = selectedUnit == u;
                              return ChoiceChip(
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                label: Text(
                                  u,
                                  style: TextStyle(
                                    fontSize: 11.5,
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

                          const SizedBox(height: 5),

                          // 3. Berat (Opsional) & Stok
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Berat / Ukuran',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                                    ),
                                    const SizedBox(height: 2),
                                    TextField(
                                      controller: weightCtrl,
                                      onChanged: (val) {
                                        if (!unitManuallySelected) {
                                          final lower = val.toLowerCase();
                                          if (lower.contains('kg') || lower.contains('kilo')) {
                                            setDialogState(() => selectedUnit = 'kg');
                                          } else if (lower.contains('mililiter') ||
                                              RegExp(r'(?:^|\d|\s)ml\b').hasMatch(lower)) {
                                            setDialogState(() => selectedUnit = 'ml');
                                          } else if (lower.contains('liter') || RegExp(r'\d+\s*l\b').hasMatch(lower)) {
                                            setDialogState(() => selectedUnit = 'liter');
                                          } else if (lower.contains('gram') || RegExp(r'\d+\s*g\b').hasMatch(lower)) {
                                            setDialogState(() => selectedUnit = 'gram');
                                          }
                                        }
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'Misal: 5kg, 500g, 250ml',
                                        prefixIcon: const Icon(Icons.scale, color: Colors.grey, size: 16),
                                        prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 28),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isEdit ? 'Stok' : 'Stok Awal',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                                    ),
                                    const SizedBox(height: 2),
                                    TextField(
                                      key: stockFieldKey,
                                      controller: stockCtrl,
                                      focusNode: stockFocusNode,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) {
                                        setDialogState(() {
                                          stockError = null;
                                          dialogError = null;
                                        });
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'Misal: 10',
                                        errorText: stockError,
                                        prefixIcon: const Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 16),
                                        prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 28),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 5),

                          // 4. Modal / Produk, Ongkir (Opsional), & Harga Jual *
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Modal / Produk',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    TextField(
                                      controller: costPriceCtrl,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) => setDialogState(() {}),
                                      decoration: InputDecoration(
                                        hintText: '28000',
                                        prefixText: 'Rp ',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Ongkir (Opsional)',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    TextField(
                                      controller: shippingCostCtrl,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) => setDialogState(() {}),
                                      decoration: InputDecoration(
                                        hintText: 'Total ongkir',
                                        prefixText: 'Rp ',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Harga Jual *',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    TextField(
                                      key: priceFieldKey,
                                      controller: priceCtrl,
                                      focusNode: priceFocusNode,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) {
                                        setDialogState(() {
                                          priceError = null;
                                          dialogError = null;
                                        });
                                      },
                                      decoration: InputDecoration(
                                        hintText: '35000',
                                        errorText: priceError,
                                        prefixText: 'Rp ',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Ringkasan Kalkulasi HPP (Modal + Ongkir/Stok), Untung Kotor, Markup (%) & Margin (%)
                          if (previewHpp > 0 || previewSellPrice > 0) ...[
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          previewShipping > 0
                                              ? 'HPP / Produk: ${_formatRp(previewHpp)} (Modal ${_formatRp(previewBaseCost)} + Ongkir ${_formatRp(previewShippingPerUnit)})'
                                              : 'HPP / Produk: ${_formatRp(previewHpp)}',
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF166534),
                                          ),
                                        ),
                                      ),
                                      if (previewSellPrice > 0 && previewHpp > 0)
                                        Text(
                                          previewGrossProfit >= 0
                                              ? 'Untung: +${_formatRp(previewGrossProfit)}'
                                              : 'Rugi: -${_formatRp(-previewGrossProfit)}',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: previewGrossProfit >= 0 ? kGreen : Colors.redAccent,
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (previewSellPrice > 0 && previewHpp > 0) ...[
                                    Text(
                                      'Markup (vs HPP): ${previewMarkup.toStringAsFixed(1)}%  •  Margin (vs Jual): ${previewMargin.toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF374151),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],

                          if (dialogError != null) ...[
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 15),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      dialogError!,
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Action Buttons (Pinned at bottom of modal sheet so always reachable)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                            final rawStockText = stockCtrl.text.trim();
                            final rawPriceText = priceCtrl.text.trim();
                            final costPrice =
                                int.tryParse(costPriceCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                            final shippingCost =
                                int.tryParse(shippingCostCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                            final price =
                                int.tryParse(rawPriceText.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                            final stock =
                                int.tryParse(rawStockText.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

                            // Validasi berurutan kolom wajib + arahkan kursor langsung ke kolom tersebut
                            if (name.isEmpty) {
                              setDialogState(() {
                                nameError = 'Wajib diisi';
                                dialogError = 'Nama produk wajib diisi!';
                              });
                              focusRequiredField(nameFocusNode, nameFieldKey);
                              ScaffoldMessenger.of(pageContext)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  const SnackBar(
                                    content: Text('Nama produk wajib diisi!'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              return;
                            }

                            if (isCustomCategory && customCategoryCtrl.text.trim().isEmpty) {
                              setDialogState(() {
                                customCategoryError = 'Wajib diisi';
                                dialogError = 'Jenis produk kustom wajib diisi!';
                              });
                              focusRequiredField(customCategoryFocusNode, customCategoryFieldKey);
                              ScaffoldMessenger.of(pageContext)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  const SnackBar(
                                    content: Text('Jenis produk kustom wajib diisi!'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              return;
                            }

                            if (rawStockText.isEmpty || int.tryParse(rawStockText.replaceAll(RegExp(r'[^0-9]'), '')) == null) {
                              setDialogState(() {
                                stockError = 'Wajib diisi';
                                dialogError = 'Jumlah stok wajib diisi!';
                              });
                              focusRequiredField(stockFocusNode, stockFieldKey);
                              ScaffoldMessenger.of(pageContext)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  const SnackBar(
                                    content: Text('Jumlah stok wajib diisi!'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              return;
                            }

                            if (rawPriceText.isEmpty || price <= 0) {
                              setDialogState(() {
                                priceError = 'Wajib > Rp 0';
                                dialogError = 'Harga jual harus lebih dari Rp 0!';
                              });
                              focusRequiredField(priceFocusNode, priceFieldKey);
                              ScaffoldMessenger.of(pageContext)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  const SnackBar(
                                    content: Text('Harga jual harus lebih dari Rp 0!'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              return;
                            }

                            String category = selectedCategory;
                            if (isCustomCategory && customCategoryCtrl.text.trim().isNotEmpty) {
                              category = customCategoryCtrl.text.trim();
                            }

                            Navigator.pop(ctx);
                            if (mounted) {
                              setState(() {
                                _isLoading = true;
                                if (_selectedCategory != 'Semua' &&
                                    _selectedCategory.toLowerCase() != category.toLowerCase()) {
                                  _selectedCategory = 'Semua';
                                }
                              });
                            }

                            if (isEdit) {
                              await ApiService.updateProduct(
                                id: existingProduct['id'],
                                originalName: existingProduct['name']?.toString(),
                                name: name,
                                price: price,
                                costPrice: costPrice,
                                shippingCost: shippingCost,
                                stock: stock,
                                unit: selectedUnit,
                                category: category,
                                weight: weight,
                                barcode: existingProduct['barcode']?.toString(),
                                image: selectedImage ?? '',
                              );
                            } else {
                              await ApiService.addProduct(
                                name: name,
                                price: price,
                                costPrice: costPrice,
                                shippingCost: shippingCost,
                                stock: stock,
                                initialStock: stock,
                                unit: selectedUnit,
                                category: category,
                                weight: weight,
                                image: selectedImage,
                              );
                            }

                            await _loadProducts();

                            if (pageContext.mounted) {
                              ScaffoldMessenger.of(pageContext)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle, color: Colors.white),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            isEdit
                                                ? 'Produk "$name" berhasil diperbarui!'
                                                : 'Produk "$name" berhasil ditambahkan!',
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.check, size: 20),
                          label: Text(
                            isEdit ? 'Simpan Perubahan' : 'Simpan Produk',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
                        final int rawStock = (item['stock'] as num?)?.toInt() ?? 0;
                        final int inCartQty = CartService.qtyForProduct(
                          productId: item['id'],
                          name: item['name']?.toString() ?? '',
                        );
                        return _ProductCardItem(
                          product: item,
                          inCartQty: inCartQty,
                          formatRp: _formatRp,
                          onAdd: () {
                            final int remaining = (rawStock - inCartQty).clamp(0, rawStock);
                            final String unit = (item['unit'] as String?)?.trim().isNotEmpty == true
                                ? (item['unit'] as String).trim()
                                : 'pcs';
                            final int costPrice = (item['cost_price'] as num?)?.toInt() ?? 0;
                            final String? image = item['image'] as String?;
                            final String? category = (item['category'] ?? item['jenis'])?.toString();
                            final bool added = remaining > 0 &&
                                CartService.addItem(
                                  item['name'] as String,
                                  (item['price'] as num?)?.toInt() ?? 0,
                                  unit,
                                  maxStock: rawStock,
                                  productId: item['id'],
                                  costPrice: costPrice,
                                  image: image,
                                  category: category,
                                );
                            final int nextRemaining = added ? (remaining - 1) : remaining;
                            final String msg;
                            if (!added) {
                              msg = rawStock <= 0
                                  ? 'Peringatan: Stok ${item['name']} sudah habis (0 $unit)!'
                                  : 'Peringatan: Stok ${item['name']} habis! Maksimal $rawStock $unit sudah di keranjang.';
                            } else if (nextRemaining <= 0) {
                              msg = '${item['name']} ditambahkan ($unit). Sisa stok: 0 $unit (habis)!';
                            } else {
                              msg = '${item['name']} ($unit) ditambahkan! Sisa stok: $nextRemaining $unit';
                            }
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(msg),
                                backgroundColor: added ? kGreen : Colors.redAccent,
                                duration: Duration(milliseconds: added ? 1400 : 2200),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          onEdit: () => _showEditProductDialog(item),
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
  final int inCartQty;
  final String Function(int) formatRp;
  final VoidCallback onAdd;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCardItem({
    required this.product,
    this.inCartQty = 0,
    required this.formatRp,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final int rawStock = (product['stock'] as num?)?.toInt() ?? 0;
    final int stock = (rawStock - inCartQty).clamp(0, rawStock);
    final bool outOfStock = stock <= 0;
    final bool low = outOfStock || ApiService.isLowStock({...product, 'stock': stock});
    final int price = (product['price'] as num?)?.toInt() ?? (product['selling_price'] as num?)?.toInt() ?? 0;
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

    final String stockLabel;
    if (outOfStock) {
      stockLabel = inCartQty > 0
          ? 'Stok habis ($inCartQty di keranjang)'
          : 'Stok habis (0 $unit)';
    } else if (inCartQty > 0) {
      stockLabel = 'Stok: $stock $unit ($inCartQty di keranjang)';
    } else {
      stockLabel = low ? 'Stok tersisa: $stock $unit' : 'Stok: $stock $unit';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: outOfStock ? const Color(0xFFFECACA) : const Color(0xFFF0F0F0),
          width: 1.2,
        ),
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
          Expanded(
            child: GestureDetector(
              onTap: onEdit,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  // Icon or Uploaded Image Container
                  Container(
                    width: 46,
                    height: 46,
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
                  const SizedBox(width: 12),

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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
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
                            'Modal: ${formatRp(costPrice)} / produk',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF4B5563),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (price > 0) ...[
                            const SizedBox(height: 1),
                            Text(
                              () {
                                final profit = price - costPrice;
                                final markup = (profit / costPrice) * 100;
                                final margin = (profit / price) * 100;
                                final shipping = (product['shipping_cost'] as num?)?.toInt() ?? 0;
                                final prefix = profit >= 0
                                    ? 'Untung +${formatRp(profit)}'
                                    : 'Rugi -${formatRp(-profit)}';
                                final shipNote = shipping > 0 ? ' (incl. ongkir)' : '';
                                return '$prefix • Markup ${markup.toStringAsFixed(0)}% • Margin ${margin.toStringAsFixed(0)}%$shipNote';
                              }(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: (price - costPrice) >= 0
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFB91C1C),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 2),
                        Text(
                          stockLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: low ? FontWeight.w600 : FontWeight.normal,
                            color: low ? const Color(0xFFB91C1C) : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Action Button: "Tambah" ke keranjang (atau "Habis" jika stok kosong)
          OutlinedButton(
            onPressed: onAdd,
            style: OutlinedButton.styleFrom(
              foregroundColor: outOfStock ? const Color(0xFFB91C1C) : const Color(0xFF1E874B),
              backgroundColor: outOfStock ? const Color(0xFFFEF2F2) : null,
              side: BorderSide(
                color: outOfStock ? const Color(0xFFFCA5A5) : const Color(0xFF1E874B),
                width: 1.2,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              outOfStock ? 'Habis' : 'Tambah',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
          ),

          // Edit & Delete options popup
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
            padding: EdgeInsets.zero,
            onSelected: (val) {
              if (val == 'edit') {
                onEdit();
              } else if (val == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1E874B)),
                    SizedBox(width: 8),
                    Text('Edit Produk', style: TextStyle(color: Color(0xFF111827), fontSize: 13)),
                  ],
                ),
              ),
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
