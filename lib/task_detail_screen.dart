import 'package:flutter/material.dart';
import 'categories.dart';
import 'models.dart';
import 'dart:io';
import 'attachments.dart';
import 'schedule_data.dart';
import 'step_detail_screen.dart';
import 'tags.dart';
import 'notification_service.dart';

class TaskDetailScreen extends StatefulWidget {
  final TaskItem task;
  final int taskIndex;
  final VoidCallback onDelete;
  final VoidCallback? onChanged;
  final List<TaskItem> allTasks; // ใช้ดูว่าแท็กถูกใช้ในงานไหนบ้างก่อนลบ
  const TaskDetailScreen({
    this.allTasks = const [],
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
  bool _aiBusy = false;
  bool _deleted = false; // ลบแล้วไม่ต้องบันทึก/ตั้งแจ้งเตือนตอนปิดหน้า

  static const _priorities = {1: 'สูง', 2: 'กลาง', 3: 'ต่ำ'};
  static const _priorityColors = {1: kCRed, 2: kCGoldDark, 3: kCGreen};
  static const _recurrences = {'': 'ไม่ซ้ำ', 'daily': 'ทุกวัน', 'weekly': 'ทุกสัปดาห์', 'monthly': 'ทุกเดือน', 'yearly': 'ทุกปี'};

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.task.title);
    _metaCtrl  = TextEditingController(text: widget.task.meta);
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _metaCtrl.dispose();
    super.dispose();
  }

  void _changed() {
    widget.task.lastUpdatedAt = DateTime.now();
    widget.onChanged?.call();
    setState(() {});
  }

  void _save() {
    final t = widget.task;
    t.title = _titleCtrl.text.trim().isEmpty ? t.title : _titleCtrl.text.trim();
    t.meta  = _metaCtrl.text.trim();
    NotificationService.cancel(t.id);
    NotificationService.scheduleDeadline(t.id, t);
    _changed();
  }

  // ติด/เอาแท็กออกจากงานนี้ (งานหนึ่งมีได้หลายแท็ก)
  void _toggleTag(String tag) {
    final tags = widget.task.tags;
    if (!tags.remove(tag)) tags.add(tag);
    _changed();
  }

