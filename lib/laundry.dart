import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

// ── ซักผ้า (ทุกวันเสาร์) ──────────────────────────────────────────────────────
// ขั้น 1 ปล่อยน้ำเข้า 5 นาที → แจ้งเตือนถามว่าปิดน้ำหรือยัง (มีปุ่ม "ปิดน้ำแล้ว" ในแจ้งเตือน)
// ขั้น 2 กดปิดน้ำแล้ว → แช่ผ้า 20 → ปั่น 10 → ปล่อยน้ำออก 3 นาที ต่อกันอัตโนมัติ แจ้งเตือนทุกขั้นที่ครบ
// เก็บแค่เวลาเริ่ม 2 ค่า ที่เหลือคิดจากเวลาปัจจุบัน → ปิดแอพไปแล้วกลับมาก็ยังนับถูก

enum LaundryPhase { idle, filling, waitWaterOff, soak, spin, drain, done }

class LaundryStep {
  final LaundryPhase phase;
  final String label;
  final int minutes;
  final String endTitle, endBody; // แจ้งเตือนตอนขั้นนี้ครบเวลา
  const LaundryStep(this.phase, this.label, this.minutes, this.endTitle, this.endBody);
}

const laundryFill = LaundryStep(LaundryPhase.filling, 'ปล่อยน้ำเข้า', 5,
    '🚰 ครบ 5 นาทีแล้ว — ปิดน้ำหรือยัง?', 'ปิดน้ำแล้วกด "ปิดน้ำแล้ว" เพื่อเริ่มแช่ผ้า 20 นาที');
const laundryWash = [
  LaundryStep(LaundryPhase.soak, 'แช่ผ้า', 20, '🧺 แช่ผ้าครบ 20 นาที', 'ได้เวลาปั่น 10 นาที'),
  LaundryStep(LaundryPhase.spin, 'ปั่น', 10, '🌀 ปั่นครบ 10 นาที', 'ปล่อยน้ำออก 3 นาที'),
  LaundryStep(LaundryPhase.drain, 'ปล่อยน้ำออก', 3, '✅ ซักผ้าเสร็จแล้ว', 'ปล่อยน้ำออกครบ 3 นาที เอาผ้าไปตากได้เลย'),
];
const laundryHour = 8; // เตือนวันซักผ้า เสาร์ 08:00

class LaundryStatus {
  final LaundryPhase phase;
  final DateTime? endsAt; // ขั้นปัจจุบันครบเวลาเมื่อไร (null = ไม่ได้นับอยู่)
  const LaundryStatus(this.phase, [this.endsAt]);
  Duration left(DateTime now) => endsAt == null || !endsAt!.isAfter(now) ? Duration.zero : endsAt!.difference(now);
}

LaundryStatus laundryStatus(DateTime? fillAt, DateTime? washAt, DateTime now) {
  if (washAt != null) {
    var end = washAt;
    for (final s in laundryWash) {
      end = end.add(Duration(minutes: s.minutes));
      if (now.isBefore(end)) return LaundryStatus(s.phase, end);
    }
    // เสร็จนานเกิน 1 ชม. = ไม่โชว์ค้างไว้แล้ว
    return LaundryStatus(now.difference(end) < const Duration(hours: 1) ? LaundryPhase.done : LaundryPhase.idle);
  }
  if (fillAt != null) {
    final end = fillAt.add(Duration(minutes: laundryFill.minutes));
    if (now.isBefore(end)) return LaundryStatus(LaundryPhase.filling, end);
    // ลืมกดยืนยันไว้นานเกิน 3 ชม. (เช่นจากสัปดาห์ก่อน) = เริ่มใหม่
    return LaundryStatus(now.difference(end) < const Duration(hours: 3) ? LaundryPhase.waitWaterOff : LaundryPhase.idle);
  }
  return const LaundryStatus(LaundryPhase.idle);
}

// เวลาที่แต่ละขั้นของรอบซักครบ (แช่/ปั่น/ปล่อยน้ำออก)
List<(LaundryStep, DateTime)> laundryWashEnds(DateTime washAt) {
  var end = washAt;
  return [for (final s in laundryWash) (s, end = end.add(Duration(minutes: s.minutes)))];
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
  static const _pref = 'laundry_state'; // {"fill": iso, "wash": iso} เก็บคู่กันใน key เดียว
  static DateTime? fillAt, washAt;
  static final changed = ValueNotifier<int>(0); // หน้าซักผ้าฟังไว้ (กดปุ่มในแจ้งเตือนตอนเปิดหน้าอยู่)
  static Future<void> _queue = Future.value();

  // ทำทีละคำสั่ง: กดเริ่ม/ปิดน้ำ/ยกเลิกซ้อนกัน (เช่นกดในแจ้งเตือนกับในแอพพร้อมกัน) ไม่ให้สถานะกับแจ้งเตือนเพี้ยน
  static Future<void> _serial(Future<void> Function() f) => _queue = _queue.then((_) => f()).catchError((_) {});

  static LaundryStatus status([DateTime? now]) => laundryStatus(fillAt, washAt, now ?? DateTime.now());

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    try {
      final j = jsonDecode(p.getString(_pref) ?? '{}') as Map<String, dynamic>;
      fillAt = DateTime.tryParse(j['fill'] as String? ?? '');
      washAt = DateTime.tryParse(j['wash'] as String? ?? '');
    } catch (_) {
      fillAt = washAt = null;
    }
    changed.value++;
  }

  static Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_pref, jsonEncode({
      if (fillAt != null) 'fill': fillAt!.toIso8601String(),
      if (washAt != null) 'wash': washAt!.toIso8601String(),
    }));
    changed.value++;
  }

  // ขั้น 1: เริ่มปล่อยน้ำเข้า 5 นาที
  static Future<void> startFill() => _serial(() async {
    fillAt = DateTime.now();
    washAt = null;
    await _save();
    await NotificationService.cancelLaundry();
    await NotificationService.scheduleLaundryFill(fillAt!.add(Duration(minutes: laundryFill.minutes)));
  });

  // ขั้น 2: ปิดน้ำแล้ว → แช่/ปั่น/ปล่อยน้ำออก
  // รับเฉพาะตอนกำลังปล่อยน้ำเข้า/รอปิดน้ำ (กดแจ้งเตือนเก่าที่ค้าง หรือกดซ้ำ ไม่เริ่มรอบใหม่)
  static Future<void> confirmWaterOff() => _serial(() async {
    await load();
    final phase = status().phase;
    if (phase != LaundryPhase.filling && phase != LaundryPhase.waitWaterOff) return;
    washAt = DateTime.now();
    await _save();
    await NotificationService.cancelLaundry();
    await NotificationService.scheduleLaundryWash(laundryWashEnds(washAt!));
  });

  static Future<void> reset() => _serial(() async {
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
        await NotificationService.scheduleLaundryFill(fillAt!.add(Duration(minutes: laundryFill.minutes)), now: now);
      case LaundryPhase.soak || LaundryPhase.spin || LaundryPhase.drain:
        await NotificationService.scheduleLaundryWash(laundryWashEnds(washAt!), now: now);
      case LaundryPhase.idle || LaundryPhase.done:
        break;
    }
  });
}
