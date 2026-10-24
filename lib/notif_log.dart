import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ประวัติแจ้งเตือน: แจ้งเตือนในเครื่องเด้งเองโดยแอพไม่รู้ตัว จึงจดทุกอันตอน "ตั้ง" ไว้
// เวลาผ่านไปแล้ว = แจ้งแล้ว · ยกเลิก = ลบอันที่ยังไม่ถึงเวลา · แจ้งเตือนประจำ (แผนเช้า/รีวิว) เติมย้อนหลังตอนเปิดแอพ
class NotifEntry {
  final int id;
  final DateTime at;
  final String title, body;
  final int? taskId; // กดแล้วเปิดงานนี้
  final String? payload; // 'weekly' | 'plan' | 'lastyear'
  NotifEntry(this.id, this.at, this.title, this.body, {this.taskId, this.payload});

  Map<String, dynamic> toJson() => {'id': id, 'at': at.toIso8601String(), 'title': title, 'body': body,
    if (taskId != null) 'task': taskId, if (payload != null) 'payload': payload};
  factory NotifEntry.fromJson(Map<String, dynamic> j) => NotifEntry((j['id'] as num).toInt(), DateTime.parse(j['at'] as String),
    j['title'] as String? ?? '', j['body'] as String? ?? '', taskId: (j['task'] as num?)?.toInt(), payload: j['payload'] as String?);
}

class NotifLog {
  static const _pref = 'notif_log', _seenPref = 'notif_log_seen';
  static const keepDays = 90;
  static List<NotifEntry> entries = [];
  static DateTime? seen; // เติมแจ้งเตือนประจำย้อนหลังถึงตรงนี้แล้ว

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    try {
      entries = (jsonDecode(p.getString(_pref) ?? '[]') as List).map((j) => NotifEntry.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) { entries = []; }
    seen = DateTime.tryParse(p.getString(_seenPref) ?? '');
  }

  static Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_pref, jsonEncode(entries.map((e) => e.toJson()).toList()));
    if (seen != null) await p.setString(_seenPref, seen!.toIso8601String());
  }

  // ตั้งแจ้งเตือน id นี้ใหม่ → แทนอันเดิมที่ยังไม่ถึงเวลา
  static void add(NotifEntry e, {DateTime? now}) {
    removeFuture((id) => id == e.id, now: now);
    entries.add(e);
  }

  static void removeFuture(bool Function(int id) match, {DateTime? now}) {
    final n = now ?? DateTime.now();
    entries.removeWhere((e) => e.at.isAfter(n) && match(e.id));
  }

  // แผนเช้า (ทุกวัน) และรีวิวรายสัปดาห์ (อาทิตย์) ที่เด้งไปแล้วตั้งแต่ครั้งก่อน · ครั้งแรกเริ่มนับจากตอนนี้
  static void backfillRepeating(DateTime now, {required int planHour}) {
    final from = seen ?? now;
    for (var d = DateTime(from.year, from.month, from.day); !d.isAfter(now); d = DateTime(d.year, d.month, d.day + 1)) {
      final plan = DateTime(d.year, d.month, d.day, planHour);
      if (plan.isAfter(from) && !plan.isAfter(now)) {
        entries.add(NotifEntry(9998, plan, 'วางแผนวันนี้', 'เลือกงานที่จะทำวันนี้ และงานกบ 🐸', payload: 'plan'));
      }
      final weekly = DateTime(d.year, d.month, d.day, 9);
      if (d.weekday == DateTime.sunday && weekly.isAfter(from) && !weekly.isAfter(now)) {
        entries.add(NotifEntry(9999, weekly, 'Weekly Review', 'ดูสรุปสัปดาห์ + เคลียร์กล่องรับ', payload: 'weekly'));
      }
    }
    seen = now;
    entries.removeWhere((e) => now.difference(e.at).inDays > keepDays);
  }

  static List<NotifEntry> past(DateTime now) =>
      entries.where((e) => !e.at.isAfter(now)).toList()..sort((a, b) => b.at.compareTo(a.at));
  static List<NotifEntry> upcoming(DateTime now) =>
      entries.where((e) => e.at.isAfter(now)).toList()..sort((a, b) => a.at.compareTo(b.at));
}
