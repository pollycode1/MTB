import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

// ── ซักผ้า (ทุกวันเสาร์ หรือกดเองวันไหนก็ได้) ─────────────────────────────────────
// รอบ 1 ซัก: ปล่อยน้ำเข้า 5 → (กด "ปิดน้ำแล้ว") → แช่ผ้า 20 → ปั่น 10 → ปล่อยน้ำออก 3
// รอบ 2 น้ำยาปรับผ้านุ่ม: (กด "เริ่มรอบ 2") ปล่อยน้ำเข้า 5 → (กด "ปิดน้ำแล้ว") → ปั่นกับน้ำยา 10 → ปล่อยน้ำออก 3
// เก็บแค่รอบที่ + เวลาเริ่ม 2 ค่า ที่เหลือคิดจากเวลาปัจจุบัน → ปิดแอพไปแล้วกลับมาก็ยังนับถูก

enum LaundryPhase { idle, filling, waitWaterOff, soak, spin, drain, betweenRounds, done }

class LaundryStep {
  final LaundryPhase phase;
  final String label;
  final int minutes;
  final String endTitle, endBody; // แจ้งเตือนตอนขั้นนี้ครบเวลา
  final bool nextRound; // แจ้งเตือนตอนครบมีปุ่ม "เริ่มรอบ 2"
  const LaundryStep(this.phase, this.label, this.minutes, this.endTitle, this.endBody, {this.nextRound = false});
}

class LaundryRound {
  final String name;
  final LaundryStep fill;
  final List<LaundryStep> wash; // ต่อกันอัตโนมัติหลังกดปิดน้ำ
  const LaundryRound(this.name, this.fill, this.wash);
}

const laundryRounds = [
  LaundryRound('รอบ 1 · ซัก',
    LaundryStep(LaundryPhase.filling, 'ปล่อยน้ำเข้า', 5,
        '🚰 ครบ 5 นาทีแล้ว — ปิดน้ำหรือยัง?', 'ปิดน้ำแล้วกด "ปิดน้ำแล้ว" เพื่อเริ่มแช่ผ้า 20 นาที'),
    [
      LaundryStep(LaundryPhase.soak, 'แช่ผ้า', 20, '🧺 แช่ผ้าครบ 20 นาที', 'ได้เวลาปั่น 10 นาที'),
      LaundryStep(LaundryPhase.spin, 'ปั่น', 10, '🌀 ปั่นครบ 10 นาที', 'ปล่อยน้ำออก 3 นาที'),
      LaundryStep(LaundryPhase.drain, 'ปล่อยน้ำออก', 3, '🚿 ปล่อยน้ำออกครบ — ต่อรอบ 2',
          'เปิดน้ำเข้า ใส่น้ำยาปรับผ้านุ่ม แล้วกด "เริ่มรอบ 2"', nextRound: true),
    ]),
  LaundryRound('รอบ 2 · น้ำยาปรับผ้านุ่ม',
    LaundryStep(LaundryPhase.filling, 'ปล่อยน้ำเข้า + น้ำยาปรับผ้านุ่ม', 5,
        '🚰 ครบ 5 นาทีแล้ว — ปิดน้ำหรือยัง?', 'ปิดน้ำแล้วกด "ปิดน้ำแล้ว" เพื่อปั่นกับน้ำยา 10 นาที'),
    [
      LaundryStep(LaundryPhase.spin, 'ปั่นกับน้ำยาปรับผ้านุ่ม', 10, '🌀 ปั่นกับน้ำยาครบ 10 นาที', 'ปล่อยน้ำออก 3 นาที'),
      LaundryStep(LaundryPhase.drain, 'ปล่อยน้ำออก', 3, '✅ ซักผ้าเสร็จแล้ว', 'ปล่อยน้ำออกครบ 3 นาที เอาผ้าไปตากได้เลย'),
    ]),
];
const laundryHour = 8; // เตือนวันซักผ้า เสาร์ 08:00

