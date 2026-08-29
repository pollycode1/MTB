import 'package:flutter_test/flutter_test.dart';
import 'package:mtb/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MTBApp());
  });
}
