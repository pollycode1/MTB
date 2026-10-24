import 'package:flutter_test/flutter_test.dart';
import 'package:mtb/models.dart';
import 'package:mtb/search_screen.dart';

void main() {
  test('search finds title, tag, area, note and nested steps; open tasks rank first', () {
    final done = TaskItem(title: 'ตรวจข้อสอบ ม.2', done: true);
    final t = TaskItem(title: 'เตรียมสอน', area: 'สอน', tag: 'ด่วน', meta: 'ใช้ห้องคอม',
      subTasks: [SubTask(title: 'ทำสไลด์', children: [SubTask(title: 'ใส่โจทย์ข้อสอบ', note: 'บทที่ 3')])]);
    final idea = TaskItem(title: 'เกมไพ่', type: 'idea');

    final hits = searchTasks([done, t, idea], 'ข้อสอบ');
    expect(hits.map((h) => h.task.title), ['เตรียมสอน', 'ตรวจข้อสอบ ม.2']); // งานค้างก่อนงานเสร็จ
    expect(hits.first.where, ['ขั้นตอน: ทำสไลด์ › ใส่โจทย์ข้อสอบ']);

    expect(searchTasks([t], 'ด่วน').single.where, ['แท็ก: ด่วน']);
    expect(searchTasks([t], 'บทที่').single.where.single, startsWith('หมายเหตุขั้นตอน'));
    expect(searchTasks([t], 'ห้องคอม').single.where, ['หมายเหตุ: ใช้ห้องคอม']);
    expect(searchTasks([t, idea], '   '), isEmpty);
    expect(statusLabel(idea), 'ไอเดีย');
  });
}
