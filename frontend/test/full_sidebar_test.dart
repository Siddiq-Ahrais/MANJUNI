import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:majunih/services/cart_service.dart';
import 'package:majunih/widgets/full_sidebar.dart';

void main() {
  testWidgets('FullSidebar renders full width, column items and badge',
      (WidgetTester tester) async {
    int selected = 0;

    // Add item to cart to test badge
    CartService.addItem('Beras 5kg', 65000, 'karung');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          drawer: FullSidebar(
            selectedIndex: selected,
            onItemSelected: (idx) => selected = idx,
          ),
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                child: const Text('Buka'),
              ),
            ),
          ),
        ),
      ),
    );

    // Open drawer
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();

    // Verify Drawer is full width
    final drawerFinder = find.byType(Drawer);
    expect(drawerFinder, findsOneWidget);
    final drawerSize = tester.getSize(drawerFinder);
    expect(drawerSize.width, 800.0); // Default flutter test screen width is 800

    // Verify all menu items in column
    expect(find.text('MENU UTAMA'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Produk'), findsOneWidget);
    expect(find.text('Keranjang'), findsOneWidget);
    expect(find.text('Transaksi'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);

    // Verify Keranjang badge count
    expect(find.text('1'), findsOneWidget);

    // Tap 'Transaksi'
    await tester.tap(find.text('Transaksi'));
    expect(selected, 3);
  });
}
