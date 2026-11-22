import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

// ── ซักผ้า (ทุกวันเสาร์ หรือกดเองวันไหนก็ได้) ─────────────────────────────────────
// รอบ 1 ซัก: ปล่อยน้ำเข้า 5 → (กด "ปิดน้ำแล้ว") → แช่ผ้า 20 → ปั่น 10 → ปล่อยน้ำออก 3
// รอบ 2 น้ำยาปรับผ้านุ่ม: (กด "เริ่มรอบ 2") ปล่อยน้ำเข้า 5 → (กด "ปิดน้ำแล้ว") → ปั่นกับน้ำยา 10 → ปล่อยน้ำออก 3
// (นาทีคือค่าเริ่มต้น ปรับเองได้ในหน้าตั้งค่าซักผ้า → LaundrySettings)
// เก็บแค่รอบที่ + เวลาเริ่ม 2 ค่า ที่เหลือคิดจากเวลาปัจจุบัน → ปิดแอพไปแล้วกลับมาก็ยังนับถูก

enum LaundryPhase { idle, filling, waitWaterOff, soak, spin, drain, betweenRounds, done }

class LaundryStep {
  final String key; // ใช้เก็บเวลาที่ผู้ใช้ปรับเอง
  final LaundryPhase phase;
  final String label;
  final int defaultMinutes;
  final String emoji;
  final bool nextRound; // แจ้งเตือนตอนครบมีปุ่ม "เริ่มรอบ 2"
  const LaundryStep(this.key, this.phase, this.label, this.defaultMinutes, this.emoji, {this.nextRound = false});
  int get minutes => LaundrySettings.minutesFor(this);
}

class LaundryRound {
  final String name;
  final LaundryStep fill;
  final List<LaundryStep> wash; // ต่อกันอัตโนมัติหลังกดปิดน้ำ
  const LaundryRound(this.name, this.fill, this.wash);
}

const laundryRounds = [
  LaundryRound('รอบ 1 · ซัก',
    LaundryStep('fill1', LaundryPhase.filling, 'ปล่อยน้ำเข้า', 5, '🚰'),
    [
      LaundryStep('soak1', LaundryPhase.soak, 'แช่ผ้า', 20, '🧺'),
      LaundryStep('spin1', LaundryPhase.spin, 'ปั่น', 10, '🌀'),
      LaundryStep('drain1', LaundryPhase.drain, 'ปล่อยน้ำออก', 3, '🚿', nextRound: true),
    ]),
  LaundryRound('รอบ 2 · น้ำยาปรับผ้านุ่ม',
    LaundryStep('fill2', LaundryPhase.filling, 'ปล่อยน้ำเข้า + น้ำยาปรับผ้านุ่ม', 5, '🚰'),
    [
      LaundryStep('spin2', LaundryPhase.spin, 'ปั่นกับน้ำยาปรับผ้านุ่ม', 10, '🌀'),
      LaundryStep('drain2', LaundryPhase.drain, 'ปล่อยน้ำออก', 3, '✅'),
    ]),
];

// ข้อความแจ้งเตือนตอนขั้นนี้ครบ (คิดจากเวลาที่ตั้งไว้ตอนนี้)
(String, String) laundryEndText(int round, LaundryStep s) {
  final def = laundryRounds[round];
  if (s.phase == LaundryPhase.filling) {
    final next = def.wash.first;
    return ('${s.emoji} ครบ ${s.minutes} นาทีแล้ว — ปิดน้ำหรือยัง?', 'ปิดน้ำแล้วกด "ปิดน้ำแล้ว" เพื่อเริ่ม${next.label} ${next.minutes} นาที');
  }
  final k = def.wash.indexOf(s);
  if (k >= 0 && k < def.wash.length - 1) {
    final next = def.wash[k + 1];
    return ('${s.emoji} ${s.label}ครบ ${s.minutes} นาที', 'ได้เวลา${next.label} ${next.minutes} นาที');
  }
  if (round < laundryRounds.length - 1) {
    return ('${s.emoji} ${s.label}ครบ — ต่อรอบ 2', 'เปิดน้ำเข้า ใส่น้ำยาปรับผ้านุ่ม แล้วกด "เริ่มรอบ 2"');
  }
  return ('${s.emoji} ซักผ้าเสร็จแล้ว', '${s.label}ครบ ${s.minutes} นาที เอาผ้าไปตากได้เลย');
}

