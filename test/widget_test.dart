import 'package:flutter_test/flutter_test.dart';
import 'package:jams_absen/main.dart';

void main() {
  testWidgets('Dashboard renders correctly', (tester) async {
    await tester.pumpWidget(const JamsAbsenApp());
    await tester.pumpAndSettle();

    expect(find.text('Menu Utama'), findsOneWidget);
    expect(find.text('Statistik Bulan Ini'), findsOneWidget);
    expect(find.text('Aktivitas Terbaru'), findsOneWidget);
  });
}
