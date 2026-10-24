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

// ── นำเข้าตารางสอนจาก JSON (วางจากคลิปบอร์ด เช่น ให้ AI แปลงรูปตารางสอนมาเป็นรูปแบบนี้) ─────────────
const scheduleTemplate = '''แปลงตารางสอนของฉันเป็น JSON รูปแบบนี้ (day = จ/อ/พ/พฤ/ศ/ส/อา หรือ 1–7, เวลา HH:mm ช่วง 06:00–16:30, kind = teach คาบสอน / duty งานพิเศษ เช่น เวร)
{"blocks": [
  {"day": "จ", "start": "08:30", "end": "09:20", "title": "คณิต ม.2/3", "kind": "teach"},
  {"day": "ศ", "start": "15:30", "end": "16:30", "title": "เวรประตู", "kind": "duty"}
]}''';

const _thaiDays = {
  'จ': 1, 'จันทร์': 1, 'อ': 2, 'อังคาร': 2, 'พ': 3, 'พุธ': 3, 'พฤ': 4, 'พฤหัส': 4, 'พฤหัสบดี': 4,
  'ศ': 5, 'ศุกร์': 5, 'ส': 6, 'เสาร์': 6, 'อา': 7, 'อาทิตย์': 7,
};

int? _parseTime(Object? v) {
  final m = RegExp(r'^(\d{1,2})[:.](\d{2})$').firstMatch('${v ?? ''}'.trim());
  if (m == null) return null;
  final h = int.parse(m[1]!), min = int.parse(m[2]!);
  return h < 24 && min < 60 ? h * 60 + min : null;
}

// อ่าน {"blocks":[...]} หรือ [...] · ข้ามข้อความรอบ JSON (คำอธิบาย/```json จาก AI)
// ผิดแม้แถวเดียว → ไม่นำเข้าเลย บอกว่าแถวไหนผิด (ห้ามทับตารางเดิมด้วยข้อมูลครึ่งๆ)
({List<WeeklyBlock>? blocks, String? error}) parseScheduleJson(String text) {
  final start = text.indexOf(RegExp(r'[\[{]'));
  final end = text.lastIndexOf(RegExp(r'[\]}]'));
  if (start < 0 || end <= start) return (blocks: null, error: 'ไม่พบ JSON ในข้อความ');
  Object? data;
  try { data = jsonDecode(text.substring(start, end + 1)); } catch (_) {
    return (blocks: null, error: 'อ่าน JSON ไม่ได้ (รูปแบบผิด)');
  }
  final rows = data is Map ? data['blocks'] : data;
  if (rows is! List || rows.isEmpty) return (blocks: null, error: 'ไม่มีรายการใน "blocks"');
  final out = <WeeklyBlock>[];
  for (var i = 0; i < rows.length; i++) {
    final r = rows[i];
    final bad = 'แถวที่ ${i + 1}';
    if (r is! Map) return (blocks: null, error: '$bad ไม่ใช่ {...}');
    final d = r['day'], day = d is num ? d.toInt() : _thaiDays['${d ?? ''}'.trim()];
    if (day == null || day < 1 || day > 7) return (blocks: null, error: '$bad: day ไม่ถูกต้อง ($d)');
    final s = _parseTime(r['start']), e = _parseTime(r['end']);
    if (s == null || e == null || e <= s) return (blocks: null, error: '$bad: เวลาไม่ถูกต้อง (${r['start']}–${r['end']})');
    final title = '${r['title'] ?? ''}'.trim();
    if (title.isEmpty) return (blocks: null, error: '$bad: ไม่มี title');
    out.add(WeeklyBlock(weekday: day, startMin: s, endMin: e, title: title, kind: r['kind'] == 'duty' ? 'duty' : 'teach'));
  }
  return (blocks: out, error: null);
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

// ── รอบถัดไปของงานประจำ ─────────────────────────────────────────────────────────────────
// รายสัปดาห์ที่ตกวันหยุด → เลื่อนไปวันเรียนถัดไป (จ.–ศ. ที่ไม่ใช่วันหยุด) คงเวลาเดิม
// รอบถัดไปคิดจากวันเดิมก่อนเลื่อน (deadline - recurShift) จะได้กลับมาวันเดิมของสัปดาห์
DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n, d.hour, d.minute);