// ทุกขั้นเรียงต่อกัน (ใช้แสดงรายการขั้นในหน้าซักผ้า)
final laundryRows = [
  for (final (r, round) in laundryRounds.indexed) ...[(r, round.fill), for (final s in round.wash) (r, s)],
];
int _rowStart(int round) => [for (var r = 0; r < round; r++) 1 + laundryRounds[r].wash.length].fold(0, (a, b) => a + b);

class LaundryStatus {
  final LaundryPhase phase;
  final int round; // 0 = รอบซัก, 1 = รอบน้ำยาปรับผ้านุ่ม
  final int pos; // ลำดับใน laundryRows ของขั้นปัจจุบัน (-1 = ยังไม่เริ่ม, laundryRows.length = เสร็จ)
  final DateTime? endsAt; // ขั้นปัจจุบันครบเวลาเมื่อไร (null = ไม่ได้นับอยู่)
  const LaundryStatus(this.phase, {this.round = 0, this.pos = -1, this.endsAt});
  LaundryStep? get step => pos >= 0 && pos < laundryRows.length ? laundryRows[pos].$2 : null;
  Duration left(DateTime now) => endsAt == null || !endsAt!.isAfter(now) ? Duration.zero : endsAt!.difference(now);
}

LaundryStatus laundryStatus(int round, DateTime? fillAt, DateTime? washAt, DateTime now) {
  final r = round.clamp(0, laundryRounds.length - 1);
  final def = laundryRounds[r];
  final start = _rowStart(r);
  if (washAt != null) {
    var end = washAt;
    for (final (k, s) in def.wash.indexed) {
      end = end.add(Duration(minutes: s.minutes));
      if (now.isBefore(end)) return LaundryStatus(s.phase, round: r, pos: start + 1 + k, endsAt: end);
    }
    if (r < laundryRounds.length - 1) {
      // รอเริ่มรอบถัดไป · ทิ้งไว้นานเกิน 3 ชม. = เริ่มใหม่
      return now.difference(end) < const Duration(hours: 3)
          ? LaundryStatus(LaundryPhase.betweenRounds, round: r + 1, pos: _rowStart(r + 1))
          : const LaundryStatus(LaundryPhase.idle);
    }
    // เสร็จนานเกิน 1 ชม. = ไม่โชว์ค้างไว้แล้ว
    return now.difference(end) < const Duration(hours: 1)
        ? LaundryStatus(LaundryPhase.done, round: r, pos: laundryRows.length)
        : const LaundryStatus(LaundryPhase.idle);
  }
  if (fillAt != null) {
    final end = fillAt.add(Duration(minutes: def.fill.minutes));
    if (now.isBefore(end)) return LaundryStatus(LaundryPhase.filling, round: r, pos: start, endsAt: end);
    // ลืมกดยืนยันไว้นานเกิน 3 ชม. (เช่นจากสัปดาห์ก่อน) = เริ่มใหม่
    return now.difference(end) < const Duration(hours: 3)
        ? LaundryStatus(LaundryPhase.waitWaterOff, round: r, pos: start)
        : const LaundryStatus(LaundryPhase.idle);
  }
  return const LaundryStatus(LaundryPhase.idle);
}

// เวลาที่แต่ละขั้นต่อจากกดปิดน้ำของรอบนี้ครบ
List<(LaundryStep, DateTime)> laundryWashEnds(int round, DateTime washAt) {
  var end = washAt;
  return [for (final s in laundryRounds[round].wash) (s, end = end.add(Duration(minutes: s.minutes)))];
}

// เสาร์ถัดไป เวลา hour:00 (ถ้าวันนี้เสาร์และยังไม่ถึงเวลา = วันนี้)
DateTime nextSaturday(DateTime now, int hour) {
  var d = DateTime(now.year, now.month, now.day, hour);
  while (d.weekday != DateTime.saturday || !d.isAfter(now)) {
    d = DateTime(d.year, d.month, d.day + 1, hour);
  }
  return d;
}

class Laundry {
  static const _pref = 'laundry_state'; // {"round": 0|1, "fill": iso, "wash": iso} เก็บรวมใน key เดียว
  static int round = 0;
  static DateTime? fillAt, washAt;
  static final changed = ValueNotifier<int>(0); // หน้าซักผ้าฟังไว้ (กดปุ่มในแจ้งเตือนตอนเปิดหน้าอยู่)
  static Future<void> _queue = Future.value();

