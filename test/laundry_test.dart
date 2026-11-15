import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mtb/laundry.dart';
import 'package:mtb/laundry_screen.dart';
import 'package:mtb/notif_log.dart';

void main() {
  test('laundry: round 1 fill 5 → soak 20 → spin 10 → drain 3, round 2 fill 5 → spin 10 → drain 3', () {
    final fill = DateTime(2026, 11, 21, 8, 0); // เสาร์
    LaundryStatus st(int r, DateTime? f, DateTime? w, int min) => laundryStatus(r, f, w, fill.add(Duration(minutes: min)));
    LaundryPhase at(int r, DateTime? f, DateTime? w, int min) => st(r, f, w, min).phase;

    expect(at(0, null, null, 0), LaundryPhase.idle);
    expect(at(0, fill, null, 0), LaundryPhase.filling);
    expect(st(0, fill, null, 3).left(fill.add(const Duration(minutes: 3))), const Duration(minutes: 2));
    expect(at(0, fill, null, 5), LaundryPhase.waitWaterOff); // ไม่เริ่มแช่เองจนกว่าจะกดปิดน้ำ
    expect(at(0, fill, null, 60), LaundryPhase.waitWaterOff);
    expect(at(0, fill, null, 5 + 180), LaundryPhase.idle); // ค้างนานเกิน = เริ่มใหม่

    final wash = fill.add(const Duration(minutes: 7)); // กดปิดน้ำตอน 08:07
    expect(at(0, fill, wash, 7), LaundryPhase.soak);
    expect(at(0, fill, wash, 26), LaundryPhase.soak);
    expect(at(0, fill, wash, 27), LaundryPhase.spin);
    expect(at(0, fill, wash, 37), LaundryPhase.drain);
    // จบรอบ 1 → รอเริ่มรอบ 2 (น้ำยาปรับผ้านุ่ม) ไม่ใช่เสร็จ
    expect(at(0, fill, wash, 40), LaundryPhase.betweenRounds);
    expect(st(0, fill, wash, 40).round, 1);
    expect(st(0, fill, wash, 40).pos, 4); // แถว "ปล่อยน้ำเข้า + น้ำยาปรับผ้านุ่ม"
    expect(at(0, fill, wash, 40 + 180), LaundryPhase.idle);
    expect(laundryWashEnds(0, wash).map((e) => e.$2),
        [DateTime(2026, 11, 21, 8, 27), DateTime(2026, 11, 21, 8, 37), DateTime(2026, 11, 21, 8, 40)]);
    expect(laundryWashEnds(0, wash).last.$1.nextRound, isTrue);

    final fill2 = fill.add(const Duration(minutes: 45)); // 08:45 เริ่มรอบ 2
    expect(at(1, fill2, null, 45), LaundryPhase.filling);
    expect(at(1, fill2, null, 50), LaundryPhase.waitWaterOff);
    final wash2 = fill.add(const Duration(minutes: 51));
    expect(at(1, fill2, wash2, 51), LaundryPhase.spin); // ไม่มีแช่ในรอบ 2
    expect(st(1, fill2, wash2, 51).step!.label, 'ปั่นกับน้ำยาปรับผ้านุ่ม');
    expect(at(1, fill2, wash2, 61), LaundryPhase.drain);
    expect(at(1, fill2, wash2, 64), LaundryPhase.done);
    expect(st(1, fill2, wash2, 64).pos, laundryRows.length);
    expect(at(1, fill2, wash2, 64 + 60), LaundryPhase.idle);
    expect(laundryWashEnds(1, wash2).map((e) => e.$2), [DateTime(2026, 11, 21, 9, 1), DateTime(2026, 11, 21, 9, 4)]);
    expect(laundryRows.length, 7);
  });

  test('next Saturday', () {
    expect(nextSaturday(DateTime(2026, 11, 15, 12), 8), DateTime(2026, 11, 21, 8)); // อาทิตย์ → เสาร์หน้า
    expect(nextSaturday(DateTime(2026, 11, 21, 7), 8), DateTime(2026, 11, 21, 8)); // เสาร์ก่อน 8 โมง = วันนี้
    expect(nextSaturday(DateTime(2026, 11, 21, 8), 8), DateTime(2026, 11, 28, 8));
  });

  test('notification log backfills the Saturday laundry reminder', () {
    NotifLog.entries = [];
    NotifLog.seen = DateTime(2026, 11, 20, 12);
    NotifLog.backfillRepeating(DateTime(2026, 11, 21, 9), planHour: 7);
    expect(NotifLog.entries.where((e) => e.payload == 'laundry').single.at, DateTime(2026, 11, 21, 8));
  });

  testWidgets('laundry screen: start fill, confirm water off', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LaundryScreen()));
    await tester.pump();
    await tester.tap(find.text('เริ่มปล่อยน้ำเข้า (5 นาที)'));
    await tester.pump();
    expect(Laundry.status().phase, LaundryPhase.filling);
    expect(find.text('รอบ 1 · ซัก · กำลังปล่อยน้ำเข้า'), findsOneWidget);
    await tester.tap(find.text('ปิดน้ำแล้ว — เริ่มแช่ผ้า'));
    await tester.pump();
    expect(Laundry.status().phase, LaundryPhase.soak);
    expect(find.text('รอบ 1 · ซัก · กำลังแช่ผ้า'), findsOneWidget);
    expect(find.text('รอบ 2 · น้ำยาปรับผ้านุ่ม'), findsOneWidget);

    // จบรอบ 1 แล้ว → ปุ่มเริ่มรอบ 2
    Laundry.washAt = DateTime.now().subtract(const Duration(minutes: 34));
    await tester.pump(const Duration(seconds: 1)); // หน้าจอนับเวลาใหม่ทุกวินาที
    expect(Laundry.status().phase, LaundryPhase.betweenRounds);
    await tester.tap(find.text('เริ่มรอบ 2 — ปล่อยน้ำเข้า (5 นาที)'));
    await tester.pump();
    expect([Laundry.status().phase, Laundry.status().round], [LaundryPhase.filling, 1]);
    await tester.tap(find.text('ปิดน้ำแล้ว — เริ่มปั่นกับน้ำยา'));
    await tester.pump();
    expect(Laundry.status().phase, LaundryPhase.spin);
    await Laundry.reset();
    await tester.pumpWidget(const SizedBox());
  });
}
