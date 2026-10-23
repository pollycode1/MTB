import 'package:flutter/material.dart';
import 'models.dart';
import 'notification_service.dart';

class TaskDetailScreen extends StatefulWidget {
  final TaskItem task;
  final int taskIndex;
  final VoidCallback onDelete;
  final VoidCallback? onChanged;
  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.taskIndex,
    required this.onDelete,
    this.onChanged,
  });
  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _metaCtrl;
  late final TextEditingController _tagCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.task.title);
    _metaCtrl  = TextEditingController(text: widget.task.meta);
    _tagCtrl   = TextEditingController(text: widget.task.tag ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _metaCtrl.dispose(); _tagCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final t = widget.task;
    t.title    = _titleCtrl.text.trim().isEmpty ? t.title : _titleCtrl.text.trim();
    t.meta     = _metaCtrl.text.trim();
    final tag  = _tagCtrl.text.trim();
    t.tag      = tag.isEmpty ? null : tag;
    t.tagBg    = tag.isEmpty ? null : const Color(0x33D8A93F);
    t.tagColor = tag.isEmpty ? null : kCGoldDark;
    t.lastUpdatedAt = DateTime.now();
    NotificationService.cancel(widget.task.id);
    NotificationService.scheduleDeadline(widget.task.id, t);
    widget.onChanged?.call();
    setState(() {});
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.task.deadline ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: kCGreen, onPrimary: Colors.white,
            surface: kCSurf, onSurface: kCText,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    // ask for time too
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(widget.task.deadline ?? DateTime(now.year, now.month, now.day, 9)),
    );
    setState(() {
      widget.task.deadline = DateTime(
        picked.year, picked.month, picked.day,
        time?.hour ?? 9, time?.minute ?? 0,
      );
    });
    NotificationService.cancel(widget.task.id);
    NotificationService.scheduleDeadline(widget.task.id, widget.task);
    widget.onChanged?.call();
  }

  void _clearDeadline() {
    setState(() => widget.task.deadline = null);
    NotificationService.cancel(widget.task.id);
    widget.onChanged?.call();
  }

  void _setRecurrence(String? val) {
    setState(() => widget.task.recurrence = val);
    widget.onChanged?.call();
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
          _field('แท็ก', _tagCtrl, hint: 'เช่น สอน, ส่วนตัว', onDone: _save),
          const SizedBox(height: 16),
          _sectionLabel('ความสำคัญ'),
          const SizedBox(height: 8),
          _priorityRow(),
          const SizedBox(height: 20),
          _sectionLabel('กำหนดส่ง & การแจ้งเตือน'),
          const SizedBox(height: 10),
          _deadlineRow(),
          const SizedBox(height: 10),
          _recurrenceRow(),
          const SizedBox(height: 28),
          _sectionLabel('ขั้นตอนย่อย'),
          const SizedBox(height: 10),
          ...t.subTasks.map((s) => SubTaskTile(
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
        keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
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

  Widget _priorityRow() {
    const labels = ['สูง', 'กลาง', 'ต่ำ'];
    const colors = [kCRed, kCGoldDark, kCGreen];
    return Row(children: List.generate(3, (idx) {
      final p = idx + 1;
      final active = widget.task.priority == p;
      return Expanded(child: GestureDetector(
        onTap: () { setState(() => widget.task.priority = p); _save(); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: EdgeInsets.only(right: idx < 2 ? 8 : 0),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? colors[idx].withValues(alpha: .15) : kCSurf,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? colors[idx].withValues(alpha: .6) : kCText.withValues(alpha: .1)),
          ),
          child: Center(child: Text(labels[idx], style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: active ? colors[idx] : kCText.withValues(alpha: .4)))),
        ),
      ));
    }));
  }

  Widget _deadlineRow() {
    final d = widget.task.deadline;
    final now = DateTime.now();
    final isOverdue = d != null && d.isBefore(now) && !widget.task.done;
    return GestureDetector(
      onTap: _pickDeadline,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isOverdue ? kCRed.withValues(alpha: .07) : kCSurf,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isOverdue ? kCRed.withValues(alpha: .3) : kCText.withValues(alpha: .1)),
        ),
        child: Row(children: [
          Icon(Icons.alarm_rounded, size: 18,
            color: isOverdue ? kCRed : d != null ? kCGreen : kCText.withValues(alpha: .4)),
          const SizedBox(width: 10),
          Expanded(child: d == null
            ? Text('ตั้งกำหนดส่ง', style: TextStyle(fontSize: 14, color: kCText.withValues(alpha: .4)))
            : Text(_fmtDeadline(d), style: TextStyle(fontSize: 14,
                color: isOverdue ? kCRed : kCText, fontWeight: FontWeight.w600))),
          if (d != null) GestureDetector(
            onTap: _clearDeadline,
            child: Icon(Icons.close, size: 16, color: kCText.withValues(alpha: .3)),
          ),
        ]),
      ),
    );
  }

  Widget _recurrenceRow() {
    final options = <(String, String?)>[
      ('ไม่ซ้ำ', null),
      ('ทุกวัน', 'daily'),
      ('ทุกสัปดาห์', 'weekly'),
      ('ทุกเดือน', 'monthly'),
      ('ทุกปี', 'yearly'),
    ];
    return Wrap(spacing: 8, runSpacing: 6, children: options.map((opt) {
      final label = opt.$1;
      final val   = opt.$2;
      final active = widget.task.recurrence == val;
      return GestureDetector(
        onTap: () => _setRecurrence(val),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? kCGreen : kCSurf,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? kCGreen : kCText.withValues(alpha: .12)),
          ),
          child: Text(label, style: TextStyle(
            fontSize: 12.5, fontWeight: FontWeight.w600,
            color: active ? Colors.white : kCText.withValues(alpha: .6))),
        ),
      );
    }).toList());
  }

  String _fmtDeadline(DateTime d) {
    final now = DateTime.now();
    final diff = d.difference(DateTime(now.year, now.month, now.day)).inDays;
    final timeStr = '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    final months = ['ม.ค.','ก.พ.','มี.ค.','เม.ย.','พ.ค.','มิ.ย.','ก.ค.','ส.ค.','ก.ย.','ต.ค.','พ.ย.','ธ.ค.'];
    if (diff == 0) return 'วันนี้ $timeStr น.';
    if (diff == 1) return 'พรุ่งนี้ $timeStr น.';
    if (diff < 0) return 'เกินกำหนด ${d.day} ${months[d.month-1]}';
    return '${d.day} ${months[d.month-1]} ${d.year + 543} · $timeStr น.';
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
class SubTaskTile extends StatefulWidget {
  final SubTask sub;
  final int depth;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  const SubTaskTile({super.key, required this.sub, required this.depth, required this.onChanged, required this.onDelete});
  @override
  State<SubTaskTile> createState() => SubTaskTileState();
}

class SubTaskTileState extends State<SubTaskTile> {
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
        ...s.children.map((child) => SubTaskTile(
          sub: child, depth: widget.depth + 1,
          onChanged: widget.onChanged,
          onDelete: () { setState(() => s.children.remove(child)); widget.onChanged(); },
        )),
    ]);
  }
}