  // ทำทีละคำสั่ง: กดเริ่ม/ปิดน้ำ/ยกเลิกซ้อนกัน (เช่นกดในแจ้งเตือนกับในแอพพร้อมกัน) ไม่ให้สถานะกับแจ้งเตือนเพี้ยน
  static Future<void> _serial(Future<void> Function() f) => _queue = _queue.then((_) => f()).catchError((_) {});

  static LaundryStatus status([DateTime? now]) => laundryStatus(round, fillAt, washAt, now ?? DateTime.now());

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    try {
      final j = jsonDecode(p.getString(_pref) ?? '{}') as Map<String, dynamic>;
      round = (j['round'] as num?)?.toInt() ?? 0;
      fillAt = DateTime.tryParse(j['fill'] as String? ?? '');
      washAt = DateTime.tryParse(j['wash'] as String? ?? '');
    } catch (_) {
      round = 0;
      fillAt = washAt = null;
    }
    changed.value++;
  }

  static Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_pref, jsonEncode({
      'round': round,
      if (fillAt != null) 'fill': fillAt!.toIso8601String(),
      if (washAt != null) 'wash': washAt!.toIso8601String(),
    }));
    changed.value++;
  }

  static Future<void> _fill(int r) async {
    round = r;
    fillAt = DateTime.now();
    washAt = null;
    await _save();
    await NotificationService.cancelLaundry();
    await NotificationService.scheduleLaundryFill(laundryRounds[r].fill, fillAt!.add(Duration(minutes: laundryRounds[r].fill.minutes)));
  }

  // เริ่มปล่อยน้ำเข้า: ถ้ารอรอบ 2 อยู่ = เริ่มรอบ 2 · นอกนั้น = เริ่มรอบ 1 ใหม่
  static Future<void> startFill() => _serial(() async {
    final st = status();
    await _fill(st.phase == LaundryPhase.betweenRounds ? st.round : 0);
  });

  // ปุ่ม "เริ่มรอบ 2" ในแจ้งเตือน — รับเฉพาะตอนรอรอบ 2 อยู่จริง
  static Future<void> startNextRound() => _serial(() async {
    await load();
    final st = status();
    if (st.phase == LaundryPhase.betweenRounds) await _fill(st.round);
  });

  // ปิดน้ำแล้ว → ขั้นที่เหลือของรอบนี้ต่อกันอัตโนมัติ
  // รับเฉพาะตอนกำลังปล่อยน้ำเข้า/รอปิดน้ำ (กดแจ้งเตือนเก่าที่ค้าง หรือกดซ้ำ ไม่เริ่มรอบใหม่)
  static Future<void> confirmWaterOff() => _serial(() async {
    await load();
    final phase = status().phase;
    if (phase != LaundryPhase.filling && phase != LaundryPhase.waitWaterOff) return;
    washAt = DateTime.now();
    await _save();
    await NotificationService.cancelLaundry();
    await NotificationService.scheduleLaundryWash(laundryWashEnds(round, washAt!));
  });

  static Future<void> reset() => _serial(() async {
    round = 0;
    fillAt = null;
    washAt = null;
    await _save();
    await NotificationService.cancelLaundry();
  });

  // ตั้งแจ้งเตือนที่ยังไม่ถึงเวลาของรอบที่ค้างอยู่ใหม่ (หลังล้างแจ้งเตือนทั้งหมด/เปิดแอพ)
  static Future<void> resync() => _serial(() async {
    final now = DateTime.now();
    switch (status(now).phase) {
      case LaundryPhase.filling || LaundryPhase.waitWaterOff:
        final fill = laundryRounds[round].fill;
        await NotificationService.scheduleLaundryFill(fill, fillAt!.add(Duration(minutes: fill.minutes)), now: now);
      case LaundryPhase.soak || LaundryPhase.spin || LaundryPhase.drain:
        await NotificationService.scheduleLaundryWash(laundryWashEnds(round, washAt!), now: now);
      case LaundryPhase.idle || LaundryPhase.betweenRounds || LaundryPhase.done:
        break;
    }
  });
}
