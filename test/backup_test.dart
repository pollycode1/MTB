import 'package:flutter_test/flutter_test.dart';
import 'package:mtb/backup.dart';
import 'package:mtb/models.dart';

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
}
