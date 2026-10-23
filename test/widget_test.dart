import 'package:flutter_test/flutter_test.dart';
import 'package:mtb/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MTBApp());
    await tester.pump(const Duration(seconds: 1)); // ให้ timer ใน initState จบ
  });
}
