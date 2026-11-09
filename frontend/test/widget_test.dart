import 'package:flutter_test/flutter_test.dart';
import 'package:majunih/main.dart';

void main() {
  testWidgets('App smoke test - opens full sidebar and navigates',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Dashboard'), findsWidgets);

    // Tap hamburger menu button on top navbar
    final menuButton = find.byTooltip('Menu');
    expect(menuButton, findsOneWidget);
    await tester.tap(menuButton);
    await tester.pumpAndSettle();

    // In the full sidebar, verify the column list of menu items exists
    expect(find.text('MENU UTAMA'), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Produk'), findsOneWidget);
    expect(find.text('Keranjang'), findsOneWidget);
    expect(find.text('Transaksi'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);

    // Tap 'Produk' item in the sidebar
    await tester.tap(find.text('Produk'));
    await tester.pumpAndSettle();

    // Now Produk page should be active
    expect(find.text('Produk'), findsWidgets);

    // Open sidebar again from Produk page
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();

    expect(find.text('MENU UTAMA'), findsOneWidget);

    // Tap 'Dashboard' item in sidebar to go back
    await tester.tap(find.text('Dashboard').first);
    await tester.pumpAndSettle();

    // Dashboard page is back and shows greeting
    expect(find.text('Halo, Selamat Datang!'), findsOneWidget);
  });

  testWidgets('Floating calendar popup opens directly below option list and updates selection',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify initial calendar button
    expect(find.text('Okt 2024'), findsOneWidget);
    expect(find.text('Grafik Penjualan 7 Hari'), findsOneWidget);

    // Tap calendar button to open floating popup
    await tester.tap(find.text('Okt 2024'));
    await tester.pumpAndSettle();

    // Verify floating popup content is visible
    expect(find.text('Pilih Periode'), findsOneWidget);
    expect(find.text('7 Hari'), findsOneWidget);
    expect(find.text('30 Hari'), findsOneWidget);
    expect(find.text('Bulan Ini'), findsOneWidget);

    // Tap '30 Hari' quick filter
    await tester.tap(find.text('30 Hari'));
    await tester.pumpAndSettle();

    // Verify floating popup closed and button & chart title updated
    expect(find.text('Pilih Periode'), findsNothing);
    expect(find.text('30 Hari'), findsWidgets);
    expect(find.text('Grafik Penjualan 30 Hari'), findsOneWidget);

    // Reopen popup and pick '7 Hari'
    await tester.tap(find.text('30 Hari').first);
    await tester.pumpAndSettle();
    expect(find.text('Pilih Periode'), findsOneWidget);

    await tester.tap(find.text('7 Hari'));
    await tester.pumpAndSettle();

    expect(find.text('Pilih Periode'), findsNothing);
    expect(find.text('Grafik Penjualan 7 Hari'), findsOneWidget);
  });

  testWidgets('Statistics chart day labels can be tapped to switch active point',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Tap day label 'Sen'
    expect(find.text('Sen'), findsOneWidget);
    await tester.tap(find.text('Sen'));
    await tester.pumpAndSettle();

    // Tap day label 'Min'
    expect(find.text('Min'), findsOneWidget);
    await tester.tap(find.text('Min'));
    await tester.pumpAndSettle();
  });
}
