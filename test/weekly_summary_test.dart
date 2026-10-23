import 'package:flutter_test/flutter_test.dart';
import 'package:mtb/models.dart';
import 'package:mtb/weekly_summary_screen.dart';

void main() {
  test('week summary counts this/last week, overdue, postponed', () {
    final now = DateTime(2026, 10, 23, 12); // ศุกร์ → สัปดาห์เริ่มจันทร์ 19 ต.ค.
    final tasks = [
      TaskItem(title: 'a', done: true, doneAt: DateTime(2026, 10, 20), area: 'สอน'),
      TaskItem(title: 'b', done: true, doneAt: DateTime(2026, 10, 19, 8), estimateMin: 30, actualMin: 45),
      TaskItem(title: 'c', done: true, doneAt: DateTime(2026, 10, 18)), // สัปดาห์ก่อน
      TaskItem(title: 'd', deadline: DateTime(2026, 10, 22), postponeCount: 4),
      TaskItem(title: 'e', postponeCount: 1),
      TaskItem(title: 'f', type: 'inbox'),
    ];
    final s = computeWeekSummary(tasks, now);
    expect(s.doneThis, 2);
    expect(s.doneLast, 1);
    expect(s.doneByArea, {'สอน': 1, 'อื่นๆ': 1});
    expect(s.pending, 2);
    expect(s.overdue, 1);
    expect(s.inbox, 1);
    expect([s.timedCount, s.estMin, s.actMin], [1, 30, 45]);
    expect(s.mostPostponed.map((t) => t.title), ['d', 'e']);
  });
}
