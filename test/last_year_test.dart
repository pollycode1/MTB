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
}
