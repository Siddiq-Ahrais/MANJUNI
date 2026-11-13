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
}
