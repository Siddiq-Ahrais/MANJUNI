import 'package:flutter_test/flutter_test.dart';
import 'package:majunih/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Produk'), findsWidgets);
    expect(find.text('Keranjang'), findsWidgets);
    expect(find.text('Transaksi'), findsWidgets);
    expect(find.text('Profil'), findsWidgets);
  });
}
