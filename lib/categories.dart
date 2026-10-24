import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

// หมวดหมู่ที่ผู้ใช้จัดการเองในหน้าตั้งค่า · โหลดครั้งเดียวตอนเปิดแอพ (main.dart)
class Categories {
  static const _pref = 'settings_areas';
  static List<String> list = ['สอน', 'ส่วนตัว', 'บ้าน'];

  static Future<void> load() async {
    final v = (await SharedPreferences.getInstance()).getStringList(_pref);
    if (v != null) list = v;
  }

  static Future<void> save() async =>
      (await SharedPreferences.getInstance()).setStringList(_pref, list);
}

// ── หน้าจัดการหมวดหมู่: เพิ่ม · แก้ชื่อ · ลบ · ลากเรียงลำดับ ─────────────────────────────
class CategoriesScreen extends StatefulWidget {
  final List<TaskItem> tasks;
  final VoidCallback onTasksChanged; // แก้ชื่อ/ลบหมวด แล้วงานในหมวดนั้นเปลี่ยนตาม → ให้หน้าหลักบันทึก
  const CategoriesScreen({super.key, required this.tasks, required this.onTasksChanged});
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  int _count(String a) => widget.tasks.where((t) => t.area == a).length;

  // ชื่อหมวดใหม่ (null = ยกเลิก) · ห้ามว่าง ห้ามซ้ำ ห้ามใช้คำว่า "ไม่ระบุ"
  Future<String?> _askName(String title, {String initial = ''}) async {
    final ctrl = TextEditingController(text: initial);
    String? error;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        backgroundColor: kCSurf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCText)),
        content: TextField(
          controller: ctrl, autofocus: true,
          style: const TextStyle(color: kCText),
          decoration: InputDecoration(
            hintText: 'เช่น ประชุม, ชมรม, โปรเจกต์',
            hintStyle: TextStyle(color: kCText.withValues(alpha: .3)),
            errorText: error,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('ยกเลิก', style: TextStyle(color: kCText.withValues(alpha: .5)))),
          TextButton(
            onPressed: () {
              final v = ctrl.text.trim();
              final err = v.isEmpty ? 'ใส่ชื่อหมวด'
                  : v == 'ไม่ระบุ' ? 'ใช้ชื่อนี้ไม่ได้'
                  : (v != initial && Categories.list.contains(v)) ? 'มีหมวดนี้แล้ว'
                  : null;
              if (err != null) { setD(() => error = err); return; }
              Navigator.pop(ctx, v);
            },
            child: const Text('บันทึก', style: TextStyle(color: kCGreenDk, fontWeight: FontWeight.w700)),
          ),
        ],
      )),
    );
  }

  Future<void> _add() async {
    final v = await _askName('เพิ่มหมวด');
    if (v == null) return;
    setState(() => Categories.list.add(v));
    await Categories.save();
  }

  Future<void> _rename(int i) async {
    final old = Categories.list[i];
    final v = await _askName('แก้ชื่อหมวด', initial: old);
    if (v == null || v == old) return;
    setState(() {
      Categories.list[i] = v;
      for (final t in widget.tasks) {
        if (t.area == old) t.area = v;
      }
    });
    await Categories.save();
    widget.onTasksChanged();
  }

  Future<void> _delete(int i) async {
    final a = Categories.list[i];
    final n = _count(a);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCSurf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('ลบหมวด "$a"?', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCText)),
        content: Text(n == 0 ? 'ไม่มีงานในหมวดนี้' : 'งาน $n รายการในหมวดนี้จะกลายเป็น "ไม่ระบุหมวด" (ตัวงานไม่ถูกลบ)',
          style: TextStyle(fontSize: 13.5, color: kCText.withValues(alpha: .6))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('ยกเลิก', style: TextStyle(color: kCText.withValues(alpha: .5)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ลบ', style: TextStyle(color: kCRed, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      Categories.list.removeAt(i);
      for (final t in widget.tasks) {
        if (t.area == a) t.area = null;
      }
    });
    await Categories.save();
    if (n > 0) widget.onTasksChanged();
  }

  @override
  Widget build(BuildContext context) {
    final list = Categories.list;
    return Scaffold(
      backgroundColor: kCBg,
      appBar: AppBar(
        backgroundColor: kCBg, elevation: 0,
        title: const Text('หมวดหมู่', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kCText)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: kCSurf,
        icon: const Icon(Icons.add, color: kCText),
        label: const Text('เพิ่มหมวด', style: TextStyle(color: kCText, fontWeight: FontWeight.w600)),
      ),
      body: list.isEmpty
        ? Center(child: Text('ยังไม่มีหมวด กด "เพิ่มหมวด"', style: TextStyle(color: kCText.withValues(alpha: .4))))
        : ReorderableListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            onReorder: (from, to) {
              setState(() {
                if (to > from) to--;
                list.insert(to, list.removeAt(from));
              });
              Categories.save();
            },
            children: [
              for (var i = 0; i < list.length; i++)
                Container(
                  key: ValueKey(list[i]),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: kCSurf,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kCText.withValues(alpha: .08)),
                  ),
                  child: ListTile(
                    onTap: () => _rename(i),
                    leading: Icon(Icons.folder_outlined, color: kCText.withValues(alpha: .5)),
                    title: Text(list[i], style: const TextStyle(fontSize: 15, color: kCText, fontWeight: FontWeight.w600)),
                    subtitle: Text('${_count(list[i])} งาน · แตะเพื่อแก้ชื่อ',
                      style: TextStyle(fontSize: 12, color: kCText.withValues(alpha: .4))),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        onPressed: () => _delete(i),
                        icon: Icon(Icons.delete_outline_rounded, color: kCRed.withValues(alpha: .7)),
                      ),
                      ReorderableDragStartListener(
                        index: i,
                        child: Icon(Icons.drag_handle_rounded, color: kCText.withValues(alpha: .35)),
                      ),
                    ]),
                  ),
                ),
            ],
          ),
    );
  }
}
