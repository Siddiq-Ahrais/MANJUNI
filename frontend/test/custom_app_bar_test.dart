import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:majunih/widgets/custom_app_bar.dart';

void main() {
  testWidgets('CustomAppBar renders minimalist transparent bar and title',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          appBar: CustomAppBar(
            title: 'Katalog Produk',
            subtitle: 'Toko Maju \u2022 Mode Offline',
          ),
          body: Center(child: Text('Konten')),
        ),
      ),
    );

    // Title & subtitle should be visible
    expect(find.text('Katalog Produk'), findsOneWidget);
    expect(find.text('Toko Maju \u2022 Mode Offline'), findsOneWidget);

    // Search button should be visible
    expect(find.byKey(const ValueKey('open_search_btn')), findsOneWidget);
    // Notification button should be present
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
  });

  testWidgets(
      'CustomAppBar automatically hides title when search is triggered and restores it on close',
      (WidgetTester tester) async {
    String query = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: CustomAppBar(
            title: 'Katalog Produk',
            subtitle: 'Toko Maju \u2022 Mode Offline',
            onSearchChanged: (val) => query = val,
          ),
          body: const Center(child: Text('Konten')),
        ),
      ),
    );

    // Initially title is visible
    expect(find.text('Katalog Produk'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    // Tap search button
    await tester.tap(find.byKey(const ValueKey('open_search_btn')));
    await tester.pumpAndSettle();

    // Title should now be HIDDEN
    expect(find.text('Katalog Produk'), findsNothing);
    // Search input should be VISIBLE
    expect(find.byType(TextField), findsOneWidget);

    // Enter search text
    await tester.enterText(find.byType(TextField), 'Kopi Kapal Api');
    expect(query, 'Kopi Kapal Api');

    // Close search button should be visible
    expect(find.byKey(const ValueKey('close_search_btn')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('close_search_btn')));
    await tester.pumpAndSettle();

    // Title should be restored automatically
    expect(find.text('Katalog Produk'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(query, '');
  });

  testWidgets('Notification button shows hoverable tooltip and modal sheet on tap',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          appBar: CustomAppBar(
            title: 'Dashboard',
          ),
          body: Center(child: Text('Body')),
        ),
      ),
    );

    // Find notification icon (unhovered state)
    final unhoveredIcon = find.byIcon(Icons.notifications_none_rounded);
    expect(unhoveredIcon, findsOneWidget);

    // Simulate mouse hover using a pointer gesture
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(unhoveredIcon));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // When hovered, the icon animates to filled notifications_rounded!
    final hoveredIcon = find.byIcon(Icons.notifications_rounded);
    expect(hoveredIcon, findsOneWidget);

    // Tap notification button while hovered
    await tester.tap(hoveredIcon);
    await tester.pumpAndSettle();

    // Notification bottom sheet should be displayed
    expect(find.text('Notifikasi'), findsWidgets);
    expect(find.text('Sistem Kasir Berjalan Normal'), findsOneWidget);
    expect(find.text('Tutup'), findsOneWidget);

    // Tap tutup
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();

    expect(find.text('Sistem Kasir Berjalan Normal'), findsNothing);
  });

  testWidgets('CustomAppBar respects showTitle: false and showSearch: false',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          appBar: CustomAppBar(
            title: 'Products',
            showTitle: false,
            showSearch: false,
          ),
          body: Center(child: Text('Konten')),
        ),
      ),
    );

    // Title should NOT be visible
    expect(find.text('Products'), findsNothing);

    // Search button should NOT be present
    expect(find.byKey(const ValueKey('open_search_btn')), findsNothing);

    // Notification button should still be present
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    // Menu button should still be present
    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
  });
}
