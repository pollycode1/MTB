import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

// ── ตารางประจำสัปดาห์ (ตารางสอน / งานพิเศษ) · ช่วงเวลาในตาราง · วันหยุด ─────────────────────
const kDayStartMin = 6 * 60;        // 06:00
const kDayEndMin   = 16 * 60 + 30;  // 16:30
const kSlotMin     = 30;            // แตะ/เลือกได้ทีละ 30 นาที

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
String hm(int min) => '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';
int minOfDay(DateTime d) => d.hour * 60 + d.minute;

// คาบสอน / งานพิเศษที่เกิดซ้ำทุกสัปดาห์ (ไม่ใช่งานที่ต้องติ๊ก)
class WeeklyBlock {
  int weekday;        // 1 = จันทร์ ... 7 = อาทิตย์
  int startMin, endMin;
  String title;
  final String kind;  // 'teach' | 'duty'
  WeeklyBlock({required this.weekday, required this.startMin, required this.endMin, required this.title, required this.kind});

  Map<String, dynamic> toJson() => {'weekday': weekday, 'start': startMin, 'end': endMin, 'title': title, 'kind': kind};
  factory WeeklyBlock.fromJson(Map<String, dynamic> j) => WeeklyBlock(
    weekday: (j['weekday'] as num).toInt(), startMin: (j['start'] as num).toInt(), endMin: (j['end'] as num).toInt(),
    title: j['title'] as String? ?? '', kind: j['kind'] as String? ?? 'teach');
}

class ScheduleStore {
  static const _pref = 'schedule_blocks';
  static List<WeeklyBlock> blocks = [];

  static Future<void> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_pref);
    if (raw == null) return;
    try {
      blocks = (jsonDecode(raw) as List).map((j) => WeeklyBlock.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {/* ข้อมูลเสีย → เริ่มว่าง */}
  }

  static Future<void> save() async => (await SharedPreferences.getInstance())
      .setString(_pref, jsonEncode(blocks.map((b) => b.toJson()).toList()));
}

// ── วันหยุด: นักขัตฤกษ์จากปฏิทินวันหยุดไทยของ Google (เก็บไว้ในเครื่อง) + วันหยุดพิเศษที่เพิ่มเอง ─────────
class Holidays {
  static const _cachePref = 'holidays_public';   // {"2026-10-23": "วันปิยมหาราช", ...}
  static const _customPref = 'holidays_custom';
  static const _feed = 'https://calendar.google.com/calendar/ical/th.th%23holiday%40group.v.calendar.google.com/public/basic.ics';
  static Map<String, String> public = {};
  static Map<String, String> custom = {};
  static DateTime? fetchedAt;

  static String key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static String? nameOn(DateTime d) => custom[key(d)] ?? public[key(d)];

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    public = Map<String, String>.from(jsonDecode(p.getString(_cachePref) ?? '{}') as Map);
    custom = Map<String, String>.from(jsonDecode(p.getString(_customPref) ?? '{}') as Map);
    final f = p.getString('${_cachePref}_at');
    fetchedAt = f == null ? null : DateTime.tryParse(f);
  }

  static Future<void> setCustom(DateTime d, String? name) async {
    if (name == null) { custom.remove(key(d)); } else { custom[key(d)] = name; }
    await (await SharedPreferences.getInstance()).setString(_customPref, jsonEncode(custom));
  }

  // โหลดใหม่ถ้ายังไม่เคยโหลด หรือโหลดไว้นานกว่า 30 วัน · คืน true ถ้าได้ข้อมูลใหม่
  static Future<bool> refreshIfStale() async {
    if (fetchedAt != null && DateTime.now().difference(fetchedAt!).inDays < 30) return false;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse(_feed));
      final res = await req.close().timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return false;
      final parsed = parseThaiHolidayIcs(await res.transform(utf8.decoder).join());
      if (parsed.isEmpty) return false;
      public = parsed;
      fetchedAt = DateTime.now();
      final p = await SharedPreferences.getInstance();
      await p.setString(_cachePref, jsonEncode(public));
      await p.setString('${_cachePref}_at', fetchedAt!.toIso8601String());
      return true;
    } catch (_) {
      return false; // ไม่มีเน็ต → ใช้ที่เก็บไว้
    } finally {
      client.close();
    }
  }
}

