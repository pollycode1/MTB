import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mtb/laundry.dart';
import 'package:mtb/laundry_screen.dart';
import 'package:mtb/notif_log.dart';

void main() {
  test('laundry: each step stops and waits for a tap — no auto-advance to the next step', () {
    final fill = DateTime(2026, 11, 21, 8, 0); // เสาร์
    LaundryStatus st(int r, DateTime? f, DateTime? w, int step, int min) =>
        laundryStatus(r, f, w, step, fill.add(Duration(minutes: min)));
    LaundryPhase at(int r, DateTime? f, DateTime? w, int step, int min) => st(r, f, w, step, min).phase;

    // ── ปล่อยน้ำเข้า → รอกดปิดน้ำ ─────────────────────────────
    expect(at(0, null, null, 0, 0), LaundryPhase.idle);
    expect(at(0, fill, null, 0, 0), LaundryPhase.filling);
    expect(st(0, fill, null, 0, 3).left(fill.add(const Duration(minutes: 3))), const Duration(minutes: 2));
    expect(at(0, fill, null, 0, 5), LaundryPhase.waitWaterOff); // ไม่เริ่มแช่เองจนกว่าจะกดปิดน้ำ
    expect(at(0, fill, null, 0, 60), LaundryPhase.waitWaterOff);
    expect(at(0, fill, null, 0, 5 + 180), LaundryPhase.idle); // ค้างนานเกิน = เริ่มใหม่

    final wash = fill.add(const Duration(minutes: 7)); // กดปิดน้ำตอน 08:07 → เริ่มแช่ (step 0)
    expect(at(0, fill, wash, 0, 7), LaundryPhase.soak);
    expect(at(0, fill, wash, 0, 26), LaundryPhase.soak);
    // แช่ครบ 20 นาที → "หยุดรอให้กด" ไม่เดินไปปั่นเอง
    expect(at(0, fill, wash, 0, 27), LaundryPhase.waitStep);
    expect(st(0, fill, wash, 0, 27).pos, 1); // ยังชี้ที่ขั้นแช่ (ติ๊กว่าเสร็จแล้ว)
    expect(at(0, fill, wash, 0, 27 + 180), LaundryPhase.idle); // รอกดนานเกิน = เริ่มใหม่

    // กด "ไปขั้นต่อไป" → เริ่มจับเวลาปั่น (step 1) จากเวลาที่กด (ในที่นี้ reuse wash เพื่อทดสอบล้วนๆ)
    expect(at(0, fill, wash, 1, 14), LaundryPhase.spin);
    expect(at(0, fill, wash, 1, 17), LaundryPhase.waitStep); // ปั่นครบก็หยุดรอกดอีก
    expect(st(0, fill, wash, 1, 17).pos, 2);

    // กดไปขั้นต่อไป → ปล่อยน้ำออก (step 2, ขั้นสุดท้ายรอบ 1)
    expect(at(0, fill, wash, 2, 9), LaundryPhase.drain);
    expect(at(0, fill, wash, 2, 10), LaundryPhase.betweenRounds); // ขั้นสุดท้ายครบ → ต่อรอบ 2
    expect(st(0, fill, wash, 2, 10).round, 1);
    expect(st(0, fill, wash, 2, 10).pos, 4); // แถว "ปล่อยน้ำเข้า + น้ำยาปรับผ้านุ่ม"
    expect(at(0, fill, wash, 2, 10 + 180), LaundryPhase.idle);

    // ── รอบ 2 ─────────────────────────────────────────────
    final fill2 = fill.add(const Duration(minutes: 45)); // 08:45 เริ่มรอบ 2
    expect(at(1, fill2, null, 0, 45), LaundryPhase.filling);
    expect(at(1, fill2, null, 0, 50), LaundryPhase.waitWaterOff);
    final wash2 = fill.add(const Duration(minutes: 51));
    expect(at(1, fill2, wash2, 0, 51), LaundryPhase.spin); // ไม่มีแช่ในรอบ 2
    expect(st(1, fill2, wash2, 0, 51).step!.label, 'ปั่นกับน้ำยาปรับผ้านุ่ม');
    expect(at(1, fill2, wash2, 0, 61), LaundryPhase.waitStep); // ปั่นรอบ 2 ครบ → หยุดรอกด
    expect(at(1, fill2, wash2, 1, 53), LaundryPhase.drain);
    expect(at(1, fill2, wash2, 1, 54), LaundryPhase.done); // ขั้นสุดท้ายรอบสุดท้ายครบ = เสร็จ
    expect(st(1, fill2, wash2, 1, 54).pos, laundryRows.length);
    expect(at(1, fill2, wash2, 1, 54 + 60), LaundryPhase.idle);

    // เวลาจบของแต่ละขั้น (จับทีละขั้นจากเวลาที่กด) + ปุ่มของขั้นสุดท้ายรอบ 1
    expect(laundryStepEnd(0, 0, wash), DateTime(2026, 11, 21, 8, 27)); // แช่ 20
    expect(laundryStepEnd(0, 2, wash), DateTime(2026, 11, 21, 8, 10)); // ปล่อยน้ำออก 3
    expect(laundryRounds[0].wash.last.nextRound, isTrue);
    expect(laundryRows.length, 7);
  });

  test('next laundry day', () {
    const sat = DateTime.saturday;
    expect(nextLaundryDay(DateTime(2026, 11, 15, 12), sat, 8), DateTime(2026, 11, 21, 8)); // อาทิตย์ → เสาร์หน้า
    expect(nextLaundryDay(DateTime(2026, 11, 21, 7), sat, 8), DateTime(2026, 11, 21, 8)); // เสาร์ก่อน 8 โมง = วันนี้
    expect(nextLaundryDay(DateTime(2026, 11, 21, 8), sat, 8), DateTime(2026, 11, 28, 8));
    expect(nextLaundryDay(DateTime(2026, 11, 15, 12), DateTime.sunday, 18, 30), DateTime(2026, 11, 15, 18, 30));
  });

  test('custom laundry times change the timeline and notification text', () {
    LaundrySettings.fromJson({'steps': {'fill1': 7, 'soak1': 30}, 'weekday': 7, 'hour': 9, 'minute': 15, 'nag': 3});
    final fill = DateTime(2026, 11, 22, 9);
    expect(laundryStatus(0, fill, null, 0, fill.add(const Duration(minutes: 6))).phase, LaundryPhase.filling);
    expect(laundryStatus(0, fill, null, 0, fill.add(const Duration(minutes: 7))).phase, LaundryPhase.waitWaterOff);
    final wash = fill.add(const Duration(minutes: 8));
    expect(laundryStepEnd(0, 0, wash), DateTime(2026, 11, 22, 9, 38)); // แช่ปรับเป็น 30 นาที
    expect(laundryEndText(0, laundryRounds[0].fill).$2, contains('แช่ผ้า 30 นาที'));
    expect(laundryDayLabel(), 'วันอาทิตย์ 09:15');
    final back = LaundrySettings.toJson();
    LaundrySettings.fromJson({});
    expect(laundryRounds[0].fill.minutes, 5);
    LaundrySettings.fromJson(back);
    expect([LaundrySettings.minutes['soak1'], LaundrySettings.nagEvery, LaundrySettings.weekday], [30, 3, 7]);
    LaundrySettings.fromJson({});
  });

  test('intermediate steps ask to go to the next step, last step of round 1 starts round 2', () {
    LaundrySettings.fromJson({});
    // แช่ครบ → ชวนให้กด "ไปขั้นต่อไป" (ไม่เดินเอง)
    expect(laundryEndText(0, laundryRounds[0].wash[0]).$2, contains('ไปขั้นต่อไป'));
    // ปล่อยน้ำออกรอบ 1 (ขั้นสุดท้าย) → ต่อรอบ 2
    expect(laundryEndText(0, laundryRounds[0].wash.last).$1, contains('ต่อรอบ 2'));
  });

  test('notification log backfills the Saturday laundry reminder', () {
    NotifLog.entries = [];
    NotifLog.seen = DateTime(2026, 11, 20, 12);
    NotifLog.backfillRepeating(DateTime(2026, 11, 21, 9), planHour: 7);
    expect(NotifLog.entries.where((e) => e.payload == 'laundry').single.at, DateTime(2026, 11, 21, 8));
  });

  // รันก่อน testWidgets ทั้งหมด: _serial ใช้คิวสถิต (Laundry._queue) ที่ถ้าถูกตั้งค่าในโซน FakeAsync
  // ของ testWidgets ไว้ก่อน จะทำให้ await ในเทสต์ async ปกติค้าง — จึงต้องให้คิวยังเป็น Future.value() เดิมอยู่
  test('laundry: a finished step waits, then tapping "next step" advances one step only', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Laundry.resetQueueForTest();
    LaundrySettings.fromJson({});
    // ตั้งสถานะ: กดปิดน้ำแล้วแช่ผ้า (step 0) ไป 25 นาที — เกิน 20 นาที คือแช่ครบแล้ว
    final washAt = DateTime.now().subtract(const Duration(minutes: 25));
    SharedPreferences.setMockInitialValues({
      'flutter.laundry_state': jsonEncode({
        'round': 0,
        'fill': washAt.subtract(const Duration(minutes: 7)).toIso8601String(),
        'wash': washAt.toIso8601String(),
        'step': 0,
      }),
    });
    await Laundry.load();
    // แช่ 20 นาทีครบไปแล้ว → ต้องหยุดรอกด ไม่ใช่เดินไปปั่นเอง
    expect(Laundry.status().phase, LaundryPhase.waitStep);
    expect(Laundry.washStep, 0);

    // กด "ไปขั้นต่อไป" → เริ่มจับเวลาปั่น (step 1) ตั้งแต่ตอนนี้
    await Laundry.confirmNextStep();
    expect(Laundry.washStep, 1);
    expect(Laundry.status().phase, LaundryPhase.spin);

    // ปั่นยังไม่ครบ → กดไปขั้นต่อไปอีกครั้งต้องไม่ทำอะไร (ไม่ข้ามไปปล่อยน้ำออก)
    await Laundry.confirmNextStep();
    expect(Laundry.washStep, 1);
    expect(Laundry.status().phase, LaundryPhase.spin);

    await Laundry.reset();
  });

  testWidgets('laundry screen: start fill, confirm water off → start soaking', (tester) async {
    Laundry.resetQueueForTest();
    SharedPreferences.setMockInitialValues({});
    LaundrySettings.fromJson({});
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
    await Laundry.reset();
    await tester.pumpWidget(const SizedBox());
  });
}
