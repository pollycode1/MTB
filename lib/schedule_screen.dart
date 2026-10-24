import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'schedule_data.dart';

export 'schedule_data.dart' show hm;

// ── ตารางเวลา 06:00–16:30 · วันเดียว / 7 วัน · โหมดแก้ "ตารางสอน" และ "งานพิเศษ" (ประจำทุกสัปดาห์) ─────
const _cTeach = Color(0xFF5B7DB8);
const _cDuty  = kCGoldDark;

class _Item {
  final int start, end;
  final TaskItem? task;
  final WeeklyBlock? block;
  final bool real; // false = รอบล่วงหน้าของงานทำซ้ำ (ยังไม่ถึง)
  _Item(this.start, this.end, {this.task, this.block, this.real = true});
}

// แบ่งช่องซ้อนเวลาให้อยู่เคียงกัน: คืน (รายการ, ลำดับช่อง) และจำนวนช่องทั้งหมดของวัน
(List<(_Item, int)>, int) _lanes(List<_Item> items) {
  items.sort((a, b) => a.start.compareTo(b.start));
  final ends = <int>[];
  final out = <(_Item, int)>[];
  for (final it in items) {
    var lane = ends.indexWhere((e) => e <= it.start);
    if (lane < 0) { ends.add(it.end); lane = ends.length - 1; } else { ends[lane] = it.end; }
    out.add((it, lane));
  }
  return (out, ends.isEmpty ? 1 : ends.length);
}

