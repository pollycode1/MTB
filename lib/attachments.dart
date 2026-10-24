import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

// ไฟล์แนบเก็บในโฟลเดอร์ของแอพ: <app files>/attachments/<taskId>/<เวลา>_<ชื่อไฟล์>
// ในงานเก็บเป็น path สัมพัทธ์ "taskId/ไฟล์" (ย้ายเครื่อง/กู้ข้อมูลแล้ว path ไม่พัง แต่ตัวไฟล์ไม่ได้อยู่ใน backup)
class Attachments {
  static String rootPath = '';

  // เรียกครั้งเดียวตอนเปิดแอพ (main.dart) · ใช้ที่เก็บภายนอกของแอพก่อน (เปิดดูผ่านสาย USB ได้) ไม่มีค่อยใช้ภายใน
  static Future<void> init() async {
    final base = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/attachments');
    await dir.create(recursive: true);
    rootPath = dir.path;
  }

  static String pathOf(String rel) => '$rootPath/$rel';

  static bool isImage(String rel) => RegExp(r'\.(jpe?g|png|gif|webp|heic|bmp)$', caseSensitive: false).hasMatch(rel);

  static String displayName(String rel) => rel.split('/').last.replaceFirst(RegExp(r'^\d+_'), '');

  static Future<String> _save(int taskId, String name, Future<void> Function(String dest) write) async {
    final dir = Directory('$rootPath/$taskId');
    await dir.create(recursive: true);
    final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = '${DateTime.now().millisecondsSinceEpoch}_$safe';
    await write('${dir.path}/$file');
    return '$taskId/$file';
  }

  // เลือกไฟล์ (หรือรูปจากคลัง) ได้หลายไฟล์ แล้วคัดลอกเข้าโฟลเดอร์ของแอพ
  static Future<List<String>> pick(int taskId, {bool images = false}) async {
    final files = await FilePicker.pickFiles(type: images ? FileType.image : FileType.any);
    final out = <String>[];
    for (final f in files) {
      out.add(await _save(taskId, f.name, f.xFile.saveTo));
    }
    return out;
  }

  static Future<String?> takePhoto(int taskId) async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
    if (x == null) return null;
    return _save(taskId, x.name, x.saveTo);
  }

  static Future<void> open(String rel) => OpenFilex.open(pathOf(rel));

  static Future<void> delete(String rel) async {
    final f = File(pathOf(rel));
    if (await f.exists()) await f.delete();
  }

  // ลบทั้งโฟลเดอร์ของงาน (ตอนลบงาน)
  static Future<void> deleteTask(int taskId) async {
    final d = Directory('$rootPath/$taskId');
    if (await d.exists()) await d.delete(recursive: true);
  }
}
