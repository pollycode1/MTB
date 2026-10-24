import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'attachments.dart';
import 'models.dart';

// สำรอง/กู้คืนเป็นข้อความ JSON ผ่านคลิปบอร์ด (วางเก็บไว้ในโน้ต/แชตของตัวเองได้)
// files = ไฟล์แนบ {path สัมพัทธ์: base64} ใส่เฉพาะไฟล์สำรองอัตโนมัติ (คลิปบอร์ดไม่ใส่ เพราะใหญ่)
String buildBackup(List<TaskItem> tasks, {DateTime? now, Map<String, String> files = const {}}) => jsonEncode({
  'app': 'mtb',
  'version': 1,
  'exportedAt': (now ?? DateTime.now()).toIso8601String(),
  'tasks': tasks.map((t) => t.toJson()).toList(),
  if (files.isNotEmpty) 'files': files,
});

// ไม่ใช่ข้อมูลสำรองของ MTB หรืออ่านไม่ได้ → null (ห้ามไปทับข้อมูลเดิม)
List<TaskItem>? parseBackup(String text) {
  try {
    final m = jsonDecode(text.trim());
    if (m is! Map || m['app'] != 'mtb' || m['tasks'] is! List) return null;
    return (m['tasks'] as List).map((j) => TaskItem.fromJson(j as Map<String, dynamic>)).toList();
  } catch (_) {
    return null;
  }
}

// ไฟล์แนบในข้อมูลสำรอง · ข้าม path ที่หลุดออกนอกโฟลเดอร์ไฟล์แนบ (มี ..) หรืออ่านไม่ได้
Map<String, List<int>> parseBackupFiles(String text) {
  final out = <String, List<int>>{};
  try {
    final files = (jsonDecode(text.trim()) as Map)['files'];
    if (files is! Map) return out;
    files.forEach((rel, b64) {
      if (rel is String && b64 is String && !rel.split('/').contains('..') && !rel.startsWith('/')) {
        try { out[rel] = base64Decode(b64); } catch (_) {}
      }
    });
  } catch (_) {}
  return out;
}

// สำรองอัตโนมัติ: 1 ไฟล์ต่อวัน (เขียนทับได้ทั้งวัน) รวมไฟล์แนบ เก็บไว้ล่าสุด [keep] วัน
// ponytail: ฝังไฟล์แนบทุกไฟล์ในทุกไฟล์สำรอง ถ้าแนบเยอะจนไฟล์ใหญ่ ค่อยเปลี่ยนเป็นเก็บไฟล์แนบแยกโฟลเดอร์เดียว
Future<File> writeDailyBackup(Directory dir, List<TaskItem> tasks,
    {required String attachRoot, DateTime? now, int keep = 7}) async {
  now ??= DateTime.now();
  await dir.create(recursive: true);
  final files = <String, String>{};
  for (final rel in tasks.expand((t) => t.attachments)) {
    final f = File('$attachRoot/$rel');
    if (await f.exists()) files[rel] = base64Encode(await f.readAsBytes());
  }
  String two(int n) => n.toString().padLeft(2, '0');
  final out = File('${dir.path}/mtb-backup-${now.year}-${two(now.month)}-${two(now.day)}.json');
  // เขียนลงไฟล์ชั่วคราวก่อน แอพถูกปิดกลางทางจะได้ไม่ทับไฟล์ของวันนี้ด้วยไฟล์ครึ่งๆ
  final tmp = File('${out.path}.tmp');
  await tmp.writeAsString(buildBackup(tasks, now: now, files: files), flush: true);
  if (await out.exists()) await out.delete();
  await tmp.rename(out.path);

  final name = RegExp(r'mtb-backup-\d{4}-\d\d-\d\d\.json$');
  final all = dir.listSync().whereType<File>().where((f) => name.hasMatch(f.path)).toList()
    ..sort((a, b) => b.path.compareTo(a.path));
  for (final f in all.skip(keep)) {
    try { await f.delete(); } catch (_) {/* ไฟล์ของแอพเวอร์ชันที่ลงไว้ก่อนหน้า ลบไม่ได้ก็ปล่อยไว้ */}
  }
  return out;
}

class AutoBackup {
  // โฟลเดอร์ Download ของเครื่อง เปิดดูจากแอพจัดการไฟล์ได้ และไม่หายตอนลบแอพ
  static const publicDir = '/storage/emulated/0/Download/MTB';
  static String? lastPath;
  static bool _running = false;

  // เรียกตอนเปิดแอพและตอนสลับออกจากแอพ · เขียน Download ไม่ได้ (Android 9 ลงไป) → เก็บในโฟลเดอร์ของแอพแทน
  static Future<void> run(List<TaskItem> tasks) async {
    if (_running) return;
    _running = true;
    final snapshot = List<TaskItem>.of(tasks);
    try {
      lastPath = (await writeDailyBackup(Directory(publicDir), snapshot, attachRoot: Attachments.rootPath)).path;
    } catch (_) {
      try {
        final base = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
        lastPath = (await writeDailyBackup(Directory('${base.path}/backups'), snapshot, attachRoot: Attachments.rootPath)).path;
      } catch (_) {/* สำรองไม่ได้ ไม่ให้แอพพัง ครั้งหน้าลองใหม่ */}
    } finally {
      _running = false;
    }
  }

  // กู้ไฟล์แนบจากข้อมูลสำรองกลับเข้าโฟลเดอร์ของแอพ
  static Future<void> restoreFiles(String text) async {
    for (final e in parseBackupFiles(text).entries) {
      final f = File(Attachments.pathOf(e.key));
      await f.parent.create(recursive: true);
      await f.writeAsBytes(e.value);
    }
  }
}