  Future<void> _newTag() async {
    final ctrl = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCSurf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('แท็กใหม่', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCText)),
        content: TextField(
          controller: ctrl, autofocus: true,
          style: const TextStyle(color: kCText),
          decoration: InputDecoration(hintText: 'เช่น ตรวจงาน', hintStyle: TextStyle(color: kCText.withValues(alpha: .3))),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('ยกเลิก', style: TextStyle(color: kCText.withValues(alpha: .5)))),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('เพิ่ม', style: TextStyle(color: kCGreenDk, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (tag != null && tag.isNotEmpty) {
      Tags.add(tag);
      if (!widget.task.tags.contains(tag)) _toggleTag(tag);
    }
  }

  // เลือกวันและเวลาลงตาราง: แสดงเฉพาะเวลาที่ว่าง (ไม่ชนคาบสอน งานพิเศษ หรืองานอื่น · วันหยุดว่างทั้งวัน)
  Future<void> _pickSlot() async {
    final t = widget.task;
    const dayShort = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];
    final today = dateOnly(DateTime.now());
    var day = t.slotStart != null ? dateOnly(t.slotStart!) : today;
    var dur = t.slotStart != null ? t.slotMin : 60;
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final hol = Holidays.nameOn(day);
        final starts = freeStarts(busyOn(day, widget.allTasks, ScheduleStore.blocks, holiday: hol != null, ignore: t), dur);
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .8),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: const BoxDecoration(color: kCSurf, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ลงเวลาในตาราง', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCText)),
            const SizedBox(height: 10),
            SizedBox(height: 58, child: ListView(scrollDirection: Axis.horizontal, children: [
              for (var i = 0; i < 21; i++)
                Builder(builder: (_) {
                  final d = today.add(Duration(days: i));
                  final sel = sameDay(d, day);
                  final h = Holidays.nameOn(d) != null;
                  return GestureDetector(
                    onTap: () => setS(() => day = d),
                    child: Container(
                      width: 46, margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: sel ? kCGreen.withValues(alpha: .3) : kCBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: sel ? kCGreen : kCText.withValues(alpha: .1)),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(dayShort[d.weekday - 1], style: TextStyle(fontSize: 11, color: h ? kCRed : kCText.withValues(alpha: .55))),
                        Text('${d.day}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: h ? kCRed : kCText)),
                      ]),
                    ),
                  );
                }),
            ])),
            if (hol != null) Padding(padding: const EdgeInsets.only(top: 6),
              child: Text('🎌 $hol · ว่างทั้งวัน', style: const TextStyle(fontSize: 12, color: kCRed))),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              for (final m in const [30, 60, 90, 120, 180])
                ChoiceChip(
                  label: Text(m < 60 ? '$m นาที' : m % 60 == 0 ? '${m ~/ 60} ชม.' : '1.5 ชม.'),
                  selected: dur == m, onSelected: (_) => setS(() => dur = m),
                  selectedColor: kCGreen.withValues(alpha: .3), backgroundColor: kCBg,
                  labelStyle: TextStyle(fontSize: 12.5, color: dur == m ? kCGreenDk : kCText.withValues(alpha: .7)),
                ),
            ]),
            const SizedBox(height: 12),
            Text(starts.isEmpty ? 'วันนี้ไม่มีช่วงว่างพอ ลองวันอื่นหรือลดเวลา' : 'เวลาว่าง (${starts.length} ช่วง)',
              style: TextStyle(fontSize: 12, color: kCText.withValues(alpha: .5))),
            const SizedBox(height: 8),
            Flexible(child: SingleChildScrollView(child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in starts)
                ActionChip(
                  label: Text('${hm(s)}–${hm(s + dur)}'),
                  onPressed: () => Navigator.pop(ctx, s),
                  backgroundColor: kCBg,
                  labelStyle: const TextStyle(fontSize: 13, color: kCText, fontWeight: FontWeight.w600),
                ),
            ]))),
          ]),
        );
      }),
    );
    if (picked == null) return;
    t.slotStart = DateTime(day.year, day.month, day.day, picked ~/ 60, picked % 60);
    t.slotMin = dur;
    t.recurShift = 0; // ผู้ใช้เลือกวันเอง → ไม่ต้องคิดย้อนการเลื่อนหนีวันหยุด
    t.plannedFor = day;
    _changed();
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
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(widget.task.deadline ?? DateTime(now.year, now.month, now.day, 9)),
    );
    final old = widget.task.deadline;
    final next = DateTime(picked.year, picked.month, picked.day, time?.hour ?? 9, time?.minute ?? 0);
    if (old != null && next.isAfter(old)) widget.task.postponeCount++; // เลื่อนกำหนด = เลื่อน 1 ครั้ง
    widget.task.deadline = next;
    widget.task.recurShift = 0;
    NotificationService.cancel(widget.task.id);
    NotificationService.scheduleDeadline(widget.task.id, widget.task);
    _changed();
  }

  void _clearDeadline() {
    widget.task.deadline = null;
    NotificationService.cancel(widget.task.id);
    _changed();
  }

  // สลับงาน ↔ ไอเดีย แล้วกลับหน้าหลัก (ข้อมูลอื่นของงานยังอยู่ครบ)
  void _moveType(String to) {
    final t = widget.task;
    final n = DateTime.now();
    t.type = to;
    t.done = false;
    t.isFrog = false;
    t.lastUpdatedAt = n;
    if (to == 'idea') {
      t.plannedFor = null;
      t.reviewCount = 0;
      NotificationService.cancel(t.id); // ไอเดียไม่ต้องเตือนกำหนดส่ง
    } else {
      t.plannedFor = DateTime(n.year, n.month, n.day);
    }
    _save(); // _save ตั้งแจ้งเตือนกำหนดส่งใหม่ให้ (เฉพาะงาน)
    if (to == 'idea') NotificationService.cancel(t.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(to == 'idea' ? 'ย้ายไปแท็บไอเดียแล้ว' : 'ย้ายเป็นงานของวันนี้แล้ว')));
    _deleted = true; // ไม่ต้องบันทึกซ้ำตอนปิดหน้า
    Navigator.pop(context);
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCSurf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('ลบงานนี้?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCText)),
        content: Text(widget.task.title, style: TextStyle(fontSize: 13.5, color: kCText.withValues(alpha: .6))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text('ยกเลิก', style: TextStyle(color: kCText.withValues(alpha: .5)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ', style: TextStyle(color: kCRed, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true && mounted) {
      _deleted = true;
      Attachments.deleteTask(widget.task.id); // ลบไฟล์แนบของงานนี้ทั้งโฟลเดอร์
      widget.onDelete();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final now = DateTime.now();
    final overdue = t.deadline != null && t.deadline!.isBefore(now) && !t.done;
    return PopScope(
      onPopInvokedWithResult: (_, _) { if (!_deleted) _save(); }, // บันทึกชื่อ/หมายเหตุเมื่อย้อนกลับทุกทาง
      child: Scaffold(
        backgroundColor: kCBg,
        body: Column(children: [
          _buildHeader(context, t),
          Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
            // ชื่อ + หมายเหตุ แบบไม่มีกรอบ อ่านเหมือนโน้ต
            _plainField(_titleCtrl, 'ชื่องาน', size: 21, weight: FontWeight.w700, maxLines: 3),
            _plainField(_metaCtrl, 'เพิ่มหมายเหตุ…', size: 14, weight: FontWeight.w400, maxLines: 4, faded: true),
            const SizedBox(height: 20),

            // คุณสมบัติของงาน: ชิปเล็กแถวเดียว (เลื่อนแนวนอนได้) แตะแล้วเลือกจากป๊อปอัป
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _popupPill<String>(
                  icon: Icons.folder_outlined,
                  text: t.area ?? 'หมวด', set: t.area != null,
                  items: {for (final a in Categories.list) a: a, '': 'ไม่ระบุ'},
                  onSelected: (v) { t.area = v.isEmpty ? null : v; _changed(); },
                ),
                _popupPill<int>(
                  icon: Icons.flag_rounded,
                  text: 'สำคัญ${_priorities[t.priority] ?? 'กลาง'}', set: true,
                  color: _priorityColors[t.priority],
                  items: _priorities,
                  onSelected: (v) { t.priority = v; _save(); },
                ),
                _pill(
                  icon: Icons.alarm_rounded,
                  text: t.deadline == null ? 'กำหนดส่ง' : _fmtDeadline(t.deadline!),
                  set: t.deadline != null,
                  color: overdue ? kCRed : null,
                  onTap: _pickDeadline,
                  onClear: t.deadline == null ? null : _clearDeadline,
                ),
                if (t.type == 'task')
                  _pill(
                    icon: Icons.schedule_rounded,
                    text: t.slotStart == null ? 'ลงเวลา' : '${t.slotStart!.day}/${t.slotStart!.month} ${hm(minOfDay(t.slotStart!))}–${hm(minOfDay(t.slotStart!) + t.slotMin)}',
                    set: t.slotStart != null,
                    onTap: _pickSlot,
                    onClear: t.slotStart == null ? null : () { t.slotStart = null; _changed(); },
                  ),
                _popupPill<String>(
                  icon: Icons.repeat_rounded,
                  text: _recurrences[t.recurrence ?? ''] ?? 'ไม่ซ้ำ', set: t.recurrence != null,
                  items: _recurrences,
                  onSelected: (v) { t.recurrence = v.isEmpty ? null : v; _changed(); },
                ),
              ]),
            ),

            _section('แท็ก', _tagRow()),
            _section('ไฟล์แนบ', _attachmentsRow()),
            _section('ขั้นตอนย่อย', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final s in t.subTasks)
                StepTile(
                  key: ObjectKey(s),
                  task: t, step: s, siblings: t.subTasks,
                  onChanged: () { if (mounted) _changed(); },
                ),
              Row(children: [
                stepAddButton('เพิ่มขั้นตอน', () { setState(() => t.subTasks.add(SubTask(title: 'ขั้นตอนใหม่'))); _changed(); }),
                const SizedBox(width: 18),
                stepAddButton(_aiBusy ? 'AI กำลังแตกงาน…' : '✨ ให้ AI แตกขั้นตอน', _aiBusy ? () {} : () {
                  // ใช้ชื่อ/หมายเหตุที่พิมพ์อยู่ล่าสุด แม้ยังไม่ได้กดบันทึก
                  t.title = _titleCtrl.text.trim().isEmpty ? t.title : _titleCtrl.text.trim();
                  t.meta  = _metaCtrl.text.trim();
                  aiSplitFlow(context, task: t,
                    setBusy: (v) { if (mounted) setState(() => _aiBusy = v); },
                    onAdded: () { if (mounted) _changed(); });
                }),
              ]),
            ])),
          ])),
        ]),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, TaskItem t) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 8, 8, 4),
      child: Row(children: [
        IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: kCText),
        ),
        Expanded(child: Text(t.type == 'idea' ? 'ไอเดีย' : t.done ? 'งานที่เสร็จแล้ว' : 'รายละเอียดงาน',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kCText.withValues(alpha: .6)))),
        if (t.type == 'task' || t.type == 'idea')
          TextButton.icon(
            onPressed: () => _moveType(t.type == 'task' ? 'idea' : 'task'),
            icon: Icon(t.type == 'task' ? Icons.lightbulb_outline_rounded : Icons.task_alt_rounded,
              size: 17, color: kCText.withValues(alpha: .6)),
            label: Text(t.type == 'task' ? 'ย้ายไปไอเดีย' : 'ย้ายเป็นงาน',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCText.withValues(alpha: .7))),
          ),
        IconButton(
          onPressed: _confirmDelete,
          icon: Icon(Icons.delete_outline_rounded, color: kCRed.withValues(alpha: .8)),
        ),
      ]),
    );
  }

  // ชิปคุณสมบัติ: ไอคอน + ค่า (ยังไม่ตั้ง = สีจาง)
  Widget _pillBody(IconData icon, String text, bool set, Color? color, {VoidCallback? onClear}) {
    final fg = color ?? (set ? kCText : kCText.withValues(alpha: .45));
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: EdgeInsets.fromLTRB(11, 7, onClear == null ? 12 : 6, 7),
      decoration: BoxDecoration(
        color: set ? kCSurf : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: (color ?? kCText).withValues(alpha: set ? .25 : .14)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: fg),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: fg)),
        if (onClear != null)
          GestureDetector(
            onTap: onClear,
            child: Padding(padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.close_rounded, size: 14, color: kCText.withValues(alpha: .4))),
          ),
      ]),
    );
  }

  Widget _pill({required IconData icon, required String text, required bool set, Color? color,
      required VoidCallback onTap, VoidCallback? onClear}) =>
    GestureDetector(onTap: onTap, child: _pillBody(icon, text, set, color, onClear: onClear));

  Widget _popupPill<T>({required IconData icon, required String text, required bool set, Color? color,
      required Map<T, String> items, required ValueChanged<T> onSelected}) =>
    PopupMenuButton<T>(
      color: kCSurf,
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final e in items.entries)
          PopupMenuItem<T>(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 14, color: kCText))),
      ],
      child: _pillBody(icon, text, set, color),
    );

  Widget _section(String label, Widget child) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel(label),
      const SizedBox(height: 10),
      child,
    ]),
  );

  Future<void> _addAttachment(String kind) async {
    final t = widget.task;
    try {
      final added = switch (kind) {
        'camera' => [?await Attachments.takePhoto(t.id)],
        'image'  => await Attachments.pick(t.id, images: true),
        _        => await Attachments.pick(t.id),
      };
      if (added.isEmpty) return;
      t.attachments.addAll(added);
      _changed();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('แนบไฟล์ไม่สำเร็จ: $e')));
    }
  }

  Future<void> _removeAttachment(String rel) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCSurf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('ลบไฟล์แนบ?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCText)),
        content: Text(Attachments.displayName(rel), style: TextStyle(fontSize: 13.5, color: kCText.withValues(alpha: .6))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('ยกเลิก', style: TextStyle(color: kCText.withValues(alpha: .5)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ลบ', style: TextStyle(color: kCRed, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true) return;
    widget.task.attachments.remove(rel);
    await Attachments.delete(rel);
    _changed();
  }

  // ไฟล์แนบ: รูปเป็นภาพย่อ ไฟล์อื่นเป็นการ์ดชื่อไฟล์ · แตะ = เปิด · กดค้าง = ลบ
  Widget _attachmentsRow() {
    final files = widget.task.attachments;
    Widget addBtn(IconData icon, String label, String kind) => GestureDetector(
      onTap: () => _addAttachment(kind),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: kCText.withValues(alpha: .18))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: kCText.withValues(alpha: .55)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCText.withValues(alpha: .55))),
        ]),
      ),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (files.isNotEmpty) ...[
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final rel in [...files])
            GestureDetector(
              onTap: () => Attachments.open(rel),
              onLongPress: () => _removeAttachment(rel),
              child: Attachments.isImage(rel)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(Attachments.pathOf(rel)), width: 96, height: 96, fit: BoxFit.cover, cacheWidth: 240,
                      errorBuilder: (_, _, _) => _fileTile(rel)),
                  )
                : _fileTile(rel),
            ),
        ]),
        const SizedBox(height: 6),
        Text('แตะเพื่อเปิด · กดค้างเพื่อลบ', style: TextStyle(fontSize: 11, color: kCText.withValues(alpha: .3))),
        const SizedBox(height: 10),
      ],
      Wrap(spacing: 8, runSpacing: 8, children: [
        addBtn(Icons.photo_camera_outlined, 'ถ่ายรูป', 'camera'),
        addBtn(Icons.image_outlined, 'รูปภาพ', 'image'),
        addBtn(Icons.attach_file_rounded, 'ไฟล์', 'file'),
      ]),
    ]);
  }

  Widget _fileTile(String rel) => Container(
    width: 96, height: 96,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: kCSurf, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: kCText.withValues(alpha: .1))),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.insert_drive_file_outlined, size: 26, color: kCText.withValues(alpha: .5)),
      const SizedBox(height: 6),
      Text(Attachments.displayName(rel), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10.5, color: kCText.withValues(alpha: .7))),
    ]),
  );

  // ลบแท็ก: เลือกได้ว่าเอาออกเฉพาะงานนี้ หรือลบออกจากแอพ (แสดงงานที่จะได้รับผลก่อน)
  Future<void> _deleteTag(String tag) async {
    final t = widget.task;
    final users = widget.allTasks.where((x) => x.tags.contains(tag)).toList();
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCSurf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('ลบแท็ก "$tag"?', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCText)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(users.isEmpty ? 'ยังไม่มีงานไหนใช้แท็กนี้' : 'ถ้าลบออกจากแอพ งาน ${users.length} รายการนี้จะไม่มีแท็กนี้อีก:',
            style: TextStyle(fontSize: 13.5, color: kCText.withValues(alpha: .65))),
          if (users.isNotEmpty) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final u in users)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text('• ${u.title}${identical(u, t) ? ' (งานนี้)' : ''}${u.done ? ' ✓' : ''}',
                      style: const TextStyle(fontSize: 13.5, color: kCText)),
                  ),
              ])),
            ),
          ],
          const SizedBox(height: 10),
          const Text('แท็กจะหายไปจากรายการแท็กของแอพด้วย กู้คืนไม่ได้',
            style: TextStyle(fontSize: 12, color: kCRed)),
        ]),
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('ยกเลิก', style: TextStyle(color: kCText.withValues(alpha: .5)))),
          if (t.tags.contains(tag))
            TextButton(onPressed: () => Navigator.pop(ctx, 'this'),
              child: const Text('เอาออกเฉพาะงานนี้', style: TextStyle(color: kCText, fontWeight: FontWeight.w600))),
          TextButton(onPressed: () => Navigator.pop(ctx, 'all'),
            child: const Text('ลบออกจากแอพ', style: TextStyle(color: kCRed, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (choice == null) return;
    if (choice == 'this') {
      t.tags.remove(tag);
    } else {
      Tags.removeEverywhere(tag, widget.allTasks);
      t.tags.remove(tag);
    }
    _changed(); // บันทึกทั้งรายการงาน (รวมงานอื่นที่ถูกเอาแท็กออก)
  }

  // แท็ก: แสดงทุกแท็กที่ติดอยู่กับงานนี้ (รวมที่ AI ใส่ให้) · แตะ = เอาออก · กดค้าง = ลบออกจากแอพ
  Widget _tagRow() {
    final tags = widget.task.tags;
    return Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      for (final tag in [...tags])
        GestureDetector(
          onLongPress: () => _deleteTag(tag),
          child: _chip('#$tag  ✕', true, () => _toggleTag(tag)),
        ),
      GestureDetector(
        onTap: _pickTag,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: kCText.withValues(alpha: .18)),
          ),
          child: Text('+ แท็ก', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCText.withValues(alpha: .5))),
        ),
      ),
      if (tags.isNotEmpty)
        SizedBox(width: double.infinity, child: Text('แตะแท็กเพื่อเอาออกจากงานนี้ · กดค้างเพื่อลบออกจากแอพ',
          style: TextStyle(fontSize: 11, color: kCText.withValues(alpha: .3)))),
    ]);
  }

  // เลือกแท็กได้หลายอัน: แตะ = ติด/เอาออก (หน้าต่างไม่ปิด) · กดค้าง = ลบออกจากแอพ
  Future<void> _pickTag() async {
    final newTag = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: const BoxDecoration(color: kCSurf, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('เลือกแท็ก (ได้หลายอัน)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCText)),
          const SizedBox(height: 4),
          Text('แตะเพื่อติด/เอาออก · กดค้างเพื่อลบออกจากแอพ', style: TextStyle(fontSize: 11.5, color: kCText.withValues(alpha: .45))),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final tag in Tags.list)
              GestureDetector(
                onLongPress: () async { await _deleteTag(tag); setS(() {}); },
                child: _chip('#$tag', widget.task.tags.contains(tag), () { _toggleTag(tag); setS(() {}); }),
              ),
            GestureDetector(
              onTap: () => Navigator.pop(ctx, true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: kCText.withValues(alpha: .18))),
                child: Text('+ แท็กใหม่', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCText.withValues(alpha: .5))),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('เสร็จ', style: TextStyle(color: kCGreenDk, fontWeight: FontWeight.w700)),
          )),
        ]),
      )),
    );
    if (newTag == true && mounted) await _newTag();
  }

  Widget _chip(String label, bool active, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? kCGoldDark.withValues(alpha: .2) : kCSurf,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? kCGoldDark.withValues(alpha: .6) : kCText.withValues(alpha: .1)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600,
        color: active ? kCGoldLight : kCText.withValues(alpha: .55))),
    ),
  );

  Widget _plainField(TextEditingController ctrl, String hint, {
    required double size, required FontWeight weight, int maxLines = 1, bool faded = false,
  }) {
    return TextField(
      controller: ctrl,
      minLines: 1,
      maxLines: maxLines,
      textInputAction: TextInputAction.done,
      onEditingComplete: () { _save(); FocusScope.of(context).unfocus(); },
      style: TextStyle(fontSize: size, fontWeight: weight, height: 1.35,
        color: faded ? kCText.withValues(alpha: .75) : kCText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: kCText.withValues(alpha: .3), fontSize: size, fontWeight: weight),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
        border: InputBorder.none,
      ),
    );
  }

  String _fmtDeadline(DateTime d) {
    final now = DateTime.now();
    final diff = d.difference(DateTime(now.year, now.month, now.day)).inDays;
    final timeStr = '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    final months = ['ม.ค.','ก.พ.','มี.ค.','เม.ย.','พ.ค.','มิ.ย.','ก.ค.','ส.ค.','ก.ย.','ต.ค.','พ.ย.','ธ.ค.'];
    if (diff == 0) return 'วันนี้ $timeStr';
    if (diff == 1) return 'พรุ่งนี้ $timeStr';
    if (d.isBefore(now)) return 'เกินกำหนด ${d.day} ${months[d.month-1]}';
    return '${d.day} ${months[d.month-1]} · $timeStr';
  }

  Widget _sectionLabel(String text) =>
    Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kCText.withValues(alpha: .4)));

}
