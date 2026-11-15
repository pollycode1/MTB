import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mtb/laundry.dart';
import 'package:mtb/laundry_screen.dart';
import 'package:mtb/notif_log.dart';

void main() {
  test('laundry: fill 5 → wait water off → soak 20 → spin 10 → drain 3', () {
    final fill = DateTime(2026, 11, 21, 8, 0); // เสาร์
    LaundryPhase at(DateTime? f, DateTime? w, int min) => laundryStatus(f, w, fill.add(Duration(minutes: min))).phase;

    expect(at(null, null, 0), LaundryPhase.idle);
    expect(at(fill, null, 0), LaundryPhase.filling);
    expect(laundryStatus(fill, null, fill.add(const Duration(minutes: 3))).left(fill.add(const Duration(minutes: 3))),
        const Duration(minutes: 2));
    expect(at(fill, null, 5), LaundryPhase.waitWaterOff); // ไม่เริ่มแช่เองจนกว่าจะกดปิดน้ำ
    expect(at(fill, null, 60), LaundryPhase.waitWaterOff);
    expect(at(fill, null, 5 + 180), LaundryPhase.idle); // ค้างนานเกิน = เริ่มใหม่

    final wash = fill.add(const Duration(minutes: 7)); // กดปิดน้ำตอน 08:07
    expect(at(fill, wash, 7), LaundryPhase.soak);
    expect(at(fill, wash, 26), LaundryPhase.soak);
    expect(at(fill, wash, 27), LaundryPhase.spin);
    expect(at(fill, wash, 37), LaundryPhase.drain);
    expect(at(fill, wash, 40), LaundryPhase.done);
    expect(at(fill, wash, 40 + 60), LaundryPhase.idle);

    expect(laundryWashEnds(wash).map((e) => e.$2),
        [DateTime(2026, 11, 21, 8, 27), DateTime(2026, 11, 21, 8, 37), DateTime(2026, 11, 21, 8, 40)]);
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
    expect(find.text('กำลังปล่อยน้ำเข้า'), findsOneWidget);
    await tester.tap(find.text('ปิดน้ำแล้ว — เริ่มแช่ผ้า'));
    await tester.pump();
    expect(Laundry.status().phase, LaundryPhase.soak);
    expect(find.text('กำลังแช่ผ้า'), findsOneWidget);
    await Laundry.reset();
    await tester.pumpWidget(const SizedBox());
  });
}
