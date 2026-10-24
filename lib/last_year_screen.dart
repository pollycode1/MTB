import 'package:flutter/material.dart';
import 'models.dart';

// งานของเดือนใดเดือนหนึ่ง (ค่าเริ่มต้น = เดือนนี้ของปีที่แล้ว) · ดูจากวันที่สร้าง เสร็จ หรือกำหนดส่ง
List<TaskItem> tasksInMonth(List<TaskItem> tasks, int year, int month) {
  bool inMonth(DateTime? d) => d != null && d.year == year && d.month == month;
  return tasks.where((t) => (t.type == 'task' || t.type == 'idea') &&
      (inMonth(t.createdAt) || inMonth(t.doneAt) || inMonth(t.deadline) || inMonth(t.plannedFor))).toList()
    ..sort((a, b) => (a.doneAt ?? a.deadline ?? a.createdAt).compareTo(b.doneAt ?? b.deadline ?? b.createdAt));
}

// คัดลอกงานเก่าเป็นงานใหม่ของวันนี้: เก็บชื่อ หมายเหตุ หมวด แท็ก ความสำคัญ ขั้นต่อไป ขั้นตอนย่อย (รีเซ็ตติ๊ก)
// กำหนดส่งเลื่อนไป 1 ปี ถ้ายังไม่เลยมา · ไม่คัดลอกไฟล์แนบ
TaskItem copyAsNew(TaskItem old, {DateTime? now}) {
  final n = now ?? DateTime.now();
  SubTask fresh(SubTask s) => SubTask(title: s.title, note: s.note, children: s.children.map(fresh).toList());
  final d = old.deadline;
  final nextDeadline = d == null ? null : DateTime(d.year + 1, d.month, d.day, d.hour, d.minute);
  return TaskItem(
    title: old.title,
    meta: old.meta,
    area: old.area,
    tags: [...old.tags],
    priority: old.priority,
    nextAction: old.nextAction,
    subTasks: old.subTasks.map(fresh).toList(),
    deadline: (nextDeadline != null && nextDeadline.isAfter(n)) ? nextDeadline : null,
    plannedFor: DateTime(n.year, n.month, n.day),
    lastUpdatedAt: n,
    createdAt: n,
  );
}

class LastYearScreen extends StatefulWidget {
  final List<TaskItem> tasks;
  final void Function(List<TaskItem> newTasks) onAdd;
  const LastYearScreen({super.key, required this.tasks, required this.onAdd});
  @override
  State<LastYearScreen> createState() => _LastYearScreenState();
}

class _LastYearScreenState extends State<LastYearScreen> {
  static const _months = ['มกราคม','กุมภาพันธ์','มีนาคม','เมษายน','พฤษภาคม','มิถุนายน','กรกฎาคม','สิงหาคม','กันยายน','ตุลาคม','พฤศจิกายน','ธันวาคม'];
  late DateTime _month = DateTime(DateTime.now().year - 1, DateTime.now().month);
  final _picked = <TaskItem>{};

  void _shift(int m) => setState(() { _month = DateTime(_month.year, _month.month + m); _picked.clear(); });

  @override
  Widget build(BuildContext context) {
    final list = tasksInMonth(widget.tasks, _month.year, _month.month);
    final n = DateTime.now();
    final isLastYear = _month.year == n.year - 1 && _month.month == n.month;
    return Scaffold(
      backgroundColor: kCBg,
      appBar: AppBar(
        backgroundColor: kCBg, elevation: 0,
        title: const Text('งานเดือนเดียวกันปีที่แล้ว', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCText)),
      ),
      bottomNavigationBar: _picked.isEmpty ? null : SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: kCGreen, padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: () {
            widget.onAdd(_picked.map((t) => copyAsNew(t)).toList());
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เพิ่มเป็นงานใหม่ของวันนี้ ${_picked.length} งาน')));
            Navigator.pop(context);
          },
          icon: const Icon(Icons.add_task_rounded, color: Colors.white),
          label: Text('เพิ่มเป็นงานใหม่ (${_picked.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      )),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded, color: kCText)),
            Expanded(child: Column(children: [
              Text('${_months[_month.month - 1]} ${_month.year + 543}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCText)),
              if (!isLastYear)
                GestureDetector(
                  onTap: () => setState(() { _month = DateTime(n.year - 1, n.month); _picked.clear(); }),
                  child: const Padding(padding: EdgeInsets.only(top: 2),
                    child: Text('กลับไปเดือนนี้ปีที่แล้ว', style: TextStyle(fontSize: 11.5, color: kCGoldDark, fontWeight: FontWeight.w600))),
                ),
            ])),
            IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right_rounded, color: kCText)),
          ]),
        ),
        Expanded(child: list.isEmpty
          ? Center(child: Text('ไม่มีงานในเดือนนี้', style: TextStyle(color: kCText.withValues(alpha: .4))))
          : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text('${list.length} งาน · เลือกงานที่จะทำอีกครั้ง', style: TextStyle(fontSize: 11.5, color: kCText.withValues(alpha: .45))),
              ),
              for (final t in list) _row(t),
            ])),
      ]),
    );
  }

  Widget _row(TaskItem t) {
    final on = _picked.contains(t);
    final d = t.doneAt ?? t.deadline;
    final info = [
      if (t.done) 'เสร็จ ${t.doneAt!.day}/${t.doneAt!.month}' else if (d != null) 'กำหนด ${d.day}/${d.month}',
      if (t.type == 'idea') 'ไอเดีย',
      if (t.area != null) t.area!,
      ...t.tags.map((x) => '#$x'),
      if (t.subTasks.isNotEmpty) '${countSteps(t.subTasks)} ขั้นตอน',
    ].join(' · ');
    return GestureDetector(
      onTap: () => setState(() { if (!_picked.remove(t)) _picked.add(t); }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
        decoration: BoxDecoration(
          color: kCSurf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: on ? kCGreen.withValues(alpha: .6) : kCText.withValues(alpha: .08)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(on ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              size: 22, color: on ? kCGreen : kCText.withValues(alpha: .4)),
          ),
          Expanded(child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.title, style: const TextStyle(fontSize: 14.5, height: 1.35, fontWeight: FontWeight.w600, color: kCText)),
              if (info.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(info, style: TextStyle(fontSize: 11.5, color: kCText.withValues(alpha: .5))),
              ],
            ]),
          )),
        ]),
      ),
    );
  }
}