// อ่านไฟล์ .ics: เอาเฉพาะ "วันหยุดนักขัตฤกษ์" (ไม่เอาวันสำคัญอย่างวาเลนไทน์) · วันหลายวันกระจายเป็นรายวัน
Map<String, String> parseThaiHolidayIcs(String ics) {
  final text = ics.replaceAll('\r\n', '\n').replaceAll('\n ', ''); // รวมบรรทัดที่ถูกพับ
  final out = <String, String>{};
  for (final ev in text.split('BEGIN:VEVENT').skip(1)) {
    String? field(String name) {
      final m = RegExp('^$name[^:\\n]*:(.*)\$', multiLine: true).firstMatch(ev);
      return m?.group(1)?.trim();
    }
    if (!(field('DESCRIPTION') ?? '').startsWith('วันหยุดนักขัตฤกษ์')) continue;
    final start = DateTime.tryParse(field('DTSTART') ?? '');
    if (start == null) continue;
    final end = DateTime.tryParse(field('DTEND') ?? '') ?? start.add(const Duration(days: 1));
    final name = (field('SUMMARY') ?? 'วันหยุด').replaceAll('​', '').trim();
    for (var d = start; d.isBefore(end); d = d.add(const Duration(days: 1))) {
      out[Holidays.key(d)] = name;
    }
  }
  return out;
}

// ── งานในตาราง: งานที่ทำซ้ำจะโผล่ทุกรอบถัดไปจนกว่าจะติ๊กเสร็จ (ติ๊กแล้วแอพสร้างรอบถัดไปให้เอง) ───────
bool _recurOn(TaskItem t, DateTime day) {
  final s = dateOnly(t.slotStart!);
  if (day.isBefore(s)) return false;
  return switch (t.recurrence) {
    'daily'   => true,
    'weekly'  => day.weekday == s.weekday,
    'monthly' => day.day == s.day,
    'yearly'  => day.day == s.day && day.month == s.month,
    _         => false,
  };
}

// (งาน, เวลาเริ่มของรอบนั้น) ในวันที่ระบุ
List<(TaskItem, DateTime)> occurrencesOn(List<TaskItem> tasks, DateTime day) {
  final out = <(TaskItem, DateTime)>[];
  for (final t in tasks) {
    if (t.type != 'task' || t.archivedAt != null || t.slotStart == null) continue;
    final s = t.slotStart!;
    if (sameDay(s, day)) {
      out.add((t, s));
    } else if (!t.done && t.recurrence != null && _recurOn(t, day)) {
      out.add((t, DateTime(day.year, day.month, day.day, s.hour, s.minute)));
    }
  }
  out.sort((a, b) => a.$2.compareTo(b.$2));
  return out;
}

// คาบสอน/งานพิเศษของวันนั้น (วันหยุดไม่มี)
List<WeeklyBlock> blocksOn(List<WeeklyBlock> blocks, DateTime day, {bool holiday = false}) =>
    holiday ? [] : (blocks.where((b) => b.weekday == day.weekday).toList()..sort((a, b) => a.startMin.compareTo(b.startMin)));

// ช่วงที่ไม่ว่าง (นาทีของวัน) จากคาบประจำ + งานที่ลงเวลา · ignore = งานที่กำลังย้ายเวลาเอง
List<(int, int)> busyOn(DateTime day, List<TaskItem> tasks, List<WeeklyBlock> blocks, {bool holiday = false, TaskItem? ignore}) => [
  for (final b in blocksOn(blocks, day, holiday: holiday)) (b.startMin, b.endMin),
  for (final (t, s) in occurrencesOn(tasks, day))
    if (!identical(t, ignore)) (minOfDay(s), minOfDay(s) + t.slotMin),
];

bool isFree(int start, int end, List<(int, int)> busy) =>
    start >= kDayStartMin && end <= kDayEndMin && busy.every((b) => end <= b.$1 || start >= b.$2);

// เวลาเริ่มที่ว่างพอสำหรับงานยาว dur นาที (ทีละ 30 นาที)
List<int> freeStarts(List<(int, int)> busy, int dur) => [
  for (var s = kDayStartMin; s + dur <= kDayEndMin; s += kSlotMin)
    if (isFree(s, s + dur, busy)) s,
];

// ว่างต่อเนื่องจาก start ได้นานสุดกี่นาที (0 = ช่องนี้ไม่ว่าง)
int freeLength(int start, List<(int, int)> busy) {
  var end = start;
  while (end + kSlotMin <= kDayEndMin && isFree(start, end + kSlotMin, busy)) {
    end += kSlotMin;
  }
  return end - start;
}
