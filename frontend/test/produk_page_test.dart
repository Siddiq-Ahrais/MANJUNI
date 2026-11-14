import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:majunih/pages/produk_page.dart';
import 'package:majunih/services/api_service.dart';
import 'package:majunih/services/cart_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // Gunakan penyimpanan in-memory agar test tidak menyentuh platform channel asli
    SharedPreferences.setMockInitialValues({});
    ApiService.resetAllData();
    CartService.clear();
  });

  testWidgets('ProdukPage displays initial products, categories and summary stats',
      (WidgetTester tester) async {
    // Seed test products
    await ApiService.addProduct(
      name: 'Beras Ramos 5kg',
      price: 65000,
      stock: 12,
      unit: 'kemasan',
      category: 'Sembako',
    );
    await ApiService.addProduct(
      name: 'Kopi Kapal Api',
      price: 12000,
      stock: 3,
      unit: 'bungkus',
      category: 'Minuman',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProdukPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify products are rendered
    expect(find.text('Beras Ramos 5kg'), findsOneWidget);
    expect(find.text('Kopi Kapal Api'), findsOneWidget);

    // Verify filter chips exist, while product card category badge UI is removed
    expect(find.widgetWithText(FilterChip, 'Sembako'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Minuman'), findsOneWidget);
    // 'Sembako' & 'Minuman' only appear once (as FilterChips), not as badges on product cards
    expect(find.text('Sembako'), findsOneWidget);
    expect(find.text('Minuman'), findsOneWidget);

    // Verify filtering by category still works properly
    await tester.tap(find.widgetWithText(FilterChip, 'Sembako'));
    await tester.pumpAndSettle();
    expect(find.text('Beras Ramos 5kg'), findsOneWidget);
    expect(find.text('Kopi Kapal Api'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Semua'));
    await tester.pumpAndSettle();
    expect(find.text('Beras Ramos 5kg'), findsOneWidget);
    expect(find.text('Kopi Kapal Api'), findsOneWidget);

    // Verify no redundant FAB or extra buttons, only single button below product list
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Tambah Produk'), findsOneWidget);
  });

  testWidgets('Tambah Produk modal opens and successfully adds a product with category/jenis',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProdukPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap single "Tambah Produk" button below Daftar Produk
    final tambahBtn = find.widgetWithText(ElevatedButton, 'Tambah Produk');
    expect(tambahBtn, findsOneWidget);
    await tester.ensureVisible(tambahBtn);
    await tester.pumpAndSettle();
    await tester.tap(tambahBtn);
    await tester.pumpAndSettle();

    // Verify modal elements are visible
    expect(find.text('Tambah Produk Baru'), findsOneWidget);
    expect(find.text('Nama Produk *'), findsOneWidget);
    expect(find.text('Jenis Produk *'), findsOneWidget);
    expect(find.text('Harga Jual *'), findsOneWidget);
    expect(find.text('Berat / Ukuran'), findsOneWidget);
    expect(find.text('Stok Awal'), findsOneWidget);
    expect(find.text('Simpan Produk'), findsOneWidget);

    // Fill in Nama Produk
    final nameField = find.widgetWithText(TextField, 'Misal: Beras Ramos, Kopi ABC, dll');
    await tester.enterText(nameField, 'Minyak Goreng Tropical 2L');

    // Fill in Harga Jual
    final priceField = find.widgetWithText(TextField, '35000');
    await tester.enterText(priceField, '38000');

    // Select category 'Sembako'
    final sembakoChip = find.widgetWithText(ChoiceChip, 'Sembako');
    await tester.ensureVisible(sembakoChip);
    await tester.pumpAndSettle();
    await tester.tap(sembakoChip);
    await tester.pumpAndSettle();

    // Tap "Simpan Produk"
    final simpanBtn = find.text('Simpan Produk');
    await tester.ensureVisible(simpanBtn);
    await tester.pumpAndSettle();
    await tester.tap(simpanBtn);
    await tester.pumpAndSettle();

    // Verify newly added product is now visible in the list
    expect(find.text('Minyak Goreng Tropical 2L'), findsOneWidget);
    expect(find.text('Rp38.000'), findsOneWidget);
  });

  testWidgets('Adding product to cart updates CartService', (WidgetTester tester) async {
    await ApiService.addProduct(
      name: 'Teh Botol Sosro',
      price: 6000,
      stock: 10,
      unit: 'botol',
      category: 'Minuman',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProdukPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Teh Botol Sosro'), findsOneWidget);

    // Tap "Tambah" button to add to cart
    final tambahBtn = find.widgetWithText(OutlinedButton, 'Tambah').first;
    await tester.tap(tambahBtn);
    await tester.pump();

    // CartService should now have 1 item
    expect(CartService.totalCount, 1);
    expect(CartService.cartNotifier.value.first.name, 'Teh Botol Sosro');
  });

  test('Produk tersimpan ke penyimpanan perangkat saat ditambahkan', () async {
    SharedPreferences.setMockInitialValues({});
    ApiService.resetAllData();

    await ApiService.addProduct(
      name: 'Minyak Goreng Tropical 2L',
      price: 38000,
      stock: 10,
      unit: 'pcs',
      category: 'Sembako',
    );

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(ApiService.productsStorageKey);
    expect(stored, isNotNull);
    expect(stored!.contains('Minyak Goreng Tropical 2L'), isTrue);
  });

  test('Produk tetap ada setelah aplikasi ditutup & dibuka kembali', () async {
    // Sesi 1: user menambah produk lalu menutup aplikasi
    SharedPreferences.setMockInitialValues({});
    ApiService.resetAllData();
    await ApiService.addProduct(
      name: 'Minyak Goreng Tropical 2L',
      price: 38000,
      stock: 10,
      unit: 'pcs',
      category: 'Sembako',
    );
    final savedJson = (await SharedPreferences.getInstance())
        .getString(ApiService.productsStorageKey)!;

    // Sesi 2: aplikasi dibuka ulang -> memori kosong, data perangkat dimuat kembali
    SharedPreferences.setMockInitialValues({
      ApiService.productsStorageKey: savedJson,
    });
    await ApiService.loadLocalData(force: true);

    final list = await ApiService.getProducts();
    expect(
      list.where((p) => p['name'] == 'Minyak Goreng Tropical 2L'),
      isNotEmpty,
    );
  });

  test('Produk tetap ada setelah user keluar (logout)', () async {
    SharedPreferences.setMockInitialValues({});
    ApiService.resetAllData();
    await ApiService.addProduct(
      name: 'Kopi Kapal Api',
      price: 3000,
      stock: 10,
      unit: 'pcs',
      category: 'Minuman',
    );

    // Keluar hanya mengakhiri sesi login, tidak menghapus produk terdaftar
    await ApiService.logout();

    final list = await ApiService.getProducts();
    expect(list.where((p) => p['name'] == 'Kopi Kapal Api'), isNotEmpty);
  });

  test('P1: Stok menipis menggunakan persentase (< 50% dari stok awal)', () async {
    SharedPreferences.setMockInitialValues({});
    ApiService.resetAllData();

    await ApiService.addProduct(
      name: 'Beras Pandan Wangi',
      price: 15000,
      costPrice: 12000,
      stock: 100,
      unit: 'kg',
      category: 'Sembako',
    );

    // Saat stok awal 100, produk belum menipis
    var products = await ApiService.getProducts();
    expect(ApiService.isLowStock(products.first), isFalse);

    // Transaksi 50 kg -> sisa stok 50 (50% dari 100) -> belum di bawah 50%
    await ApiService.createTransaction(
      cartItems: [
        {'name': 'Beras Pandan Wangi', 'qty': 50, 'price': 15000, 'unit': 'kg'},
      ],
      itemsSummary: 'Beras Pandan Wangi (50 kg)',
      paymentMethod: 'Tunai',
      totalAmount: 750000,
    );
    products = await ApiService.getProducts();
    expect(products.first['stock'], 50);
    expect(ApiService.isLowStock(products.first), isFalse);

    // Transaksi 1 kg lagi -> sisa stok 49 (< 50% dari 100) -> terdeteksi stok menipis!
    await ApiService.createTransaction(
      cartItems: [
        {'name': 'Beras Pandan Wangi', 'qty': 1, 'price': 15000, 'unit': 'kg'},
      ],
      itemsSummary: 'Beras Pandan Wangi (1 kg)',
      paymentMethod: 'Tunai',
      totalAmount: 15000,
    );
    products = await ApiService.getProducts();
    expect(products.first['stock'], 49);
    expect(ApiService.isLowStock(products.first), isTrue);
  });

  testWidgets(
      'P1: Tambah produk mendukung upload gambar, satuan (kg/liter/gram), dan harga modal, serta link satuan ke keranjang',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProdukPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tambahBtn = find.widgetWithText(ElevatedButton, 'Tambah Produk');
    await tester.ensureVisible(tambahBtn);
    await tester.pumpAndSettle();
    await tester.tap(tambahBtn);
    await tester.pumpAndSettle();

    // Verifikasi opsi satuan kg, liter, gram tersedia
    expect(find.widgetWithText(ChoiceChip, 'kg'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'liter'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'gram'), findsOneWidget);

    // Upload gambar hanya lewat Pilih File dari Perangkat
    const channel = MethodChannel('com.example.majunih/file_export');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'pickImage') {
        return {
          'base64':
              'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
          'name': 'beras_foto.png',
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await tester.ensureVisible(find.text('Upload Gambar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload Gambar'));
    await tester.pumpAndSettle();
    expect(find.text('Beras / Sembako'), findsNothing);
    expect(find.text('Minyak / Cairan'), findsNothing);
    expect(find.text('Minuman / Kopi'), findsNothing);
    expect(find.text('Makanan / Snack'), findsNothing);
    expect(find.text('Atau Path File / URL Gambar:'), findsNothing);
    await tester.tap(find.text('Pilih File dari Perangkat'));
    await tester.pumpAndSettle();
    expect(find.text('Gambar Terpilih: beras_foto.png'), findsOneWidget);

    // Isi nama produk
    await tester.enterText(
      find.widgetWithText(TextField, 'Misal: Beras Ramos, Kopi ABC, dll'),
      'Beras Rojolele',
    );

    // Pilih satuan 'kg'
    final kgChip = find.widgetWithText(ChoiceChip, 'kg');
    await tester.ensureVisible(kgChip);
    await tester.pumpAndSettle();
    await tester.tap(kgChip);
    await tester.pumpAndSettle();

    // Isi Harga Modal & Harga Jual
    final modalField = find.widgetWithText(TextField, '28000');
    await tester.ensureVisible(modalField);
    await tester.enterText(modalField, '11000');

    final priceField = find.widgetWithText(TextField, '35000');
    await tester.ensureVisible(priceField);
    await tester.enterText(priceField, '14000');

    final simpanBtn = find.text('Simpan Produk');
    await tester.ensureVisible(simpanBtn);
    await tester.pumpAndSettle();
    await tester.tap(simpanBtn);
    await tester.pumpAndSettle();

    // Produk tampil dengan satuan kg & modal
    expect(find.text('Beras Rojolele'), findsOneWidget);
    expect(find.text('Modal: Rp11.000 / kg'), findsOneWidget);

    // Tambah ke keranjang (set stok > 0 dulu atau cek produk ber-stok)
    await ApiService.addProduct(
      name: 'Gula Pasir',
      price: 16000,
      costPrice: 13500,
      stock: 20,
      unit: 'kg',
      category: 'Sembako',
    );
    await tester.pumpAndSettle();

    final addCartBtn = find.widgetWithText(OutlinedButton, 'Tambah').first;
    await tester.tap(addCartBtn);
    await tester.pump();

    expect(CartService.cartNotifier.value.first.unit, 'kg');
    expect(CartService.cartNotifier.value.first.costPrice, 13500);
  });

  testWidgets('Produk yang sudah ada dapat diedit detail dan fotonya', (
    tester,
  ) async {
    await ApiService.addProduct(
      name: 'Teh Botol',
      price: 5000,
      costPrice: 3500,
      stock: 15,
      unit: 'pcs',
      category: 'Minuman',
    );

    await tester.pumpWidget(const MaterialApp(home: ProdukPage()));
    await tester.pumpAndSettle();

    expect(find.text('Teh Botol'), findsOneWidget);

    // Buka menu card dan pilih Edit Produk
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Produk'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Produk'), findsOneWidget);
    expect(find.text('Simpan Perubahan'), findsOneWidget);

    // Ubah nama, stok, harga modal, harga jual
    await tester.enterText(
      find.widgetWithText(TextField, 'Teh Botol'),
      'Teh Botol Sosro 450ml',
    );
    await tester.enterText(find.widgetWithText(TextField, '15'), '25');
    await tester.enterText(find.widgetWithText(TextField, '3500'), '4000');
    await tester.enterText(find.widgetWithText(TextField, '5000'), '6500');

    // Pilih/ubah foto produk lewat Pilih File dari Perangkat
    const channel = MethodChannel('com.example.majunih/file_export');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'pickImage') {
        return {
          'base64':
              'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
          'name': 'teh_botol_baru.jpg',
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await tester.ensureVisible(find.text('Upload Gambar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload Gambar'));
    await tester.pumpAndSettle();
    expect(find.text('Upload Gambar Produk'), findsOneWidget);
    expect(find.text('Beras / Sembako'), findsNothing);
    expect(find.text('Minyak / Cairan'), findsNothing);
    await tester.tap(find.text('Pilih File dari Perangkat'));
    await tester.pumpAndSettle();
    expect(find.text('Gambar Terpilih: teh_botol_baru.jpg'), findsOneWidget);

    // Simpan perubahan
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    expect(find.text('Teh Botol Sosro 450ml'), findsOneWidget);
    expect(find.text('Teh Botol'), findsNothing);

    final products = await ApiService.getProducts();
    final updated = products.firstWhere(
      (p) => p['name'] == 'Teh Botol Sosro 450ml',
    );
    expect(updated['price'], 6500);
    expect(updated['cost_price'], 4000);
    expect(updated['stock'], 25);
    expect((updated['image'] ?? '').toString().isNotEmpty, true);
  });

  testWidgets('Stok produk berkurang responsif saat masuk keranjang dan memberi peringatan saat habis',
      (WidgetTester tester) async {
    await ApiService.addProduct(
      name: 'Kopi Susu',
      price: 10000,
      stock: 2,
      unit: 'cup',
      category: 'Minuman',
    );

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ProdukPage())));
    await tester.pumpAndSettle();

    expect(find.text('Stok: 2 cup'), findsOneWidget);

    // Tambah 1 -> sisa tampil menjadi 1 (berkurang 1 sesuai keranjang)
    await tester.tap(find.widgetWithText(OutlinedButton, 'Tambah').first);
    await tester.pumpAndSettle();
    expect(CartService.totalCount, 1);
    expect(find.text('Stok: 1 cup (1 di keranjang)'), findsOneWidget);

    // Tambah ke-2 -> sisa tampil menjadi 0 / habis & tombol berubah menjadi 'Habis'
    await tester.tap(find.widgetWithText(OutlinedButton, 'Tambah').first);
    await tester.pumpAndSettle();
    expect(CartService.totalCount, 2);
    expect(find.text('Stok habis (2 di keranjang)'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Habis'), findsOneWidget);

    // Tap 'Habis' -> tidak bertambah, peringatan stok habis muncul
    await tester.tap(find.widgetWithText(OutlinedButton, 'Habis'));
    await tester.pumpAndSettle();
    expect(CartService.totalCount, 2);
    expect(find.textContaining('Peringatan: Stok Kopi Susu habis'), findsOneWidget);

    // Kurangi dari keranjang -> tampilan stok produk otomatis responsif bertambah kembali
    CartService.updateQty(0, -1);
    await tester.pumpAndSettle();
    expect(find.text('Stok: 1 cup (1 di keranjang)'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Tambah'), findsOneWidget);
  });

  test('Rumus HPP per unit menghitung modal + ongkir dibagi jumlah barang serta Markup vs Margin', () async {
    SharedPreferences.setMockInitialValues({});
    ApiService.resetAllData();

    // Contoh: Beli 100 pcs minuman kemasan modal Rp3.000/pcs (total Rp300.000) dengan ongkir Rp20.000 -> HPP = Rp3.200/pcs
    await ApiService.addProduct(
      name: 'Minuman Kemasan',
      price: 4000,
      costPrice: 3000,
      shippingCost: 20000,
      stock: 100,
      unit: 'pcs',
      category: 'Minuman',
    );

    final products = await ApiService.getProducts();
    final item = products.firstWhere((p) => p['name'] == 'Minuman Kemasan');
    expect(item['base_cost_price'], 3000);
    expect(item['shipping_cost'], 20000);
    expect(item['cost_price'], 3200); // HPP per unit = 3000 + (20000 / 100) = 3200

    // Contoh kedua: Modal Rp8.000, Jual Rp10.000 (tanpa ongkir) -> Markup 25%, Margin 20%
    ApiService.resetAllData();
    await ApiService.addProduct(
      name: 'Teh Kemasan',
      price: 10000,
      costPrice: 8000,
      stock: 10,
      unit: 'pcs',
      category: 'Minuman',
    );
    await ApiService.createTransaction(
      cartItems: [
        {'name': 'Teh Kemasan', 'qty': 1, 'price': 10000, 'cost_price': 8000, 'unit': 'pcs'},
      ],
      itemsSummary: 'Teh Kemasan (1 pcs)',
      paymentMethod: 'Tunai',
      totalAmount: 10000,
    );

    final report = await ApiService.getProfitLossReport();
    final summary = report['summary'] as Map<String, dynamic>;
    expect(summary['revenue'], 10000);
    expect(summary['cogs'], 8000);
    expect(summary['gross_profit'], 2000);
    expect(summary['markup_percentage'], 25.0);
    expect(summary['gross_margin_percentage'], 20.0);
  });

  testWidgets('Validasi kolom wajib mengarahkan kursor/fokus otomatis ke kolom yang belum diisi',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProdukPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tambahBtn = find.widgetWithText(ElevatedButton, 'Tambah Produk');
    await tester.ensureVisible(tambahBtn);
    await tester.pumpAndSettle();
    await tester.tap(tambahBtn);
    await tester.pumpAndSettle();

    // Tekan Simpan tanpa mengisi Nama Produk -> muncul peringatan & kursor mengarah ke Nama Produk
    final simpanBtn = find.text('Simpan Produk');
    await tester.ensureVisible(simpanBtn);
    await tester.pumpAndSettle();
    await tester.tap(simpanBtn);
    await tester.pumpAndSettle();

    expect(find.text('Nama produk wajib diisi!'), findsWidgets);
    final nameTextField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Misal: Beras Ramos, Kopi ABC, dll'),
    );
    expect(nameTextField.focusNode?.hasFocus, isTrue);

    // Isi Nama Produk, tapi kosongkan Harga Jual -> tekan Simpan -> kursor mengarah ke Harga Jual
    await tester.enterText(
      find.widgetWithText(TextField, 'Misal: Beras Ramos, Kopi ABC, dll'),
      'Sabun Mandi',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(simpanBtn);
    await tester.pumpAndSettle();
    await tester.tap(simpanBtn);
    await tester.pumpAndSettle();

    expect(find.text('Harga jual harus lebih dari Rp 0!'), findsWidgets);
    final priceTextField = tester.widget<TextField>(
      find.widgetWithText(TextField, '35000'),
    );
    expect(priceTextField.focusNode?.hasFocus, isTrue);
  });
}
