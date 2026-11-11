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

    // Verify customer card defaults to Pelanggan Umum
    expect(find.text('Pelanggan'), findsOneWidget);
    expect(find.text('Pelanggan Umum'), findsOneWidget);

    // Verify payment methods are present
    expect(find.text('Tunai'), findsOneWidget);
    expect(find.text('QRIS'), findsOneWidget);
    expect(find.text('Kasbon'), findsOneWidget);

    // Verify payment summary shows 0 items and Rp0
    expect(find.text('Subtotal (0 item)'), findsOneWidget);
    expect(find.text('Diskon'), findsOneWidget);
    expect(find.text('Total Bayar'), findsOneWidget);
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
    expect(find.text('Bayar  Rp65.000'), findsOneWidget);

    // Increment item quantity
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('Subtotal (2 item)'), findsOneWidget);
    expect(find.text('Bayar  Rp130.000'), findsOneWidget);

    // Tap "Kosongkan" button in header
    expect(find.text('Kosongkan'), findsOneWidget);
    await tester.tap(find.text('Kosongkan'));
    await tester.pumpAndSettle();

    // Should return to empty state with Rp0
    expect(find.text('Keranjang Masih Kosong'), findsOneWidget);
    expect(find.text('Subtotal (0 item)'), findsOneWidget);
    expect(find.text('Keranjang Kosong (Rp0)'), findsOneWidget);
  });
}

