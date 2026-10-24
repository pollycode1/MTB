import 'package:flutter_test/flutter_test.dart';
import 'package:mtb/models.dart';
import 'package:mtb/schedule_data.dart';

void main() {
  test('occurrences include recurring tasks; free slots skip teaching blocks and tasks', () {
    final mon = DateTime(2026, 10, 26); // จันทร์
    final a = TaskItem(title: 'a', slotStart: DateTime(2026, 10, 26, 13), slotMin: 60);
    final weekly = TaskItem(title: 'w', slotStart: DateTime(2026, 10, 19, 15), slotMin: 30, recurrence: 'weekly');
    final doneWeekly = TaskItem(title: 'old', slotStart: DateTime(2026, 10, 12, 15), recurrence: 'weekly', done: true);
    final idea = TaskItem(title: 'i', type: 'idea', slotStart: DateTime(2026, 10, 26, 8));

    final occ = occurrencesOn([a, weekly, doneWeekly, idea], mon);
    expect(occ.map((o) => o.$1.title), ['a', 'w']); // งานทำซ้ำโผล่ทุกสัปดาห์ · ที่เสร็จแล้วไม่ซ้ำต่อ
    expect(occ.last.$2, DateTime(2026, 10, 26, 15));

    final blocks = [WeeklyBlock(weekday: 1, startMin: 8 * 60, endMin: 12 * 60, title: 'สอน', kind: 'teach')];
    final busy = busyOn(mon, [a, weekly], blocks);
    final starts = freeStarts(busy, 60);
    expect(starts.contains(6 * 60), true);
    expect(starts.contains(8 * 60), false);           // คาบสอน
    expect(starts.contains(12 * 60), true);
    expect(starts.contains(12 * 60 + 30), false);     // ชนงาน 13:00
    expect(starts.contains(15 * 60), false);          // งานทำซ้ำ 15:00
    expect(freeLength(14 * 60, busy), 60);            // 14:00–15:00
    expect(freeLength(9 * 60, busy), 0);

    // วันหยุด: ไม่มีคาบสอน ทั้งวันว่าง (ยกเว้นงานที่ลงไว้)
    expect(freeStarts(busyOn(mon, [], blocks, holiday: true), 60).length, 20);

    final back = TaskItem.fromJson(a.toJson());
    expect([back.slotStart, back.slotMin], [DateTime(2026, 10, 26, 13), 60]);
    expect(hm(16 * 60 + 30), '16:30');
  });

  test('Thai holiday ics: keeps public holidays only, expands ranges', () {
    const ics = 'BEGIN:VCALENDAR\r\n'
        'BEGIN:VEVENT\r\nDTSTART;VALUE=DATE:20261023\r\nDTEND;VALUE=DATE:20261024\r\n'
        'DESCRIPTION:วันหยุดนักขัตฤกษ์\r\nSUMMARY:วันปิยมหาราช\r\nEND:VEVENT\r\n'
        'BEGIN:VEVENT\r\nDTSTART;VALUE=DATE:20260214\r\nDTEND;VALUE=DATE:20260215\r\n'
        'DESCRIPTION:วันสำคัญ\\nหากต้องการซ่อน\r\nSUMMARY:วันวาเลนไทน์\r\nEND:VEVENT\r\n'
        'BEGIN:VEVENT\r\nDTSTART;VALUE=DATE:20260413\r\nDTEND;VALUE=DATE:20260416\r\n'
        'DESCRIPTION:วันหยุดนักขัตฤกษ์\r\nSUMMARY:​วันสงก\r\n รานต์\r\nEND:VEVENT\r\n'
        'END:VCALENDAR';
    final h = parseThaiHolidayIcs(ics);
    expect(h['2026-10-23'], 'วันปิยมหาราช');
    expect(h.containsKey('2026-02-14'), false);
    expect([h['2026-04-13'], h['2026-04-15'], h.containsKey('2026-04-16')], ['วันสงกรานต์', 'วันสงกรานต์', false]);
  });
}
