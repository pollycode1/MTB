import 'package:flutter_test/flutter_test.dart';
import 'package:mtb/models.dart';

void main() {
  test('checking a step cascades down; finishing all children checks the parent', () {
    final c1 = SubTask(title: 'c1'), c2 = SubTask(title: 'c2', children: [SubTask(title: 'g')]);
    final parent = SubTask(title: 'p', children: [c1, c2]);
    final roots = [parent, SubTask(title: 'other')];

    setStepDone(roots, parent, true); // ติ๊กขั้นบน → ขั้นย่อยทั้งหมดติ๊กตาม
    expect([parent.done, c1.done, c2.done, c2.children.first.done], [true, true, true, true]);
    expect(roots[1].done, false);

    setStepDone(roots, c2.children.first, false); // ยกเลิกหลาน → แม่และยายยกเลิกตาม
    expect([c2.done, parent.done, c1.done], [false, false, true]);

    setStepDone(roots, c2.children.first, true); // ครบอีกครั้ง → ขึ้นไปติ๊กครบทุกชั้น
    expect([c2.done, parent.done], [true, true]);

    expect(countSteps(roots), 5);
    expect(countSteps(roots, onlyDone: true), 4);

    final back = SubTask.fromJson(SubTask(title: 'x', note: 'n', children: [SubTask(title: 'y')]).toJson());
    expect([back.note, back.children.single.title], ['n', 'y']);
  });
}
