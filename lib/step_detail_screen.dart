import 'dart:convert';
import 'package:flutter/material.dart';
import 'ai_service.dart';
import 'models.dart';

// ── แถวขั้นตอน (ซ้อนได้): ติ๊ก · ชื่อเต็ม (แตะ = เปิดหน้าของขั้น) · ย่อ/ขยายดูขั้นย่อย · ลบ ─────────────
class StepTile extends StatefulWidget {
  final TaskItem task;           // ใช้ sync การติ๊กทั้งต้นไม้
  final SubTask step;
  final List<SubTask> siblings;  // รายการที่ step อยู่ (ไว้ลบ)
  final List<String> path;       // ชื่อขั้นที่สูงกว่า (ไม่รวม step)
  final int depth;
  final VoidCallback onChanged;
  const StepTile({super.key, required this.task, required this.step, required this.siblings,
    this.path = const [], this.depth = 0, required this.onChanged});
  @override
  State<StepTile> createState() => _StepTileState();
}

class _StepTileState extends State<StepTile> {
  bool _expanded = true; // เริ่มต้นแบบขยาย เห็นขั้นย่อยทุกชั้น

  void _changed() { if (mounted) setState(() {}); widget.onChanged(); }

  @override
  Widget build(BuildContext context) {
    final s = widget.step;
    final total = countSteps(s.children), done = countSteps(s.children, onlyDone: true);
    Widget icon(IconData i, VoidCallback onTap, {Color? color}) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 9, 4, 9),
        child: Icon(i, size: 18, color: color ?? kCText.withValues(alpha: .35)),
      ),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        margin: EdgeInsets.only(left: widget.depth * 18.0, bottom: 8),
        padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
        decoration: BoxDecoration(
          color: kCSurf,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kCText.withValues(alpha: .09)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () { setStepDone(widget.task.subTasks, s, !s.done); _changed(); },
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: s.done ? kCGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: s.done ? kCGreen : kCText.withValues(alpha: .45), width: 1.8),
                ),
                child: s.done ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
            ),
          ),
          Expanded(child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => openStep(context, task: widget.task, step: s, siblings: widget.siblings,
              path: widget.path, onChanged: _changed),
            child: Padding(
              padding: const EdgeInsets.only(top: 9, bottom: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.title, softWrap: true, style: TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w500,
                  color: s.done ? kCText.withValues(alpha: .4) : kCText,
                  decoration: s.done ? TextDecoration.lineThrough : null,
                  decorationColor: kCText.withValues(alpha: .4))),
                if (s.note.isNotEmpty || total > 0) ...[
                  const SizedBox(height: 3),
                  Text([if (total > 0) '$done/$total ขั้นย่อย', if (s.note.isNotEmpty) s.note].join(' · '),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: kCText.withValues(alpha: .45))),
                ],
              ]),
            ),
          )),
          if (s.children.isNotEmpty)
            icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              () => setState(() => _expanded = !_expanded)),
          icon(Icons.close_rounded, () {
            widget.siblings.remove(s);
            syncSteps(widget.task.subTasks);
            widget.onChanged();
          }, color: kCText.withValues(alpha: .28)),
        ]),
      ),
      if (_expanded)
        for (final c in s.children)
          StepTile(
            key: ObjectKey(c),
            task: widget.task, step: c, siblings: s.children,
            path: [...widget.path, s.title], depth: widget.depth + 1,
            onChanged: _changed,
          ),
    ]);
  }
}

// ── หน้ารายละเอียดของขั้นตอน (ซ้อนลงไปได้ไม่จำกัดชั้น) ─────────────────────────────
class StepDetailScreen extends StatefulWidget {
  final TaskItem task;            // งานต้นทาง (ใช้ sync ติ๊กทั้งต้นไม้ + ส่งบริบทให้ AI)
  final SubTask step;
  final List<SubTask> siblings;   // รายการที่ step อยู่ (ไว้ลบ)
  final List<String> path;        // ชื่อขั้นที่สูงกว่า จากบนลงล่าง
  final VoidCallback onChanged;
  const StepDetailScreen({super.key, required this.task, required this.step, required this.siblings,
    required this.path, required this.onChanged});
  @override
  State<StepDetailScreen> createState() => _StepDetailScreenState();
}