DateTime _step(DateTime from, String recurrence) => switch (recurrence) {
  'weekly'  => _addDays(from, 7),
  'monthly' => DateTime(from.year, from.month + 1, from.day, from.hour, from.minute),
  'yearly'  => DateTime(from.year + 1, from.month, from.day, from.hour, from.minute),
  _         => _addDays(from, 1),
};

({DateTime? deadline, DateTime? slotStart, int shift}) nextOccurrence(TaskItem t) {
  final r = t.recurrence!;
  DateTime? next(DateTime? d) => d == null ? null : _step(_addDays(d, -t.recurShift), r);
  final deadline = next(t.deadline), slot = next(t.slotStart);
  var shift = 0;
  final anchor = deadline ?? slot;
  if (r == 'weekly' && anchor != null && Holidays.nameOn(anchor) != null) {
    var d = anchor;
    do { d = _addDays(d, 1); shift++; } while (Holidays.nameOn(d) != null || d.weekday > 5);
  }
  return (
    deadline: deadline == null ? null : _addDays(deadline, shift),
    slotStart: slot == null ? null : _addDays(slot, shift),
    shift: shift,
  );
}

// ── แจ้งเตือนก่อนคาบ ────────────────────────────────────────────────────────────────────────
// ห้องในชื่อคาบ เช่น "คณิต ม.2/3" → "ม.2/3" ใช้นับงานค้างที่ชื่อ/แท็ก/หมายเหตุมีห้องนี้
String? roomOf(String s) => RegExp(r'[มป]\.\s?\d+(/\d+)?').firstMatch(s)?.group(0)?.replaceAll(' ', '');

bool _mentionsRoom(TaskItem t, String room) {
  // ม.2/3 ต้องไม่ไปตรงกับ ม.2/30
  final re = RegExp('${RegExp.escape(room)}(?!\\d)');
  return [t.title, t.meta, ...t.tags].any((s) => re.hasMatch(s.replaceAll(' ', '')));
}

// เตือนก่อนเริ่มคาบ/งานพิเศษ [lead] นาที ใน [days] วันข้างหน้า (ข้ามวันหยุด) · คิดจำนวนงานค้างตอนตั้งเตือน
// ponytail: ตั้งล่วงหน้าเป็นรายครั้ง (ข้อความเปลี่ยนตามงานค้าง) ไม่เปิดแอพเกิน [days] วันการเตือนจะหมด
List<({DateTime at, String title, String body})> classReminders(
    List<WeeklyBlock> blocks, List<TaskItem> tasks, DateTime now, {int days = 14, int lead = 10}) {
  final open = tasks.where((t) => t.type == 'task' && !t.done && t.archivedAt == null).toList();
  final out = <({DateTime at, String title, String body})>[];
  for (var i = 0; i < days; i++) {
    final day = DateTime(now.year, now.month, now.day + i);
    for (final b in blocksOn(blocks, day, holiday: Holidays.nameOn(day) != null)) {
      final at = DateTime(day.year, day.month, day.day, 0, b.startMin - lead);
      if (!at.isAfter(now)) continue;
      final room = roomOf(b.title);
      final mine = room == null ? <TaskItem>[] : open.where((t) => _mentionsRoom(t, room)).toList();
      out.add((
        at: at,
        title: b.kind == 'teach' ? 'อีก $lead นาทีสอน ${b.title}' : 'อีก $lead นาที: ${b.title}',
        body: mine.isEmpty ? '${hm(b.startMin)}–${hm(b.endMin)}'
            : 'งานค้างของห้องนี้ ${mine.length} งาน · ${mine.take(3).map((t) => t.title).join(', ')}',
      ));
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
