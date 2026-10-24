import 'package:flutter_test/flutter_test.dart';
import 'package:mtb/last_year_screen.dart';
import 'package:mtb/models.dart';

void main() {
  test('finds last year tasks of a month and copies them as fresh tasks', () {
    final old = TaskItem(title: 'ส่งคะแนนกลางภาค', done: true, doneAt: DateTime(2025, 10, 20),
      tags: ['ส่งคะแนน'], area: 'ครู', deadline: DateTime(2025, 10, 31, 16),
      subTasks: [SubTask(title: 'กรอกคะแนน', done: true, children: [SubTask(title: 'ม.2', done: true)])],
      createdAt: DateTime(2025, 10, 1));
    final other = TaskItem(title: 'อื่น', createdAt: DateTime(2025, 9, 3));
    final inbox = TaskItem(title: 'รอคัด', type: 'inbox', createdAt: DateTime(2025, 10, 2));

    expect(tasksInMonth([old, other, inbox], 2025, 10), [old]);

    final now = DateTime(2026, 10, 23, 9);
    final c = copyAsNew(old, now: now);
    expect(c.id, isNot(old.id));
    expect([c.title, c.area, c.tags, c.done], ['ส่งคะแนนกลางภาค', 'ครู', ['ส่งคะแนน'], false]);
    expect(c.deadline, DateTime(2026, 10, 31, 16)); // เลื่อนไป 1 ปี
    expect(c.plannedFor, DateTime(2026, 10, 23));
    expect([c.subTasks.single.done, c.subTasks.single.children.single.done], [false, false]);
    expect(old.subTasks.single.done, true); // ของเดิมไม่ถูกแก้
  });

  test('today last year + reminders for the coming days and the 1st of the month', () {
    final a = TaskItem(title: 'ส่งแผนการสอน', done: true, doneAt: DateTime(2025, 10, 27, 15), createdAt: DateTime(2025, 10, 1));
    final b = TaskItem(title: 'ประชุมผู้ปกครอง', deadline: DateTime(2025, 10, 27, 9), createdAt: DateTime(2025, 9, 1));
    final c = TaskItem(title: 'อื่น', createdAt: DateTime(2025, 11, 5));
    expect(tasksOnDay([a, b, c], DateTime(2025, 10, 27)).map((t) => t.title), ['ประชุมผู้ปกครอง', 'ส่งแผนการสอน']);

    final now = DateTime(2026, 10, 26, 8);
    final r = lastYearReminders([a, b, c], now, days: 7);
    expect([for (final x in r) x.at], [DateTime(2026, 10, 27, 7, 5), DateTime(2026, 11, 1, 7, 10)]);
    expect(r[0].body, '2 งาน · ประชุมผู้ปกครอง, ส่งแผนการสอน');
    expect(r[1].title, 'เดือนนี้ปีที่แล้ว');
    expect(r[1].body, '1 งาน · อื่น');
  });
}
