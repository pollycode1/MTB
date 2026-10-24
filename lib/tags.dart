import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

// รายชื่อแท็กกลางของทั้งแอพ: แท็กที่ผู้ใช้/AI สร้าง + แท็กที่มีอยู่ในงาน (ลบแล้วหายจากทุกที่)
class Tags {
  static const _pref = 'settings_tags';
  static List<String> list = ['ด่วน', 'รอเอกสาร', 'ประชุม'];

  static Future<void> load() async {
    final v = (await SharedPreferences.getInstance()).getStringList(_pref);
    if (v != null) list = v;
  }

  static Future<void> save() async =>
      (await SharedPreferences.getInstance()).setStringList(_pref, list);

  // แท็กที่อยู่ในงานแต่ยังไม่อยู่ในรายการ (ข้อมูลเก่า/จาก widget) → เพิ่มเข้ารายการ
  static void mergeFrom(List<TaskItem> tasks) {
    var changed = false;
    for (final t in tasks) {
      for (final tag in t.tags) {
        if (tag.isNotEmpty && !list.contains(tag)) { list.add(tag); changed = true; }
      }
    }
    if (changed) save();
  }

  static void add(String tag) {
    if (tag.isEmpty || list.contains(tag)) return;
    list.add(tag);
    save();
  }

  // ลบออกจากแอพ: เอาออกจากรายการและจากทุกงาน · คืนจำนวนงานที่ถูกแก้
  static int removeEverywhere(String tag, List<TaskItem> tasks) {
    list.remove(tag);
    save();
    var n = 0;
    for (final t in tasks) {
      if (t.tags.remove(tag)) n++;
    }
    return n;
  }
}