class _StepDetailScreenState extends State<StepDetailScreen> {
  late final TextEditingController _titleCtrl = TextEditingController(text: widget.step.title);
  late final TextEditingController _noteCtrl  = TextEditingController(text: widget.step.note);
  bool _aiBusy = false;

  @override
  void dispose() { _titleCtrl.dispose(); _noteCtrl.dispose(); super.dispose(); }

  void _save() {
    final s = widget.step;
    if (_titleCtrl.text.trim().isNotEmpty) s.title = _titleCtrl.text.trim();
    s.note = _noteCtrl.text.trim();
    widget.onChanged();
  }

  void _toggle(SubTask s) {
    setState(() => setStepDone(widget.task.subTasks, s, !s.done));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.step;
    return PopScope(
      onPopInvokedWithResult: (_, _) => _save(),
      child: Scaffold(
        backgroundColor: kCBg,
        body: Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 8, 8, 4),
            child: Row(children: [
              IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded, color: kCText)),
              Expanded(child: Text([widget.task.title, ...widget.path].join(' › '),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCText.withValues(alpha: .5)))),
              IconButton(
                onPressed: () {
                  setState(() => widget.siblings.remove(s));
                  syncSteps(widget.task.subTasks);
                  widget.onChanged();
                  Navigator.pop(context);
                },
                icon: Icon(Icons.delete_outline_rounded, color: kCRed.withValues(alpha: .8)),
              ),
            ]),
          ),
          Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GestureDetector(
                onTap: () => _toggle(s),
                child: Container(
                  margin: const EdgeInsets.only(top: 6, right: 12),
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: s.done ? kCGreen : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: s.done ? kCGreen : kCText.withValues(alpha: .5), width: 2),
                  ),
                  child: s.done ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                ),
              ),
              Expanded(child: TextField(
                controller: _titleCtrl, minLines: 1, maxLines: 5,
                onEditingComplete: _save,
                style: const TextStyle(fontSize: 19, height: 1.35, fontWeight: FontWeight.w700, color: kCText),
                decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 6)),
              )),
            ]),
            TextField(
              controller: _noteCtrl, minLines: 1, maxLines: 6,
              onEditingComplete: _save,
              style: TextStyle(fontSize: 14, height: 1.4, color: kCText.withValues(alpha: .75)),
              decoration: InputDecoration(
                hintText: 'เพิ่มหมายเหตุ…', hintStyle: TextStyle(color: kCText.withValues(alpha: .3)),
                border: InputBorder.none, isDense: true, contentPadding: const EdgeInsets.fromLTRB(38, 6, 0, 6),
              ),
            ),
            const SizedBox(height: 22),
            Text('ขั้นตอนย่อย', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kCText.withValues(alpha: .4))),
            const SizedBox(height: 10),
            for (final c in s.children)
              StepTile(
                key: ObjectKey(c),
                task: widget.task, step: c, siblings: s.children,
                path: [...widget.path, s.title],
                onChanged: () { setState(() {}); widget.onChanged(); },
              ),
            Row(children: [
              stepAddButton('เพิ่มขั้นตอน', () {
                setState(() => s.children.add(SubTask(title: 'ขั้นตอนใหม่')));
                syncSteps(widget.task.subTasks);
                widget.onChanged();
              }),
              const SizedBox(width: 18),
              stepAddButton(_aiBusy ? 'AI กำลังแตกงาน…' : '✨ ให้ AI แตกขั้นตอน', _aiBusy ? () {} : () {
                _save();
                aiSplitFlow(context,
                  task: widget.task, step: s, path: widget.path,
                  setBusy: (v) { if (mounted) setState(() => _aiBusy = v); },
                  onAdded: () { setState(() {}); widget.onChanged(); });
              }),
            ]),
          ])),
        ]),
      ),
    );
  }
}