// เวลาที่ผู้ใช้ปรับเอง (หน้าตั้งค่าซักผ้า) · prefs laundry_times
class LaundrySettings {
  static const _pref = 'laundry_times';
  static const defaultWeekday = DateTime.saturday, defaultHour = 8, defaultMinute = 0, defaultNag = 2;
  static Map<String, int> minutes = {};
  static int weekday = defaultWeekday, hour = defaultHour, minute = defaultMinute;
  static int nagEvery = defaultNag; // ยังไม่ปิดน้ำ → ถามซ้ำทุกกี่นาที

  static int minutesFor(LaundryStep s) => minutes[s.key] ?? s.defaultMinutes;

  static void fromJson(Map<String, dynamic> j) {
    minutes = {
      for (final e in ((j['steps'] as Map?) ?? {}).entries)
        if (e.value is num && (e.value as num) > 0) e.key as String: (e.value as num).toInt(),
    };
    weekday = ((j['weekday'] as num?)?.toInt() ?? defaultWeekday).clamp(1, 7);
    hour = ((j['hour'] as num?)?.toInt() ?? defaultHour).clamp(0, 23);
    minute = ((j['minute'] as num?)?.toInt() ?? defaultMinute).clamp(0, 59);
    nagEvery = ((j['nag'] as num?)?.toInt() ?? defaultNag).clamp(1, 30);
  }

  static Map<String, dynamic> toJson() =>
      {'steps': minutes, 'weekday': weekday, 'hour': hour, 'minute': minute, 'nag': nagEvery};

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    try {
      fromJson(jsonDecode(p.getString(_pref) ?? '{}') as Map<String, dynamic>);
    } catch (_) {
      fromJson({});
    }
  }

  static Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_pref, jsonEncode(toJson()));
  }
}

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

// วันซักผ้าครั้งถัดไป (ถ้าวันนี้ใช่และยังไม่ถึงเวลา = วันนี้)
DateTime nextLaundryDay(DateTime now, int weekday, int hour, [int minute = 0]) {
  var d = DateTime(now.year, now.month, now.day, hour, minute);
  while (d.weekday != weekday || !d.isAfter(now)) {
    d = DateTime(d.year, d.month, d.day + 1, hour, minute);
  }
  return d;
}

const laundryWeekdays = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัส', 'ศุกร์', 'เสาร์', 'อาทิตย์'];
String laundryDayLabel() =>
    'วัน${laundryWeekdays[LaundrySettings.weekday - 1]} ${LaundrySettings.hour.toString().padLeft(2, '0')}:${LaundrySettings.minute.toString().padLeft(2, '0')}';

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
    await LaundrySettings.load();
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
    await NotificationService.scheduleLaundryFill(r, fillAt!.add(Duration(minutes: laundryRounds[r].fill.minutes)));
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
    await NotificationService.scheduleLaundryWash(round, laundryWashEnds(round, washAt!));
  });

  // เปลี่ยนเวลาในหน้าตั้งค่า → ตั้งแจ้งเตือนของรอบที่กำลังซักใหม่ตามเวลาใหม่ + วันซักผ้าประจำสัปดาห์
  static Future<void> settingsChanged() async {
    await LaundrySettings.save();
    changed.value++;
    await _serial(NotificationService.cancelLaundry);
    await resync();
    await NotificationService.rescheduleLaundryDay();
  }

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
        await NotificationService.scheduleLaundryFill(round, fillAt!.add(Duration(minutes: fill.minutes)), now: now);
      case LaundryPhase.soak || LaundryPhase.spin || LaundryPhase.drain:
        await NotificationService.scheduleLaundryWash(round, laundryWashEnds(round, washAt!), now: now);
      case LaundryPhase.idle || LaundryPhase.betweenRounds || LaundryPhase.done:
        break;
    }
  });
}
