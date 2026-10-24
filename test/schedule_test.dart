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

  test('weekly task landing on a holiday moves to the next school day without drifting', () {
    Holidays.public = {'2026-10-23': 'วันปิยมหาราช'}; // ศุกร์
    Holidays.custom = {'2026-10-26': 'หยุดพิเศษ'};     // จันทร์ถัดไป
    final t = TaskItem(title: 'ส่งงาน', recurrence: 'weekly',
        deadline: DateTime(2026, 10, 16, 9), slotStart: DateTime(2026, 10, 16, 13));

    // 16 → 23 (ศุกร์หยุด) ข้ามเสาร์อาทิตย์ จันทร์ 26 ก็หยุด → อังคาร 27
    final n1 = nextOccurrence(t);
    expect([n1.deadline, n1.slotStart, n1.shift], [DateTime(2026, 10, 27, 9), DateTime(2026, 10, 27, 13), 4]);

    // รอบถัดไปกลับมาวันศุกร์ตามเดิม (30) ไม่ใช่อังคาร
    final t2 = TaskItem(title: 'ส่งงาน', recurrence: 'weekly', deadline: n1.deadline, slotStart: n1.slotStart, recurShift: n1.shift);
    final n2 = nextOccurrence(t2);
    expect([n2.deadline, n2.slotStart, n2.shift], [DateTime(2026, 10, 30, 9), DateTime(2026, 10, 30, 13), 0]);

    // งานรายวัน/รายเดือนไม่เลื่อน · งานเสาร์ที่ไม่ใช่วันหยุดไม่เลื่อน
    expect(nextOccurrence(TaskItem(title: 'd', recurrence: 'daily', deadline: DateTime(2026, 10, 22))).deadline, DateTime(2026, 10, 23));
    expect(nextOccurrence(TaskItem(title: 's', recurrence: 'weekly', deadline: DateTime(2026, 10, 17))).deadline, DateTime(2026, 10, 24));

    expect(TaskItem.fromJson(t2.toJson()).recurShift, 4);
    Holidays.public = {}; Holidays.custom = {};
  });

  test('schedule JSON import: template round-trips, Thai days, rejects bad rows', () {
    final fromTemplate = parseScheduleJson(scheduleTemplate);
    expect(fromTemplate.error, isNull);
    expect(fromTemplate.blocks!.first.title, isNotEmpty);

    // ข้อความจาก AI ที่มีคำอธิบายรอบ JSON ก็อ่านได้ · วันเป็นชื่อไทยหรือเลข · เวลา 8.30 หรือ 08:30
    final r = parseScheduleJson('นี่คือตารางครับ\n```json\n{"blocks":[\n'
        '{"day":"พฤหัสบดี","start":"8.30","end":"09:20","title":"คณิต ม.2/3"},\n'
        '{"day":5,"start":"13:00","end":"14:00","title":"เวรประตู","kind":"duty"}]}\n```');
    expect(r.error, isNull);
    expect([for (final b in r.blocks!) [b.weekday, b.startMin, b.endMin, b.title, b.kind]], [
      [4, 8 * 60 + 30, 9 * 60 + 20, 'คณิต ม.2/3', 'teach'],
      [5, 13 * 60, 14 * 60, 'เวรประตู', 'duty'],
    ]);
    expect(parseScheduleJson('[{"day":"จ","start":"09:00","end":"10:00","title":"a"}]').blocks!.single.weekday, 1);

    expect(parseScheduleJson('hello').error, isNotNull);
    expect(parseScheduleJson('{"blocks":[{"day":"x","start":"09:00","end":"10:00","title":"a"}]}').error, contains('1'));
    expect(parseScheduleJson('{"blocks":[{"day":1,"start":"10:00","end":"09:00","title":"a"}]}').error, isNotNull);
    expect(parseScheduleJson('{"blocks":[]}').error, isNotNull);
  });

  test('class reminders: 10 min before each block, count open tasks of that room, skip holidays', () {
    Holidays.public = {'2026-10-27': 'หยุด'}; // อังคาร
    final blocks = [
      WeeklyBlock(weekday: 1, startMin: 8 * 60 + 30, endMin: 9 * 60 + 20, title: 'คณิต ม.2/3', kind: 'teach'),
      WeeklyBlock(weekday: 2, startMin: 10 * 60, endMin: 11 * 60, title: 'คณิต ม.1/1', kind: 'teach'),
      WeeklyBlock(weekday: 1, startMin: 7 * 60, endMin: 7 * 60 + 30, title: 'เวรประตู', kind: 'duty'),
    ];
    final tasks = [
      TaskItem(title: 'ตรวจการบ้าน ม.2/3'),
      TaskItem(title: 'คืนสมุด', tags: ['ม.2/3']),
      TaskItem(title: 'เสร็จแล้ว ม.2/3', done: true),
      TaskItem(title: 'ไอเดีย ม.2/3', type: 'idea'),
      TaskItem(title: 'ม.2/30 อีกห้อง'),
    ];
    final now = DateTime(2026, 10, 26, 8, 25); // จันทร์ 08:25 → คาบ 08:30 เลยเวลาเตือนแล้ว
    final r = classReminders(blocks, tasks, now, days: 8);
    expect([for (final x in r) x.at], [
      DateTime(2026, 11, 2, 6, 50),  // เวรจันทร์ถัดไป (วันนี้ 06:50 ผ่านไปแล้ว)
      DateTime(2026, 11, 2, 8, 20),  // คาบจันทร์ถัดไป · อังคาร 27 วันหยุด ไม่มี
    ]);
    expect(r[1].title, 'อีก 10 นาทีสอน คณิต ม.2/3');
    expect(r[1].body, 'งานค้างของห้องนี้ 2 งาน · ตรวจการบ้าน ม.2/3, คืนสมุด');
    expect(r[0].title, 'อีก 10 นาที: เวรประตู');
    Holidays.public = {};
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
