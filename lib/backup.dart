import 'dart:convert';
import 'models.dart';

// สำรอง/กู้คืนเป็นข้อความ JSON ผ่านคลิปบอร์ด (วางเก็บไว้ในโน้ต/แชตของตัวเองได้)
String buildBackup(List<TaskItem> tasks, {DateTime? now}) => jsonEncode({
  'app': 'mtb',
  'version': 1,
  'exportedAt': (now ?? DateTime.now()).toIso8601String(),
  'tasks': tasks.map((t) => t.toJson()).toList(),
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