void openStep(BuildContext context, {required TaskItem task, required SubTask step, required List<SubTask> siblings,
    required List<String> path, required VoidCallback onChanged}) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => StepDetailScreen(
    task: task, step: step, siblings: siblings, path: path, onChanged: onChanged,
  ))).then((_) => onChanged());
}

Widget stepAddButton(String label, VoidCallback onTap) => GestureDetector(
  onTap: onTap,
  child: Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 4),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.add_rounded, size: 16, color: kCText.withValues(alpha: .45)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 13, color: kCText.withValues(alpha: .55), fontWeight: FontWeight.w600)),
    ]),
  ),
);

// ── AI แตกขั้นตอน: เล่ารายละเอียด → AI ถามสิ่งที่จำเป็น → แตกเป็นขั้นหลัก + ขั้นย่อย ────────────────
// step == null = แตกตัวงาน, ไม่งั้น = แตกขั้นตอนนั้นลงไปอีกชั้น
Future<void> aiSplitFlow(BuildContext context, {
  required TaskItem task, SubTask? step, List<String> path = const [],
  required void Function(bool) setBusy, required VoidCallback onAdded,
}) async {
  final target = step?.children ?? task.subTasks;
  final detail = await _askText(context,
    title: step == null ? 'ให้ AI แตกขั้นตอน' : 'แตกขั้นตอน "${step.title}"',
    hint: 'เล่ารายละเอียดเพิ่ม (ไม่บังคับ) เช่น ตรวจ 3 ห้อง ห้องละ 35 ชุด ต้องกรอกคะแนนลงระบบภายในศุกร์',
  );
  if (detail == null || !context.mounted) return;

  String info() => '${todayLine()}\nงาน: ${jsonEncode(taskForAi(task))}\n'
      '${task.meta.isEmpty ? '' : 'หมายเหตุของงาน (ข้อมูลสำคัญ): ${task.meta}\n'}'
      '${step == null ? '' : 'ขั้นที่ต้องการแตก: ${[...path, step.title].join(' › ')}\n'
          '${step.note.isEmpty ? '' : 'หมายเหตุของขั้นนี้: ${step.note}\n'}'}'
      '${detail.isEmpty ? '' : 'รายละเอียดจากผู้ใช้: $detail\n'}'
      'ขั้นตอนที่มีอยู่แล้วในระดับนี้: ${jsonEncode(target.map((s) => s.title).toList())}\n';
  final what = step == null ? 'งานนี้' : 'ขั้นนี้';

  setBusy(true);
  try {
    final q = await AiService.askJson(
      system: aiSystem,
      prompt: '${info()}\nก่อนแตก$what ถามเฉพาะสิ่งที่จำเป็นจริงๆ ต่อการวางขั้นตอนให้ถูกต้อง (เช่น จำนวน ขอบเขต วิธีที่ใช้ ใครเกี่ยวข้อง กำหนดส่ง) '
          'ไม่เกิน 4 ข้อ ข้อละสั้นๆ ห้ามถามสิ่งที่ข้อมูลด้านบนตอบแล้ว ถ้าข้อมูลพอแล้วให้ตอบ questions เป็นอาร์เรย์ว่าง',
      schema: {
        'type': 'object',
        'properties': {'questions': {'type': 'array', 'items': {'type': 'string'}}},
        'required': ['questions'],
        'additionalProperties': false,
      },
    );
    final questions = (q['questions'] as List).cast<String>().where((s) => s.trim().isNotEmpty).take(4).toList();
    if (!context.mounted) return;

    var qa = '';
    if (questions.isNotEmpty) {
      setBusy(false);
      final answers = await _askQuestions(context, questions);
      if (answers == null || !context.mounted) return;
      qa = [for (var i = 0; i < questions.length; i++)
        if (answers[i].isNotEmpty) 'ถาม: ${questions[i]}\nตอบ: ${answers[i]}'].join('\n');
      setBusy(true);
    }

    final r = await AiService.askJson(
      system: aiSystem,
      prompt: '${info()}${qa.isEmpty ? '' : 'คำตอบเพิ่มเติมจากผู้ใช้:\n$qa\n'}\n'
          'แตก$whatเป็นขั้นตอนหลัก 3-6 ขั้น เรียงตามลำดับที่ทำจริง ชื่อขั้นกระชับ ขึ้นต้นด้วยคำกริยา และใช้ตัวเลข/ชื่อจากข้อมูลจริง '
          'เอาเฉพาะขั้นที่เป็นเนื้องานจริง ห้ามใส่ขั้นเตรียมตัวเล็กน้อยที่ใครก็รู้ เช่น เปิดหนังสือ เปิดคอม หยิบปากกา นั่งลง เตรียมโต๊ะ '
          'ขั้นที่ยังใหญ่ให้แตกเป็นขั้นย่อย 2-4 ข้อใน substeps (กฎเดียวกัน) ขั้นที่ชัดอยู่แล้วให้ substeps ว่าง '
          'ถ้ามีขั้นตอนอยู่แล้วในระดับนี้ ให้ตอบเฉพาะขั้นที่ยังขาด',
      schema: {
        'type': 'object',
        'properties': {
          'steps': {'type': 'array', 'items': {
            'type': 'object',
            'properties': {
              'title': {'type': 'string'},
              'substeps': {'type': 'array', 'items': {'type': 'string'}},
            },
            'required': ['title', 'substeps'],
            'additionalProperties': false,
          }},
        },
        'required': ['steps'],
        'additionalProperties': false,
      },
    );
    for (final s in (r['steps'] as List).cast<Map<String, dynamic>>()) {
      final title = (s['title'] as String).trim();
      if (title.isEmpty) continue;
      target.add(SubTask(title: title, children: [
        for (final c in (s['substeps'] as List).cast<String>())
          if (c.trim().isNotEmpty) SubTask(title: c.trim()),
      ]));
    }
    syncSteps(task.subTasks);
    onAdded();
  } on AiException catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
  } finally {
    setBusy(false);
  }
}

