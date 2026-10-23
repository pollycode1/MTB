import 'package:flutter_test/flutter_test.dart';
import 'package:mtb/models.dart';

void main() {
  test('plan fields survive JSON round-trip and default for old data', () {
    final t = TaskItem(title: 'x', plannedFor: DateTime(2026, 10, 23), isFrog: true, postponeCount: 3, estimateMin: 30, actualMin: 45);
    final back = TaskItem.fromJson(t.toJson());
    expect(back.plannedFor, DateTime(2026, 10, 23));
    expect(back.isFrog, true);
    expect(back.postponeCount, 3);
    expect([back.estimateMin, back.actualMin], [30, 45]);

    final old = TaskItem.fromJson({'title': 'old'});
    expect(old.plannedFor, isNull);
    expect(old.isFrog, false);
    expect(old.postponeCount, 0);
    expect(old.estimateMin, isNull);
  });
}
