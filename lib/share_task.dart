import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'attachments.dart';
import 'models.dart';

// แชร์งาน/ไอเดีย 1 รายการเป็นไฟล์ JSON (ข้อมูลครบทุกฟิลด์ รวมขั้นตอนย่อยทุกชั้น) พร้อมไฟล์แนบของงานนั้น
String taskShareJson(TaskItem t, {DateTime? now}) => const JsonEncoder.withIndent('  ').convert({
  'app': 'mtb',
  'version': 1,
  'exportedAt': (now ?? DateTime.now()).toIso8601String(),
  'task': t.toJson(),
});

Future<void> shareTask(TaskItem t) async {
  final dir = await getTemporaryDirectory();
  final name = t.title.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  final json = File('${dir.path}/${name.isEmpty ? 'task' : name}.json');
  await json.writeAsString(taskShareJson(t));
  final files = [
    XFile(json.path, mimeType: 'application/json'),
    for (final rel in t.attachments)
      if (File(Attachments.pathOf(rel)).existsSync()) XFile(Attachments.pathOf(rel)),
  ];
  await SharePlus.instance.share(ShareParams(files: files, subject: t.title, text: t.title));
}