Future<String?> _askText(BuildContext context, {required String title, required String hint}) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kCSurf,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCText)),
      content: TextField(
        controller: ctrl, autofocus: true, minLines: 3, maxLines: 6,
        style: const TextStyle(fontSize: 14, color: kCText),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: kCText.withValues(alpha: .35)),
          filled: true, fillColor: kCBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('ยกเลิก', style: TextStyle(color: kCText.withValues(alpha: .5)))),
        TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('ถัดไป', style: TextStyle(color: kCGreenDk, fontWeight: FontWeight.w700))),
      ],
    ),
  );
}

// คำถามจาก AI พร้อมช่องตอบ · ข้อที่เว้นว่างถือว่าข้าม
Future<List<String>?> _askQuestions(BuildContext context, List<String> questions) {
  final ctrls = [for (final _ in questions) TextEditingController()];
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kCSurf,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('AI ขอถามก่อนนิดหนึ่ง', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCText)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < questions.length; i++) ...[
          Text('${i + 1}. ${questions[i]}', style: const TextStyle(fontSize: 13.5, height: 1.35, color: kCText)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrls[i], autofocus: i == 0, minLines: 1, maxLines: 3,
            style: const TextStyle(fontSize: 14, color: kCText),
            decoration: InputDecoration(
              hintText: 'คำตอบ (เว้นว่างได้)',
              hintStyle: TextStyle(fontSize: 13, color: kCText.withValues(alpha: .3)),
              isDense: true, filled: true, fillColor: kCBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('ยกเลิก', style: TextStyle(color: kCText.withValues(alpha: .5)))),
        TextButton(onPressed: () => Navigator.pop(ctx, [for (final c in ctrls) c.text.trim()]),
          child: const Text('แตกขั้นตอน', style: TextStyle(color: kCGreenDk, fontWeight: FontWeight.w700))),
      ],
    ),
  );
}
