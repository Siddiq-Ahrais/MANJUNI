import 'package:flutter/material.dart';
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

    // Verify category badges
    expect(find.text('Sembako'), findsWidgets);
    expect(find.text('Minuman'), findsWidgets);

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
    await tester.tap(find.widgetWithText(ChoiceChip, 'Sembako'));
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

    // Upload gambar dari galeri cepat
    await tester.tap(find.text('Upload Gambar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beras / Sembako'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Gambar Terpilih:'), findsOneWidget);

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
}
