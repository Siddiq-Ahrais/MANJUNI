import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:majunih/pages/keranjang_page.dart';
import 'package:majunih/services/cart_service.dart';

void main() {
  setUp(() {
    CartService.clear();
  });

  testWidgets('KeranjangPage for new user displays empty cart with Rp0 amounts',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: KeranjangPage(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify header
    expect(find.text('Keranjang'), findsOneWidget);
    expect(find.text('Warung Maju Jaya'), findsOneWidget);

    // Verify empty state card
    expect(find.text('Keranjang Masih Kosong'), findsOneWidget);
    expect(find.text('Lihat Katalog Produk'), findsOneWidget);

    // Verify customer card has been removed
    expect(find.text('Pelanggan'), findsNothing);
    expect(find.text('Pelanggan Umum'), findsNothing);
    expect(find.text('Ganti'), findsNothing);

    // Verify payment methods are present
    expect(find.text('Tunai'), findsOneWidget);
    expect(find.text('QRIS'), findsOneWidget);
    expect(find.text('Kasbon'), findsOneWidget);

    // Verify payment summary shows 0 items and Rp0
    expect(find.text('Subtotal (0 item)'), findsOneWidget);
    expect(find.text('Diskon'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Rp0'), findsWidgets);

    // Verify pay button is disabled with empty cart text
    expect(find.text('Keranjang Kosong (Rp0)'), findsOneWidget);
  });

  testWidgets('Adding items dynamically updates cart items, prices and enables checkout button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: KeranjangPage(),
      ),
    );
    await tester.pumpAndSettle();

    // Add 1 item to cart
    CartService.addItem('Beras Ramos 5kg', 65000, 'kemasan');
    await tester.pumpAndSettle();

    // Item should appear in list
    expect(find.text('Beras Ramos 5kg'), findsOneWidget);
    expect(find.text('Rp65.000 / kemasan'), findsOneWidget);

    // Summary should update
    expect(find.text('Subtotal (1 item)'), findsOneWidget);
    expect(find.text('Rp65.000'), findsWidgets);

    // Button should now be active with total
    expect(find.text('Simpan'), findsOneWidget);

    // Increment item quantity
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('Subtotal (2 item)'), findsOneWidget);
    expect(find.text('Rp130.000'), findsWidgets);
    expect(find.text('Simpan'), findsOneWidget);

    // Tap "Kosongkan" button in header
    expect(find.text('Kosongkan'), findsOneWidget);
    await tester.tap(find.text('Kosongkan'));
    await tester.pumpAndSettle();

    // Should return to empty state with Rp0
    expect(find.text('Keranjang Masih Kosong'), findsOneWidget);
    expect(find.text('Subtotal (0 item)'), findsOneWidget);
    expect(find.text('Keranjang Kosong (Rp0)'), findsOneWidget);
  });

  testWidgets('P0 Stock validation prevents buying more than available stock',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: KeranjangPage(),
      ),
    );
    await tester.pumpAndSettle();

    // Add item with maxStock = 2
    final added1 = CartService.addItem('Minyak Goreng 1L', 18000, 'pcs', maxStock: 2);
    expect(added1, isTrue);
    await tester.pumpAndSettle();

    // Increment to 2 (allowed, reaches maxStock = 2)
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(CartService.totalCount, 2);

    // Attempt to increment past maxStock = 2 -> blocked!
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(CartService.totalCount, 2);
    expect(find.textContaining('mencapai batas stok'), findsOneWidget);

    // Attempt to add when stock is 0 -> blocked!
    final addedZero = CartService.addItem('Gula Habis', 15000, 'pcs', maxStock: 0);
    expect(addedZero, isFalse);
  });

  testWidgets('Checkout diblokir dengan peringatan jika qty di keranjang melebihi stok terbaru',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: KeranjangPage(),
      ),
    );
    await tester.pumpAndSettle();

    // Simulasikan item masuk ke keranjang melebihi batas (misal stok diperbarui turun ke 2)
    CartService.cartNotifier.value = [
      CartItem(
        name: 'Minyak Goreng 1L',
        price: 18000,
        unit: 'pcs',
        maxStock: 2,
        qty: 5,
      ),
    ];
    await tester.pumpAndSettle();

    expect(find.text('Melebihi stok! Tersisa 2 pcs'), findsOneWidget);

    // Tekan Simpan -> harus ditolak dengan peringatan dan dialog sukses tidak muncul
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Transaksi Tersimpan!'), findsNothing);
    expect(find.textContaining('Stok Minyak Goreng 1L tidak mencukupi'), findsOneWidget);
  });
}

