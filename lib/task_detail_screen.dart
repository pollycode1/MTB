import 'package:flutter/material.dart';
import 'models.dart';

class TaskDetailScreen extends StatefulWidget {
  final TaskItem task;
  final VoidCallback onDelete;
  const TaskDetailScreen({super.key, required this.task, required this.onDelete});
  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _metaCtrl;
  late final TextEditingController _tagCtrl;
  late final TextEditingController _budgetCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl  = TextEditingController(text: widget.task.title);
    _metaCtrl   = TextEditingController(text: widget.task.meta);
    _tagCtrl    = TextEditingController(text: widget.task.tag ?? '');
    _budgetCtrl = TextEditingController(text: widget.task.budget?.toString() ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _metaCtrl.dispose();
    _tagCtrl.dispose(); _budgetCtrl.dispose();
    super.dispose();
  }

  void _save() {
    widget.task.title  = _titleCtrl.text.trim().isEmpty ? widget.task.title : _titleCtrl.text.trim();
    widget.task.meta   = _metaCtrl.text.trim();
    final tag = _tagCtrl.text.trim();
    widget.task.tag    = tag.isEmpty ? null : tag;
    widget.task.tagBg  = tag.isEmpty ? null : const Color(0x33D8A93F);
    widget.task.tagColor = tag.isEmpty ? null : kCGoldDark;
    widget.task.budget = int.tryParse(_budgetCtrl.text.trim());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    return Scaffold(
      backgroundColor: kCBg,
      body: Column(children: [
        _buildHeader(context, t),
        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), children: [
          _field('ชื่องาน', _titleCtrl, onDone: _save, maxLines: 2),
          const SizedBox(height: 12),
          _field('หมายเหตุ / กำหนดส่ง', _metaCtrl, onDone: _save),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _field('แท็ก', _tagCtrl, hint: 'เช่น สอน, ส่วนตัว', onDone: _save)),
            const SizedBox(width: 10),
            Expanded(child: _field('งบ (฿)', _budgetCtrl, hint: '500', keyboardType: TextInputType.number, onDone: _save)),
          ]),
          const SizedBox(height: 28),
          _sectionLabel('ขั้นตอนย่อย'),
          const SizedBox(height: 10),
          ...t.subTasks.map((s) => _SubTaskTile(
            sub: s, depth: 0,
            onChanged: () => setState(() {}),
            onDelete: () => setState(() => t.subTasks.remove(s)),
          )),
          _addSubTaskButton('+ เพิ่มขั้นตอน', () => setState(() => t.subTasks.add(SubTask(title: 'ขั้นตอนใหม่')))),
        ])),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context, TaskItem t) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 16, 16, 14),
      decoration: BoxDecoration(
        color: kCSurf,
        border: Border(bottom: BorderSide(color: kCText.withValues(alpha: .09))),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () { _save(); Navigator.pop(context); },
          child: Container(width: 34, height: 34,
            decoration: BoxDecoration(color: kCText.withValues(alpha: .07), borderRadius: BorderRadius.circular(12)),
            child: const Center(child: Text('‹', style: TextStyle(fontSize: 20, color: kCText)))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(t.done ? 'งานที่เสร็จแล้ว' : 'รายละเอียดงาน',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCText))),
        GestureDetector(
          onTap: () { widget.onDelete(); Navigator.pop(context); },
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: kCRed.withValues(alpha: .1), borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kCRed.withValues(alpha: .3))),
            child: const Text('ลบ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kCRed))),
        ),
      ]),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {
    String? hint, int maxLines = 1, TextInputType keyboardType = TextInputType.text, VoidCallback? onDone,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: kCText.withValues(alpha: .45))),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.done,
        onEditingComplete: onDone,
        style: const TextStyle(fontSize: 15, color: kCText, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: kCText.withValues(alpha: .3), fontSize: 14),
          filled: true, fillColor: kCSurf,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kCText.withValues(alpha: .1))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kCGoldDark, width: 1.5)),
        ),
      ),
    ]);
  }

  Widget _sectionLabel(String text) =>
    Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: kCText.withValues(alpha: .38)));

  Widget _addSubTaskButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: kCGold.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kCGoldDark.withValues(alpha: .25), style: BorderStyle.solid),
        ),
        child: Row(children: [
          const Icon(Icons.add, size: 16, color: kCGoldDark),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13, color: kCGoldDark, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ── Recursive sub-task tile ───────────────────────────────────────────────────
class _SubTaskTile extends StatefulWidget {
  final SubTask sub;
  final int depth;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  const _SubTaskTile({required this.sub, required this.depth, required this.onChanged, required this.onDelete});
  @override
  State<_SubTaskTile> createState() => _SubTaskTileState();
}

class _SubTaskTileState extends State<_SubTaskTile> {
  bool _expanded = true;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.sub.title);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = widget.sub;
    final indent = widget.depth * 20.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        margin: EdgeInsets.only(left: indent, bottom: 7),
        padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
        decoration: BoxDecoration(
          color: kCSurf,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kCText.withValues(alpha: .09)),
        ),
        child: Row(children: [
          // checkbox
          GestureDetector(
            onTap: () { setState(() { s.done = !s.done; }); widget.onChanged(); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: s.done ? kCGreen : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: s.done ? kCGreen : kCText.withValues(alpha: .4), width: 1.6),
              ),
              child: s.done ? const Icon(Icons.check, size: 12, color: kCSurf) : null,
            ),
          ),
          const SizedBox(width: 10),
          // title
          Expanded(child: TextField(
            controller: _ctrl,
            onChanged: (v) { s.title = v; widget.onChanged(); },
            style: TextStyle(fontSize: 13.5, color: s.done ? kCText.withValues(alpha: .4) : kCText,
              decoration: s.done ? TextDecoration.lineThrough : null,
              decorationColor: kCText.withValues(alpha: .4), fontWeight: FontWeight.w500),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
          )),
          // add child
          GestureDetector(
            onTap: () { setState(() { s.children.add(SubTask(title: 'ย่อย')); _expanded = true; }); widget.onChanged(); },
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.subdirectory_arrow_right, size: 16, color: kCText.withValues(alpha: .3))),
          ),
          // toggle expand
          if (s.children.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 16, color: kCText.withValues(alpha: .3))),
            ),
          // delete
          GestureDetector(
            onTap: widget.onDelete,
            child: Padding(padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.close, size: 15, color: kCText.withValues(alpha: .28))),
          ),
        ]),
      ),
      if (_expanded)
        ...s.children.map((child) => _SubTaskTile(
          sub: child, depth: widget.depth + 1,
          onChanged: widget.onChanged,
          onDelete: () { setState(() => s.children.remove(child)); widget.onChanged(); },
        )),
    ]);
  }
}
