import 'package:flutter_test/flutter_test.dart';
import 'package:mtb/notif_log.dart';

void main() {
  test('notification log: replace/cancel future entries, backfill repeating ones', () {
    final now = DateTime(2026, 10, 26, 12); // จันทร์
    NotifLog.entries = [];
    NotifLog.seen = null;

    NotifLog.add(NotifEntry(5, DateTime(2026, 10, 26, 9), 'แจ้งไปแล้ว', ''), now: now);
    NotifLog.add(NotifEntry(5, DateTime(2026, 10, 27, 9), 'ตั้งครั้งแรก', '', taskId: 5), now: now);
    NotifLog.add(NotifEntry(5, DateTime(2026, 10, 28, 9), 'ตั้งใหม่', '', taskId: 5), now: now);
    NotifLog.add(NotifEntry(20001, DateTime(2026, 10, 27, 8), 'ก่อนคาบ', ''), now: now);
    expect(NotifLog.upcoming(now).map((e) => e.title), ['ก่อนคาบ', 'ตั้งใหม่']); // แทนอันเดิมของ id 5
    expect(NotifLog.past(now).single.title, 'แจ้งไปแล้ว'); // อันที่เด้งไปแล้วไม่ถูกลบ

    NotifLog.removeFuture((id) => id >= 20000, now: now);
    expect(NotifLog.upcoming(now).map((e) => e.title), ['ตั้งใหม่']);

    // ครั้งแรกไม่เติมย้อนหลัง · เปิดอีกทีหลัง 2 วัน → แผนเช้า 27, 28 (07:00) · ข้ามอาทิตย์ไม่มีรีวิว
    NotifLog.backfillRepeating(now, planHour: 7);
    expect(NotifLog.past(now).length, 1);
    final later = DateTime(2026, 10, 28, 8);
    NotifLog.backfillRepeating(later, planHour: 7);
    expect(NotifLog.past(later).where((e) => e.payload == 'plan').map((e) => e.at),
        [DateTime(2026, 10, 28, 7), DateTime(2026, 10, 27, 7)]);
    // ข้ามวันอาทิตย์ 09:00 → มีรีวิวรายสัปดาห์
    NotifLog.backfillRepeating(DateTime(2026, 11, 1, 10), planHour: 7);
    expect(NotifLog.entries.where((e) => e.payload == 'weekly').single.at, DateTime(2026, 11, 1, 9));

    final back = NotifEntry.fromJson(NotifEntry(1, now, 't', 'b', taskId: 9, payload: 'plan').toJson());
    expect([back.id, back.at, back.taskId, back.payload], [1, now, 9, 'plan']);
  });
}