class ScheduleScreen extends StatefulWidget {
  final List<TaskItem> tasks;
  final void Function(TaskItem) onAdd;            // เพิ่มงานใหม่ที่ลงเวลาแล้ว
  final Future<void> Function(TaskItem) onOpen;   // เปิดรายละเอียดงาน
  final void Function(TaskItem) onToggle;         // ติ๊กเสร็จ (ใช้ _toggle ของหน้าหลัก)
  const ScheduleScreen({super.key, required this.tasks, required this.onAdd, required this.onOpen, required this.onToggle});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  static const _dayShort = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];
  static const _dayLong  = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์'];
  static const _months   = ['ม.ค.','ก.พ.','มี.ค.','เม.ย.','พ.ค.','มิ.ย.','ก.ค.','ส.ค.','ก.ย.','ต.ค.','พ.ย.','ธ.ค.'];
  static const _recur    = {'': 'ไม่ซ้ำ', 'daily': 'ทุกวัน', 'weekly': 'ทุกสัปดาห์', 'monthly': 'ทุกเดือน'};

  bool _week = true;                  // เปิดมาเป็นแบบ 7 วัน (false = วันเดียว)
  String _mode = 'task';              // 'task' | 'teach' | 'duty'
  DateTime _day = dateOnly(DateTime.now());
  DateTime get _monday => _day.subtract(Duration(days: _day.weekday - 1));
  int get _rows => (kDayEndMin - kDayStartMin) ~/ kSlotMin;   // 21 ช่อง

  @override
  void initState() {
    super.initState();
    Holidays.refreshIfStale().then((fresh) { if (fresh && mounted) setState(() {}); });
  }

  bool _isHoliday(DateTime d) => Holidays.nameOn(d) != null;
  List<(int, int)> _busy(DateTime d) => busyOn(d, widget.tasks, ScheduleStore.blocks, holiday: _isHoliday(d));

  String _dur(int m) => m < 60 ? '$m นาที' : m % 60 == 0 ? '${m ~/ 60} ชม.' : '${m ~/ 60} ชม. ${m % 60} น.';

  // ── เพิ่มงาน: เลือกได้เฉพาะความยาวที่ว่างพอ ─────────────────────────────────────
  Future<void> _addTask(DateTime day, int startMin) async {
    final maxLen = freeLength(startMin, _busy(day));
    if (maxLen == 0) return; // ช่องไม่ว่าง
    final options = [30, 60, 90, 120, 180].where((m) => m <= maxLen).toList();
    final ctrl = TextEditingController();
    var dur = options.contains(60) ? 60 : options.last;
    var recur = '';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: const BoxDecoration(color: kCSurf, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('เพิ่มงาน · ${_dayLong[day.weekday - 1]} ${day.day} ${_months[day.month - 1]} · ${hm(startMin)} น.',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kCText)),
            Text('ว่างต่อเนื่อง ${_dur(maxLen)}', style: TextStyle(fontSize: 11.5, color: kCText.withValues(alpha: .45))),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl, autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => Navigator.pop(ctx, true),
              style: const TextStyle(fontSize: 15, color: kCText),
              decoration: InputDecoration(
                hintText: 'ชื่องาน',
                hintStyle: TextStyle(color: kCText.withValues(alpha: .35), fontSize: 13.5),
                filled: true, fillColor: kCBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            _chips({for (final m in options) m: _dur(m)}, dur, (v) => setS(() => dur = v)),
            const SizedBox(height: 8),
            _chips(_recur, recur, (v) => setS(() => recur = v)),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kCGreen, padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('เพิ่ม ${hm(startMin)}–${hm(startMin + dur)}${recur.isEmpty ? '' : ' · ${_recur[recur]}'}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
            )),
          ]),
        ),
      )),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    widget.onAdd(TaskItem(
      title: ctrl.text.trim(),
      slotStart: DateTime(day.year, day.month, day.day, startMin ~/ 60, startMin % 60),
      slotMin: dur,
      recurrence: recur.isEmpty ? null : recur,
      plannedFor: day,
    ));
    setState(() {});
  }

  // ── เพิ่ม/แก้ คาบสอน หรือ งานพิเศษ (ซ้ำทุกสัปดาห์ในวันเดียวกัน) ────────────────────────
  Future<void> _editBlock(DateTime day, int startMin, {WeeklyBlock? block}) async {
    final kind = block?.kind ?? _mode;
    final ctrl = TextEditingController(text: block?.title ?? '');
    var start = block?.startMin ?? startMin;
    var dur = block == null ? (kind == 'teach' ? 50 : 60) : block.endMin - block.startMin;
    final weekday = block?.weekday ?? day.weekday;
    final label = kind == 'teach' ? 'คาบสอน' : 'งานพิเศษ';
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: const BoxDecoration(color: kCSurf, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${block == null ? 'เพิ่ม' : 'แก้'}$label · ทุกวัน${_dayLong[weekday - 1]}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kCText)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl, autofocus: block == null,
              style: const TextStyle(fontSize: 15, color: kCText),
              decoration: InputDecoration(
                hintText: kind == 'teach' ? 'เช่น คณิต ม.2/3 ห้อง 214' : 'เช่น เวรประตู · ประชุมกลุ่มสาระ',
                hintStyle: TextStyle(color: kCText.withValues(alpha: .35), fontSize: 13.5),
                filled: true, fillColor: kCBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Text('เริ่ม', style: TextStyle(fontSize: 12.5, color: kCText.withValues(alpha: .6))),
              IconButton(onPressed: start - 5 >= kDayStartMin ? () => setS(() => start -= 5) : null,
                icon: const Icon(Icons.remove_rounded, color: kCText)),
              Text(hm(start), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kCText)),
              IconButton(onPressed: start + dur + 5 <= kDayEndMin ? () => setS(() => start += 5) : null,
                icon: const Icon(Icons.add_rounded, color: kCText)),
              const Spacer(),
              Text('ถึง ${hm(start + dur)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kCText)),
            ]),
            _chips({for (final m in const [30, 50, 60, 90, 100, 120, 180]) if (start + m <= kDayEndMin) m: _dur(m)}, dur, (v) => setS(() => dur = v)),
            const SizedBox(height: 14),
            Row(children: [
              if (block != null)
                TextButton(onPressed: () => Navigator.pop(ctx, 'delete'),
                  child: const Text('ลบ', style: TextStyle(color: kCRed, fontWeight: FontWeight.w700))),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kind == 'teach' ? _cTeach : _cDuty,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => Navigator.pop(ctx, 'save'),
                child: const Text('บันทึก', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ]),
          ]),
        ),
      )),
    );
    if (result == null) return;
    setState(() {
      if (result == 'delete') {
        ScheduleStore.blocks.remove(block);
      } else if (ctrl.text.trim().isNotEmpty) {
        if (block == null) {
          ScheduleStore.blocks.add(WeeklyBlock(weekday: weekday, startMin: start, endMin: start + dur, title: ctrl.text.trim(), kind: kind));
        } else {
          block..title = ctrl.text.trim()..startMin = start..endMin = start + dur;
        }
      }
    });
    await ScheduleStore.save();
  }

  // ── นำเข้าตารางสอน JSON: คัดลอกรูปแบบไปให้ AI แปลงตาราง แล้ววางกลับมา ──────────────────────
  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _copyTemplate() async {
    await Clipboard.setData(const ClipboardData(text: scheduleTemplate));
    if (mounted) _toast('คัดลอกแล้ว · วางให้ AI พร้อมรูปตารางสอน แล้วคัดลอกผลลัพธ์กลับมานำเข้า');
  }

  // แทนที่เฉพาะประเภทที่มีในข้อมูลนำเข้า (นำเข้าแค่คาบสอน → งานพิเศษเดิมยังอยู่)
  Future<void> _importJson() async {
    final r = parseScheduleJson((await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '');
    if (!mounted) return;
    if (r.error != null) { _toast('นำเข้าไม่ได้: ${r.error}'); return; }
    final blocks = r.blocks!;
    final kinds = blocks.map((b) => b.kind).toSet();
    final old = ScheduleStore.blocks.where((b) => kinds.contains(b.kind)).length;
    final label = [if (kinds.contains('teach')) 'ตารางสอน', if (kinds.contains('duty')) 'งานพิเศษ'].join(' และ ');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCSurf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('นำเข้า$label?', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCText)),
        content: Text('${blocks.length} รายการ${old > 0 ? ' จะแทนที่ของเดิม $old รายการ' : ''}',
          style: TextStyle(fontSize: 13.5, color: kCText.withValues(alpha: .6))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('ยกเลิก', style: TextStyle(color: kCText.withValues(alpha: .5)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('นำเข้า', style: TextStyle(color: kCGreenDk, fontWeight: FontWeight.w700))),
        ],
      ),
    ) ?? false;
    if (!ok) return;
    setState(() => ScheduleStore.blocks
      ..removeWhere((b) => kinds.contains(b.kind))
      ..addAll(blocks));
    await ScheduleStore.save();
    if (mounted) _toast('นำเข้า ${blocks.length} รายการแล้ว');
  }

  // ── วันหยุดพิเศษ: กดค้างที่หัววัน ───────────────────────────────────────────────
  Future<void> _holidayMenu(DateTime d) async {
    final isCustom = Holidays.custom.containsKey(Holidays.key(d));
    final pub = Holidays.public[Holidays.key(d)];
    final ctrl = TextEditingController(text: Holidays.custom[Holidays.key(d)] ?? '');
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCSurf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${_dayLong[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCText)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (pub != null) Text('วันหยุดราชการ: $pub', style: const TextStyle(fontSize: 13, color: kCRed)),
          const SizedBox(height: 8),
          TextField(controller: ctrl, style: const TextStyle(color: kCText),
            decoration: InputDecoration(hintText: 'ชื่อวันหยุดพิเศษ เช่น กีฬาสี · ปิดภาคเรียน',
              hintStyle: TextStyle(color: kCText.withValues(alpha: .3)))),
          const SizedBox(height: 6),
          Text('วันหยุดไม่มีคาบสอน/งานพิเศษ ทั้งวันเป็นเวลาว่าง', style: TextStyle(fontSize: 11.5, color: kCText.withValues(alpha: .45))),
        ]),
        actions: [
          if (isCustom) TextButton(onPressed: () => Navigator.pop(ctx, 'remove'),
            child: const Text('ยกเลิกวันหยุด', style: TextStyle(color: kCRed))),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('ปิด', style: TextStyle(color: kCText.withValues(alpha: .5)))),
          TextButton(onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('ตั้งเป็นวันหยุด', style: TextStyle(color: kCGreenDk, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (r == 'remove') await Holidays.setCustom(d, null);
    if (r == 'save') await Holidays.setCustom(d, ctrl.text.trim().isEmpty ? 'วันหยุดพิเศษ' : ctrl.text.trim());
    if (mounted) setState(() {});
  }

  Widget _chips<T>(Map<T, String> items, T selected, ValueChanged<T> onTap) => Wrap(spacing: 8, runSpacing: 8, children: [
    for (final e in items.entries)
      ChoiceChip(
        label: Text(e.value),
        selected: e.key == selected,
        onSelected: (_) => onTap(e.key),
        selectedColor: kCGreen.withValues(alpha: .3),
        backgroundColor: kCBg,
        labelStyle: TextStyle(fontSize: 12.5, color: e.key == selected ? kCGreenDk : kCText.withValues(alpha: .7)),
      ),
  ]);

  Widget _modeBtn(String mode, String label, Color color) {
    final on = _mode == mode;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: GestureDetector(
        onTap: () => setState(() => _mode = on ? 'task' : mode),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: on ? color.withValues(alpha: .3) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: on ? .9 : .45)),
          ),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: on ? kCText : color)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mon = _monday;
    final days = _week ? [for (var i = 0; i < 7; i++) mon.add(Duration(days: i))] : [_day];
    final rowH = _week ? 30.0 : 48.0;
    final today = dateOnly(DateTime.now());
    return Scaffold(
      backgroundColor: kCBg,
      appBar: AppBar(
        backgroundColor: kCBg, elevation: 0, titleSpacing: 0,
        title: const Text('ตารางเวลา', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kCText)),
        actions: [
          _modeBtn('teach', 'ตารางสอน', _cTeach),
          _modeBtn('duty', 'งานพิเศษ', _cDuty),
          const SizedBox(width: 6),
          IconButton(
            tooltip: _week ? 'ดูวันเดียว' : 'ดู 7 วัน',
            onPressed: () => setState(() => _week = !_week),
            icon: Icon(_week ? Icons.view_day_outlined : Icons.calendar_view_week_rounded, color: kCText),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: kCText),
            color: kCSurf,
            onSelected: (v) => v == 'copy' ? _copyTemplate() : _importJson(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'copy', child: Text('คัดลอกรูปแบบ JSON', style: TextStyle(color: kCText))),
              PopupMenuItem(value: 'import', child: Text('นำเข้าตารางจากคลิปบอร์ด', style: TextStyle(color: kCText))),
            ],
          ),
        ],
      ),
      body: Column(children: [
        if (_mode != 'task')
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (_mode == 'teach' ? _cTeach : _cDuty).withValues(alpha: .15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('กำลังแก้${_mode == 'teach' ? 'ตารางสอน' : 'งานพิเศษ'} (ซ้ำทุกสัปดาห์) · แตะช่องเพื่อเพิ่ม · แตะรายการเพื่อแก้/ลบ',
              style: const TextStyle(fontSize: 12, color: kCText)),
          ),
        // ── เลือกสัปดาห์ / วัน ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(children: [
            IconButton(onPressed: () => setState(() => _day = _day.subtract(Duration(days: _week ? 7 : 1))),
              icon: const Icon(Icons.chevron_left_rounded, color: kCText)),
            Expanded(child: GestureDetector(
              onTap: () => setState(() => _day = today),
              child: Column(children: [
                Text(_week
                    ? '${mon.day} ${_months[mon.month - 1]} – ${mon.add(const Duration(days: 6)).day} ${_months[mon.add(const Duration(days: 6)).month - 1]}'
                    : '${_dayLong[_day.weekday - 1]} ${_day.day} ${_months[_day.month - 1]} ${_day.year + 543}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kCText)),
                if (!_week && _isHoliday(_day))
                  Text('🎌 ${Holidays.nameOn(_day)}', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: kCRed, fontWeight: FontWeight.w600))
                else if (!sameDay(_day, today))
                  const Text('แตะเพื่อกลับวันนี้', style: TextStyle(fontSize: 11, color: kCGoldDark)),
              ]),
            )),
            IconButton(onPressed: () => setState(() => _day = _day.add(Duration(days: _week ? 7 : 1))),
              icon: const Icon(Icons.chevron_right_rounded, color: kCText)),
          ]),
        ),
        // ── หัววัน: แตะ = ดูวันนั้น · กดค้าง = วันหยุดพิเศษ ──
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 0, 8, 6),
          child: Row(children: [
            for (var i = 0; i < 7; i++)
              Expanded(child: Builder(builder: (_) {
                final d = mon.add(Duration(days: i));
                final sel = !_week && sameDay(d, _day);
                final hol = _isHoliday(d);
                return GestureDetector(
                  onTap: () => setState(() { _day = d; _week = false; }),
                  onLongPress: () => _holidayMenu(d),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: sel ? kCGreen.withValues(alpha: .25) : hol ? kCRed.withValues(alpha: .12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sameDay(d, today) ? kCGreen.withValues(alpha: .6) : Colors.transparent),
                    ),
                    child: Column(children: [
                      Text(_dayShort[i], style: TextStyle(fontSize: 11, color: hol ? kCRed : kCText.withValues(alpha: .55))),
                      Text('${d.day}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: hol ? kCRed : kCText)),
                    ]),
                  ),
                );
              })),
          ]),
        ),
        // ── ตาราง ──
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 4, 8, 40),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 48, child: Column(children: [
              for (var r = 0; r < _rows; r++)
                SizedBox(height: rowH, child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(r.isEven ? hm(kDayStartMin + r * kSlotMin) : '',
                      style: TextStyle(fontSize: 10.5, color: kCText.withValues(alpha: .4))),
                  ),
                )),
            ])),
            for (final d in days) Expanded(child: _dayColumn(d, rowH)),
            Container(width: 1, height: _rows * rowH, color: kCText.withValues(alpha: .16)), // ขอบขวา
          ]),
        )),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Wrap(spacing: 14, children: [
            _legend(kCGreen, 'งาน'), _legend(_cTeach, 'คาบสอน'), _legend(_cDuty, 'งานพิเศษ'), _legend(kCRed, 'วันหยุด (กดค้างที่วัน)'),
          ]),
        ),
      ]),
    );
  }

  Widget _legend(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: c.withValues(alpha: .6), borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 10.5, color: kCText.withValues(alpha: .5))),
  ]);

  Widget _dayColumn(DateTime day, double rowH) {
    final hol = _isHoliday(day);
    final items = <_Item>[
      for (final b in blocksOn(ScheduleStore.blocks, day, holiday: hol)) _Item(b.startMin, b.endMin, block: b),
      for (final (t, s) in occurrencesOn(widget.tasks, day)) _Item(minOfDay(s), minOfDay(s) + t.slotMin, task: t, real: sameDay(s, t.slotStart!)),
    ];
    final (placed, lanes) = _lanes(items);
    final busy = _busy(day);
    return LayoutBuilder(builder: (ctx, c) {
      final w = c.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (e) {
          final start = kDayStartMin + (e.localPosition.dy / rowH).floor().clamp(0, _rows - 1) * kSlotMin;
          if (_mode == 'task') {
            if (freeLength(start, busy) > 0) _addTask(day, start); // ช่องไม่ว่าง = แตะแล้วไม่เกิดอะไร
          } else if (!hol) {
            _editBlock(day, start);
          }
        },
        child: SizedBox(height: _rows * rowH, child: Stack(children: [
          for (var r = 0; r < _rows; r++)
            Positioned(top: r * rowH, left: 0, right: 0, child: Container(
              height: rowH,
              decoration: BoxDecoration(
                color: hol ? kCRed.withValues(alpha: .04) : null,
                border: Border(
                  top: BorderSide(color: kCText.withValues(alpha: r.isEven ? .09 : .04)),
                  left: BorderSide(color: kCText.withValues(alpha: .16)), // เส้นแบ่งวัน/ขอบซ้าย
                ),
              ),
            )),
          for (final (it, lane) in placed) _block(it, rowH, (w - 2) / lanes, lane),
        ])),
      );
    });
  }

  Widget _block(_Item it, double rowH, double laneW, int lane) {
    final start = it.start.clamp(kDayStartMin, kDayEndMin), end = it.end.clamp(kDayStartMin, kDayEndMin);
    if (end <= start) return const SizedBox.shrink(); // นอกช่วง 06:00–16:30
    final h = (end - start) / kSlotMin * rowH;
    final t = it.task, b = it.block;
    final color = t != null ? kCGreen : b!.kind == 'teach' ? _cTeach : _cDuty;
    final done = t?.done ?? false;
    final title = t?.title ?? b!.title;
    final recurring = t != null && t.recurrence != null;
    return Positioned(
      top: (start - kDayStartMin) / kSlotMin * rowH + 1, left: 1 + lane * laneW, width: laneW - 2, height: h - 2,
      child: GestureDetector(
        onTap: () async {
          if (t != null) { await widget.onOpen(t); if (mounted) setState(() {}); }
          else if (_mode == b!.kind) { _editBlock(_day, b.startMin, block: b); }
          else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
              '${b.kind == 'teach' ? 'คาบสอน' : 'งานพิเศษ'}: ${b.title} ${hm(b.startMin)}–${hm(b.endMin)} · กดปุ่ม "${b.kind == 'teach' ? 'ตารางสอน' : 'งานพิเศษ'}" ด้านบนเพื่อแก้')));
          }
        },
        onLongPress: (t == null || !it.real) ? null : () { widget.onToggle(t); setState(() {}); },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: _week ? 3 : 8, vertical: _week ? 2 : 5),
          decoration: BoxDecoration(
            color: done ? kCText.withValues(alpha: .06) : color.withValues(alpha: it.real ? .28 : .12),
            borderRadius: BorderRadius.circular(_week ? 5 : 8),
            border: Border.all(color: done ? kCText.withValues(alpha: .12) : color.withValues(alpha: .65)),
          ),
          child: Text(
            _week ? title : '${hm(it.start)}–${hm(it.end)}${recurring ? ' ↻' : ''}  $title',
            maxLines: (h / (_week ? 12 : 17)).floor().clamp(1, 6), overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: _week ? 9.5 : 12.5, height: 1.25, fontWeight: FontWeight.w600,
              color: done ? kCText.withValues(alpha: .4) : kCText,
              decoration: done ? TextDecoration.lineThrough : null),
          ),
        ),
      ),
    );
  }
}
