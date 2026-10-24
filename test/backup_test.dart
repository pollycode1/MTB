import 'package:flutter_test/flutter_test.dart';
import 'package:mtb/backup.dart';
import 'package:mtb/models.dart';
import 'package:mtb/share_task.dart';
import 'dart:convert';

void main() {
  test('backup round-trips tasks and rejects foreign or broken text', () {
    final tasks = [
      TaskItem(title: 'a', area: 'สอน', postponeCount: 2, estimateMin: 30),
      TaskItem(title: 'b', type: 'inbox'),
    ];
    final back = parseBackup(buildBackup(tasks))!;
    expect(back.map((t) => t.title), ['a', 'b']);
    expect(back[0].postponeCount, 2);
    expect(back[0].id, tasks[0].id);
    expect(back[1].type, 'inbox');

    expect(parseBackup('hello'), isNull);
    expect(parseBackup('{"tasks": []}'), isNull); // ไม่มี app: mtb
    expect(parseBackup('{"app":"mtb","tasks":[{"no_title":1}]}'), isNull); // ข้อมูลเสีย
  });

  test('shared task JSON round-trips the whole task', () {
    final t = TaskItem(title: 'ตรวจงาน', tags: ['ด่วน', 'ม.2'], meta: 'ห้อง 3/2',
      subTasks: [SubTask(title: 'a', children: [SubTask(title: 'b')])]);
    final m = jsonDecode(taskShareJson(t)) as Map<String, dynamic>;
    expect(m['app'], 'mtb');
    final back = TaskItem.fromJson(m['task'] as Map<String, dynamic>);
    expect([back.title, back.meta, back.tags, back.subTasks.single.children.single.title], ['ตรวจงาน', 'ห้อง 3/2', ['ด่วน', 'ม.2'], 'b']);
  });
}
