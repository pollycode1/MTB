import 'package:flutter/material.dart';
import 'models.dart';

// ผลค้นหา 1 งาน + ทุกจุดที่พบคำค้น
class SearchHit {
  final TaskItem task;
  final List<String> where; // เช่น "แท็ก: ด่วน", "ขั้นตอน: ตรวจห้อง 3/2 › กรอกคะแนน"
  SearchHit(this.task, this.where);
}

// ค้นทุกอย่างในงาน: ชื่อ หมายเหตุ แท็ก หมวด ขั้นต่อไป และขั้นตอนย่อยทุกชั้น (ชื่อ + หมายเหตุ)
List<SearchHit> searchTasks(List<TaskItem> tasks, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return [];
  bool has(String? s) => s != null && s.toLowerCase().contains(q);
  final hits = <SearchHit>[];
  for (final t in tasks) {
    final where = <String>[
      if (has(t.title)) 'ชื่องาน',
      if (has(t.meta)) 'หมายเหตุ: ${t.meta}',
      if (t.tags.any(has)) 'แท็ก: ${t.tags.where(has).join(', ')}',
      if (has(t.area)) 'หมวด: ${t.area}',
      if (has(t.nextAction)) 'ขั้นต่อไป: ${t.nextAction}',
    ];
    void walk(List<SubTask> steps, List<String> path) {
      for (final s in steps) {
        final p = [...path, s.title];
        if (has(s.title)) where.add('ขั้นตอน: ${p.join(' › ')}');
        if (has(s.note)) where.add('หมายเหตุขั้นตอน: ${p.join(' › ')} — ${s.note}');
        walk(s.children, p);
      }
    }
    walk(t.subTasks, []);
    if (where.isNotEmpty) hits.add(SearchHit(t, where));
  }
  // งานที่ยังไม่เสร็จก่อน · ตรงชื่องานก่อน
  int rank(SearchHit h) => (h.task.done || h.task.archivedAt != null ? 2 : 0) + (h.where.first == 'ชื่องาน' ? 0 : 1);
  hits.sort((a, b) => rank(a).compareTo(rank(b)));
  return hits;
}

String statusLabel(TaskItem t) {
  if (t.archivedAt != null) return 'เก็บถาวร';
  return switch (t.type) {
    'inbox'   => 'รอคัดแยก',
    'idea'    => 'ไอเดีย',
    'waiting' => 'รอคนอื่น',
    _         => t.done ? 'เสร็จแล้ว' : 'งาน',
  };
}

class SearchScreen extends StatefulWidget {
  final List<TaskItem> tasks;
  final Future<void> Function(TaskItem) onOpen; // เปิดหน้ารายละเอียด (รอจนปิดแล้วค่อยค้นใหม่)
  const SearchScreen({super.key, required this.tasks, required this.onOpen});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final hits = searchTasks(widget.tasks, _ctrl.text);
    return Scaffold(
      backgroundColor: kCBg,
      body: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 8, 16, 8),
          child: Row(children: [
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, color: kCText)),
            Expanded(child: TextField(
              controller: _ctrl, autofocus: true,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 15, color: kCText),
              decoration: InputDecoration(
                hintText: 'ค้นหางาน แท็ก หมวด ขั้นตอน หมายเหตุ…',
                hintStyle: TextStyle(color: kCText.withValues(alpha: .35), fontSize: 14),
                filled: true, fillColor: kCSurf, isDense: true,
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: kCText.withValues(alpha: .45)),
                suffixIcon: _ctrl.text.isEmpty ? null : IconButton(
                  onPressed: () => setState(_ctrl.clear),
                  icon: Icon(Icons.close_rounded, size: 18, color: kCText.withValues(alpha: .45)),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            )),
          ]),
        ),
        Expanded(child: _ctrl.text.trim().isEmpty
          ? Center(child: Text('พิมพ์คำที่ต้องการค้นหา', style: TextStyle(color: kCText.withValues(alpha: .35))))
          : hits.isEmpty
            ? Center(child: Text('ไม่พบ "${_ctrl.text.trim()}"', style: TextStyle(color: kCText.withValues(alpha: .4))))
            : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 10),
                  child: Text('พบ ${hits.length} งาน', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: kCText.withValues(alpha: .4))),
                ),
                for (final h in hits) _hitCard(h),
              ])),
      ]),
    );
  }

  Widget _hitCard(SearchHit h) {
    final t = h.task;
    final faded = t.done || t.archivedAt != null;
    final details = h.where.where((w) => w != 'ชื่องาน').toList();
    return GestureDetector(
      onTap: () async { await widget.onOpen(t); if (mounted) setState(() {}); },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: kCSurf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kCText.withValues(alpha: .08)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(t.title, style: TextStyle(fontSize: 14.5, height: 1.35, fontWeight: FontWeight.w600,
              color: faded ? kCText.withValues(alpha: .5) : kCText,
              decoration: t.done ? TextDecoration.lineThrough : null,
              decorationColor: kCText.withValues(alpha: .4)))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: kCText.withValues(alpha: .07), borderRadius: BorderRadius.circular(999)),
              child: Text(statusLabel(t), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: kCText.withValues(alpha: .6))),
            ),
          ]),
          if (t.area != null || t.tags.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text([if (t.area != null) t.area!, ...t.tags.map((x) => '#$x')].join(' · '),
              style: const TextStyle(fontSize: 11.5, color: kCGreenDk)),
          ],
          for (final w in details.take(4))
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text('พบใน $w', maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, height: 1.35, color: kCText.withValues(alpha: .55))),
            ),
          if (details.length > 4)
            Padding(padding: const EdgeInsets.only(top: 4),
              child: Text('และอีก ${details.length - 4} จุด', style: TextStyle(fontSize: 11.5, color: kCText.withValues(alpha: .4)))),
        ]),
      ),
    );
  }
}
