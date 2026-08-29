import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'models.dart';
import 'task_detail_screen.dart';
import 'habits_screen.dart';

// ── Palette aliases (kept local so no rename needed) ─────────────────────────
const _cBg        = kCBg;
const _cSurf      = kCSurf;
const _cText      = kCText;
const _cGold      = kCGold;
const _cGoldDark  = kCGoldDark;
const _cGoldLight = kCGoldLight;
const _cCream     = kCCream;
const _cGreen     = kCGreen;
const _cGreenDark = kCGreenDk;
const _cRed       = kCRed;
const _cDark      = kCDark;
const _kMono      = kMono;

// ── Auto-categorizer ──────────────────────────────────────────────────────────
enum _EntryType { expense, task, taskWithBudget }

_EntryType _detect(String text) {
  final lower = text.toLowerCase();
  final hasBudget = ['งบ', 'budget'].any(lower.contains);
  final hasMoney  = text.contains('฿') || RegExp(r'\d+\s*บาท').hasMatch(text);
  if (hasBudget) return _EntryType.taskWithBudget;
  if (hasMoney)  return _EntryType.expense;
  return _EntryType.task;
}

int? _extractAmount(String text) {
  final m = RegExp(r'฿\s*(\d+)|(\d+)\s*บาท|(\d+)').firstMatch(text);
  if (m == null) return null;
  return int.tryParse(m.group(1) ?? m.group(2) ?? m.group(3) ?? '');
}

// ── Screen ────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _spent = 0;
  int? _askingBudget;
  bool _showExpenses = false;
  bool _entered = false;
  String? _filter;

  final List<TaskItem> _tasks = [
    TaskItem(title: 'เตรียมสื่อการสอนคณิต', meta: 'เสร็จ 08:12 · เร็วกว่ากำหนด 48 นาที', done: true),
    TaskItem(title: 'ตรวจใบงาน ป.4 (18 ชุด)', meta: 'เลื่อนมาแล้ว 2 ครั้ง', warn: true,
        tag: 'สอน', tagBg: const Color(0x284F7A5B), tagColor: const Color(0xFF3F6349)),
    TaskItem(title: 'ซื้ออุปกรณ์ทำสื่อ', meta: 'ภายในวันพุธ · งบผูกไว้',
        tag: 'งบ ฿500', tagBg: const Color(0x33D8A93F), tagColor: const Color(0xFF7A5A1B), budget: 500),
  ];

  final List<ExpenseItem> _expenses = [
    ExpenseItem('กาแฟเช้า', 65),
    ExpenseItem('ค่ารถ', 40),
    ExpenseItem('ข้าวกลางวัน', 85),
    ExpenseItem('ซื้อชอล์ก', 130),
  ];

  final List<HabitItem> _habits = [
    HabitItem(title: 'ออกกำลังกาย 15 นาที', streak: 3),
    HabitItem(title: 'อ่านหนังสือ 20 นาที', streak: 1),
  ];

  late AnimationController _shimmer;
  late AnimationController _caret;
  Timer? _spendTimer;

  static const _weekBase   = 1180;
  static const _weekBudget = 2500;
  static const _target     = 320;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _caret   = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
    Future.delayed(const Duration(milliseconds: 60), () { if (mounted) setState(() => _entered = true); });
    final step = math.max(1, (_target / 22).ceil());
    _spendTimer = Timer.periodic(const Duration(milliseconds: 45), (t) {
      setState(() => _spent = (_spent + step).clamp(0, _target));
      if (_spent >= _target) t.cancel();
    });
  }

  @override
  void dispose() {
    _shimmer.dispose(); _caret.dispose(); _spendTimer?.cancel();
    super.dispose();
  }

  List<int> get _pendingIdx => List.generate(_tasks.length, (i) => i).where((i) => !_tasks[i].done).toList();
  List<int> get _doneIdx    => List.generate(_tasks.length, (i) => i)
      .where((i) => _tasks[i].done)
      .toList()
      ..sort((a, b) => (_tasks[b].doneAt ?? DateTime(0)).compareTo(_tasks[a].doneAt ?? DateTime(0)));

  List<int> get _filteredPending {
    if (_filter == null) return _pendingIdx;
    return _pendingIdx.where((i) => _tasks[i].tag == _filter).toList();
  }

  List<String> get _availableTags =>
      _pendingIdx.map((i) => _tasks[i].tag).whereType<String>().toSet().toList();

  int get _weekSpent => _weekBase + _spent;
  int get _pct       => (_weekSpent / _weekBudget * 100).round().clamp(0, 100);
  bool get _overPace => _pct > 62;

  void _toggle(int i) {
    setState(() {
      _tasks[i].done = !_tasks[i].done;
      if (_tasks[i].done) {
        _tasks[i].doneAt = DateTime.now();
        if (_tasks[i].budget != null) _askingBudget = i;
      } else {
        _tasks[i].doneAt = null;
      }
    });
  }

  void _openInput() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InputSheet(
        ctrl: ctrl,
        onSubmit: (text) {
          if (text.trim().isEmpty) return;
          final type = _detect(text);
          final amount = _extractAmount(text);
          setState(() {
            switch (type) {
              case _EntryType.expense:
                _spent += amount ?? 0;
                _expenses.add(ExpenseItem(text.trim(), amount ?? 0));
              case _EntryType.taskWithBudget:
                _tasks.add(TaskItem(
                  title: text.trim(),
                  meta: amount != null ? 'งบผูกไว้ ฿$amount' : 'งานใหม่',
                  tag: amount != null ? 'งบ ฿$amount' : null,
                  tagBg: const Color(0x33D8A93F),
                  tagColor: const Color(0xFF7A5A1B),
                  budget: amount,
                ));
              case _EntryType.task:
                _tasks.add(TaskItem(title: text.trim(), meta: 'งานใหม่'));
            }
          });
        },
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cBg,
      body: Stack(children: [
        _buildMain(),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          transitionBuilder: (child, anim) => SlideTransition(
            position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: _showExpenses
              ? SizedBox.expand(key: const ValueKey('expenses'), child: _buildExpensesPanel())
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),
        if (_askingBudget != null) _buildBudgetSheet(),
      ]),
    );
  }

  Widget _buildMain() {
    final pending = _pendingIdx.length;
    final done    = _doneIdx.length;
    return Column(children: [
      Expanded(child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 24, 20, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _header(pending, done),
          const SizedBox(height: 18),
          _spendingCard(),
          const SizedBox(height: 24),
          _sectionLabel('งานที่เหลือวันนี้'),
          const SizedBox(height: 10),
          if (_availableTags.isNotEmpty) ...[_filterChips(), const SizedBox(height: 10)],
          // pending tasks
          ..._filteredPending.asMap().entries.map((e) => _staggered(e.key, _taskCard(e.value, done: false))),
          if (_filteredPending.isEmpty && pending == 0) _allDoneCard(),
          if (_filteredPending.isEmpty && pending > 0) _noMatchCard(),
          // done tasks inline
          if (done > 0) ...[
            const SizedBox(height: 6),
            _sectionLabel('เสร็จแล้ว $done'),
            const SizedBox(height: 8),
            ..._doneIdx.map((i) => _taskCard(i, done: true)),
          ],
          const SizedBox(height: 12),
          _habitSummaryRow(),
        ]),
      )),
      _inputBar(),
    ]);
  }

  // ── Header ───────────────────────────────────────────────────────────────────
  Widget _header(int remaining, int done) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('จันทร์ 31 ส.ค.', style: TextStyle(fontSize: 10.5, color: _cGoldDark, fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        Text('วันนี้เหลือ $remaining งาน', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _cText)),
      ]),
      if (done > 0) Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(color: _cGreen.withValues(alpha: .14), border: Border.all(color: _cGreen.withValues(alpha: .28)), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 13, height: 13, decoration: BoxDecoration(color: _cGreen, borderRadius: BorderRadius.circular(4)),
            child: const Center(child: Icon(Icons.check, size: 9, color: Color(0xFFFBF8F0)))),
          const SizedBox(width: 6),
          Text('เสร็จแล้ว $done', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _cGreenDark)),
        ]),
      ),
    ]);
  }

  // ── Spending card ─────────────────────────────────────────────────────────────
  Widget _spendingCard() {
    final left = (_weekBudget - _weekSpent).clamp(0, _weekBudget);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF1E241B), Color(0xFF0E120C)]),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .95), blurRadius: 44, offset: const Offset(0, 26))],
        ),
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(right: -20, top: -80, child: AnimatedBuilder(
            animation: _shimmer,
            builder: (_, child) => Opacity(
              opacity: 0.7 + 0.3 * math.sin(_shimmer.value * 2 * math.pi), child: child),
            child: Container(width: 200, height: 200,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(colors: [_cGold.withValues(alpha: .55), Colors.transparent]))),
          )),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('ใช้วันนี้', style: TextStyle(fontSize: 10.5, color: Color(0xFFE7D3A5), fontWeight: FontWeight.w600)),
              Text('งบสัปดาห์ ฿$_weekBudget', style: TextStyle(fontSize: 10.5, color: _cCream.withValues(alpha: .5))),
            ]),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              AnimatedScale(
                scale: _spent >= _target ? 1.0 : 0.88,
                duration: const Duration(milliseconds: 480),
                curve: Curves.easeOutBack,
                child: AnimatedBuilder(
                  animation: _shimmer,
                  builder: (_, child) => ShaderMask(
                    shaderCallback: (bounds) {
                      final t = _shimmer.value;
                      return LinearGradient(
                        begin: Alignment(-1.0 + t * 3, 0), end: Alignment(t * 3, 0),
                        colors: const [Color(0xFFF1EAD9), Color(0xFFF7DF9E), Color(0xFFD8A93F), Color(0xFFF7DF9E), Color(0xFFF1EAD9)],
                        stops: const [0, .3, .5, .7, 1],
                      ).createShader(bounds);
                    },
                    child: Text('฿$_spent', style: const TextStyle(fontFamily: _kMono, fontSize: 52, fontWeight: FontWeight.w600, height: .9, letterSpacing: -1.3, color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Padding(padding: const EdgeInsets.only(bottom: 7),
                child: Text(_overPace ? 'เร็วกว่างบ' : 'อยู่ในงบ',
                  style: TextStyle(fontSize: 11.5, color: _overPace ? const Color(0xFFE8A08C) : const Color(0xFFC0D8C4)))),
            ]),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(height: 6, child: Stack(children: [
                Container(color: _cCream.withValues(alpha: .14)),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 500), curve: Curves.easeInOut,
                  widthFactor: _pct / 100,
                  child: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [_cGoldDark, _cGoldLight])))),
              ])),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('เหลือในงบ ฿$left', style: TextStyle(fontSize: 10, color: _cCream.withValues(alpha: .42))),
              GestureDetector(
                onTap: () => setState(() => _showExpenses = true),
                child: Text('ดูรายจ่าย ${_expenses.length} รายการ ›',
                  style: TextStyle(fontSize: 10, color: _cGold.withValues(alpha: .75), fontWeight: FontWeight.w600)),
              ),
            ]),
          ]),
        ]),
      ),
    );
  }

  // ── Task card ─────────────────────────────────────────────────────────────────
  Widget _staggered(int listIdx, Widget child) {
    final dur = Duration(milliseconds: 320 + listIdx * 90);
    return AnimatedOpacity(
      opacity: _entered ? 1 : 0, duration: dur, curve: Curves.easeOut,
      child: AnimatedSlide(offset: _entered ? Offset.zero : const Offset(0, 0.18), duration: dur, curve: Curves.easeOutCubic, child: child),
    );
  }

  Widget _taskCard(int i, {required bool done}) {
    final t = _tasks[i];
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
        TaskDetailScreen(task: t, onDelete: () => setState(() => _tasks.removeAt(i)))
      )).then((_) => setState(() {})),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, left: 7),
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(left: -14, top: 0, bottom: 0, child: Center(child: Container(
            width: 14, height: 14,
            decoration: BoxDecoration(color: done ? _cGreen.withValues(alpha: .3) : const Color(0xFFF0E8D5), shape: BoxShape.circle)))),
          Positioned(left: -8, top: 10, bottom: 10, child: Container(width: 1.5,
            decoration: BoxDecoration(border: Border(left: BorderSide(color: _cText.withValues(alpha: .13), width: 1.5))))),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 13, 14, 13),
            decoration: BoxDecoration(
              color: done ? _cSurf.withValues(alpha: .6) : _cSurf.withValues(alpha: .95),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _cText.withValues(alpha: done ? .05 : .09)),
              boxShadow: [BoxShadow(color: _cText.withValues(alpha: .9), blurRadius: 26, offset: const Offset(0, 14), spreadRadius: -22)],
            ),
            child: Row(children: [
              // checkbox — tap only here to toggle
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () { _toggle(i); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  width: 23, height: 23, margin: const EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(
                    color: done ? _cGreen : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: done ? _cGreen : _cText.withValues(alpha: .5), width: 1.8),
                    boxShadow: [BoxShadow(color: done ? _cGreen.withValues(alpha: .5) : Colors.transparent, blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: done ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                  color: done ? _cText.withValues(alpha: .4) : _cText, height: 1.35,
                  decoration: done ? TextDecoration.lineThrough : null,
                  decorationColor: _cText.withValues(alpha: .4))),
                const SizedBox(height: 4),
                Text(t.meta, style: TextStyle(fontSize: 10.5,
                  color: (!done && t.warn) ? _cRed : _cText.withValues(alpha: done ? .32 : .5))),
                if (t.subTasks.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _subTaskProgress(t.subTasks),
                ],
              ])),
              if (t.tag != null) ...[
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: t.tagBg, borderRadius: BorderRadius.circular(999)),
                  child: Text(t.tag!, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: t.tagColor))),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _subTaskProgress(List<SubTask> subs) {
    int total = 0, done = 0;
    void count(List<SubTask> list) { for (final s in list) { total++; if (s.done) done++; count(s.children); } }
    count(subs);
    return Row(children: [
      Text('$done/$total ขั้นตอน', style: TextStyle(fontSize: 10, color: _cText.withValues(alpha: .4), fontFamily: _kMono)),
    ]);
  }

  // ── Filter chips ──────────────────────────────────────────────────────────────
  Widget _filterChips() {
    return SizedBox(height: 30, child: ListView(scrollDirection: Axis.horizontal, children: [
      _chip('ทั้งหมด', _filter == null, () => setState(() => _filter = null)),
      ..._availableTags.map((tag) => _chip(tag, _filter == tag, () => setState(() => _filter = _filter == tag ? null : tag))),
    ]));
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _cGold.withValues(alpha: .18) : _cText.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? _cGoldDark.withValues(alpha: .5) : _cText.withValues(alpha: .1)),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          color: active ? _cGoldDark : _cText.withValues(alpha: .5))),
      ),
    );
  }

  Widget _allDoneCard() => Container(
    margin: const EdgeInsets.only(bottom: 11),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    decoration: BoxDecoration(color: _cGreen.withValues(alpha: .1), borderRadius: BorderRadius.circular(18), border: Border.all(color: _cGreen.withValues(alpha: .35))),
    child: Column(children: [
      const Text('เคลียร์งานวันนี้ครบแล้ว', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _cGreenDark), textAlign: TextAlign.center),
      const SizedBox(height: 6),
      Text('ดูงานที่เสร็จด้านล่าง', style: TextStyle(fontSize: 10.5, color: _cText.withValues(alpha: .45)), textAlign: TextAlign.center),
    ]),
  );

  Widget _noMatchCard() => Container(
    margin: const EdgeInsets.only(bottom: 11),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    decoration: BoxDecoration(color: _cText.withValues(alpha: .04), borderRadius: BorderRadius.circular(18), border: Border.all(color: _cText.withValues(alpha: .1))),
    child: Center(child: Text('ไม่มีงานในหมวดนี้', style: TextStyle(fontSize: 13, color: _cText.withValues(alpha: .4)))),
  );

  // ── Habit summary ─────────────────────────────────────────────────────────────
  Widget _habitSummaryRow() {
    final done  = _habits.where((h) => h.doneToday).length;
    final total = _habits.length;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HabitsScreen(habits: _habits))).then((_) => setState(() {})),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xE6DCE7DC), Color(0x7FDCE7DC)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _cGreen.withValues(alpha: .25)),
        ),
        child: Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(color: _cGreen.withValues(alpha: .15), borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _cGreen, width: 1.8)),
            child: Center(child: Text('$done', style: const TextStyle(fontFamily: _kMono, fontSize: 15, fontWeight: FontWeight.w700, color: _cGreenDark)))),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('นิสัยประจำวัน', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _cText)),
            const SizedBox(height: 3),
            Text('ทำแล้ว $done/$total วันนี้', style: const TextStyle(fontSize: 10.5, color: _cGreenDark)),
          ])),
          Icon(Icons.chevron_right, size: 18, color: _cText.withValues(alpha: .3)),
        ]),
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────────
  Widget _inputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 18),
      decoration: BoxDecoration(
        color: _cSurf.withValues(alpha: .96),
        border: Border(top: BorderSide(color: _cText.withValues(alpha: .1))),
        boxShadow: [BoxShadow(color: _cText.withValues(alpha: .9), blurRadius: 26, offset: const Offset(0, -12), spreadRadius: -20)],
      ),
      child: GestureDetector(
        onTap: _openInput,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_cBg, Color(0xFFEBE3CD)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cGold.withValues(alpha: .35)),
            boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: .6), offset: const Offset(0, 1), blurRadius: 0)],
          ),
          child: Row(children: [
            const Text('›', style: TextStyle(fontFamily: _kMono, fontSize: 13, color: _cGoldDark, fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            Expanded(child: Text('พิมพ์งานหรือรายจ่าย…', style: TextStyle(fontSize: 13.5, color: _cText.withValues(alpha: .45)))),
            AnimatedBuilder(
              animation: _caret,
              builder: (_, child) => Opacity(opacity: _caret.value < 0.5 ? 1.0 : 0.0,
                child: Container(width: 2, height: 16, color: _cGoldDark)),
            ),
            const SizedBox(width: 10),
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                gradient: const SweepGradient(startAngle: 3.5, colors: [_cGoldDark, _cGoldLight, _cGold, _cGoldDark]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: _cGoldDark.withValues(alpha: .95), blurRadius: 18, offset: const Offset(0, 10))],
              ),
              child: const Center(child: Text('+', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w300, color: Color(0xFF1A2018)))),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Expenses panel ────────────────────────────────────────────────────────────
  Widget _buildExpensesPanel() {
    final todayTotal = _expenses.fold(0, (s, e) => s + e.amount);
    final weekTotal  = _weekBase + todayTotal;
    final pct        = (weekTotal / _weekBudget).clamp(0.0, 1.0);

    final groups = <String, List<ExpenseItem>>{};
    for (final e in _expenses.reversed) {
      final now = DateTime.now();
      final d   = e.time;
      String label;
      if (d.year == now.year && d.month == now.month && d.day == now.day) label = 'วันนี้';
      else if (d.year == now.year && d.month == now.month && d.day == now.day - 1) label = 'เมื่อวาน';
      else label = '${d.day}/${d.month}/${d.year}';
      groups.putIfAbsent(label, () => []).add(e);
    }

    return Scaffold(
      backgroundColor: _cBg,
      body: Column(children: [
        Container(
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 16),
          decoration: BoxDecoration(color: _cSurf.withValues(alpha: .97),
            border: Border(bottom: BorderSide(color: _cText.withValues(alpha: .09)))),
          child: Row(children: [
            GestureDetector(
              onTap: () => setState(() => _showExpenses = false),
              child: Container(width: 34, height: 34,
                decoration: BoxDecoration(color: _cText.withValues(alpha: .07), borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('‹', style: TextStyle(fontSize: 20, color: _cText)))),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('รายจ่าย', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _cText))),
          ]),
        ),
        // summary card
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1E241B), Color(0xFF0E120C)]),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .6), blurRadius: 28, offset: const Offset(0, 14))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('ใช้ทั้งหมดวันนี้', style: TextStyle(fontSize: 10.5, color: _cCream.withValues(alpha: .5))),
              Text('งบสัปดาห์ ฿$_weekBudget', style: TextStyle(fontSize: 10.5, color: _cCream.withValues(alpha: .35))),
            ]),
            const SizedBox(height: 8),
            Text('฿$todayTotal', style: const TextStyle(fontFamily: _kMono, fontSize: 36, fontWeight: FontWeight.w600, color: Color(0xFFF7DF9E), height: 1)),
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(999), child: SizedBox(height: 5, child: Stack(children: [
              Container(color: _cCream.withValues(alpha: .12)),
              FractionallySizedBox(widthFactor: pct,
                child: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [_cGoldDark, _cGoldLight])))),
            ]))),
            const SizedBox(height: 8),
            Text('ใช้ไปแล้ว ฿$weekTotal จาก ฿$_weekBudget ในสัปดาห์นี้',
              style: TextStyle(fontSize: 10, color: _cCream.withValues(alpha: .38))),
          ]),
        ),
        Expanded(child: _expenses.isEmpty
          ? Center(child: Text('ยังไม่มีรายจ่าย', style: TextStyle(fontSize: 14, color: _cText.withValues(alpha: .35))))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: groups.entries.expand((entry) => [
                Padding(padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: Text(entry.key, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _cText.withValues(alpha: .38)))),
                ...entry.value.map((e) => _expenseRow(e)),
              ]).toList(),
            )),
      ]),
    );
  }

  Widget _expenseRow(ExpenseItem e) {
    final h = e.time.hour.toString().padLeft(2, '0');
    final m = e.time.minute.toString().padLeft(2, '0');
    return Dismissible(
      key: ObjectKey(e),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 9),
        decoration: BoxDecoration(color: _cRed.withValues(alpha: .15), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline, color: _cRed),
      ),
      onDismissed: (_) => setState(() => _expenses.remove(e)),
      child: GestureDetector(
        onTap: () => _editExpense(e),
        child: Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: _cSurf.withValues(alpha: .95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cText.withValues(alpha: .08)),
            boxShadow: [BoxShadow(color: _cText.withValues(alpha: .7), blurRadius: 18, offset: const Offset(0, 8), spreadRadius: -16)],
          ),
          child: Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: _cGold.withValues(alpha: .13), borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Text('฿', style: TextStyle(fontFamily: _kMono, fontSize: 14, color: _cGoldDark, fontWeight: FontWeight.w700)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: _cText)),
              const SizedBox(height: 3),
              Text('$h:$m น.', style: TextStyle(fontSize: 10.5, color: _cText.withValues(alpha: .38))),
            ])),
            Text('฿${e.amount}', style: const TextStyle(fontFamily: _kMono, fontSize: 16, fontWeight: FontWeight.w700, color: _cGoldDark)),
          ]),
        ),
      ),
    );
  }

  void _editExpense(ExpenseItem e) {
    final labelCtrl  = TextEditingController(text: e.label);
    final amountCtrl = TextEditingController(text: e.amount.toString());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          decoration: const BoxDecoration(
            color: Color(0xFFFBF8F0),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: _cText.withValues(alpha: .18), borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 18),
            const Align(alignment: Alignment.centerLeft, child: Text('แก้ไขรายจ่าย', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _cText))),
            const SizedBox(height: 14),
            _sheetField(labelCtrl, 'ชื่อรายจ่าย'),
            const SizedBox(height: 10),
            _sheetField(amountCtrl, 'จำนวนเงิน (บาท)', keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () { setState(() { _expenses.remove(e); }); Navigator.pop(context); },
                child: Container(height: 46, decoration: BoxDecoration(color: _cRed.withValues(alpha: .1), borderRadius: BorderRadius.circular(14), border: Border.all(color: _cRed.withValues(alpha: .3))),
                  child: const Center(child: Text('ลบ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _cRed)))),
              )),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: GestureDetector(
                onTap: () {
                  setState(() {
                    e.label  = labelCtrl.text.trim().isEmpty ? e.label : labelCtrl.text.trim();
                    e.amount = int.tryParse(amountCtrl.text.trim()) ?? e.amount;
                  });
                  Navigator.pop(context);
                },
                child: Container(height: 46, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_cGoldDark, _cGold]), borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Text('บันทึก', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A2018))))),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _sheetField(TextEditingController ctrl, String hint, {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl, keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, color: _cText),
      decoration: InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: _cText.withValues(alpha: .35)),
        filled: true, fillColor: _cBg,
        contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _cGoldDark, width: 1.5)),
      ),
    );
  }

  // ── Budget sheet ──────────────────────────────────────────────────────────────
  Widget _buildBudgetSheet() {
    final taskBudget = _tasks[_askingBudget!].budget!;
    final amounts    = [430, taskBudget, 560];
    return GestureDetector(
      onTap: () => setState(() => _askingBudget = null),
      child: Container(
        color: _cDark.withValues(alpha: .55),
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFBF8F0), Color(0xFFF1EAD9)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _cText.withValues(alpha: .18), borderRadius: BorderRadius.circular(999)))),
                const SizedBox(height: 18),
                Text('งานนี้ผูกงบไว้ ฿$taskBudget', style: const TextStyle(fontSize: 10.5, color: _cGoldDark, fontWeight: FontWeight.w600)),
                const SizedBox(height: 7),
                const Text('ใช้ไปเท่าไหร่จริง', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _cText)),
                const SizedBox(height: 5),
                Text('บันทึกเป็นรายจ่ายให้เลย', style: TextStyle(fontSize: 12.5, color: _cText.withValues(alpha: .55))),
                const SizedBox(height: 18),
                Row(children: List.generate(3, (i) {
                  final amt = amounts[i];
                  final mid = i == 1;
                  return Expanded(child: GestureDetector(
                    onTap: () => setState(() { _spent += amt; _askingBudget = null; }),
                    child: Container(
                      margin: EdgeInsets.only(left: i > 0 ? 9 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: mid ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE0B455), Color(0xFFB98A2E)]) : null,
                        color: mid ? null : _cSurf.withValues(alpha: .95),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _cGold.withValues(alpha: .35)),
                        boxShadow: [BoxShadow(color: _cGoldDark.withValues(alpha: .9), blurRadius: 20, offset: const Offset(0, 10), spreadRadius: -14)],
                      ),
                      child: Center(child: Text('฿$amt', style: TextStyle(fontFamily: _kMono, fontSize: 15, fontWeight: FontWeight.w600, color: mid ? const Color(0xFF1A2018) : _cText))),
                    ),
                  ));
                })),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => setState(() => _askingBudget = null),
                  child: Center(child: Text('ข้ามไปก่อน', style: TextStyle(fontSize: 12.5, color: _cText.withValues(alpha: .45)))),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String text) =>
    Text(text, style: TextStyle(fontSize: 10, color: _cText.withValues(alpha: .38), fontWeight: FontWeight.w500));
}

// ── Input bottom sheet ────────────────────────────────────────────────────────
class _InputSheet extends StatefulWidget {
  final TextEditingController ctrl;
  final void Function(String) onSubmit;
  const _InputSheet({required this.ctrl, required this.onSubmit});
  @override
  State<_InputSheet> createState() => _InputSheetState();
}

class _InputSheetState extends State<_InputSheet> {
  _EntryType? _type;
  int? _amount;

  void _analyse(String text) => setState(() {
    _type   = text.trim().isEmpty ? null : _detect(text);
    _amount = _extractAmount(text);
  });

  String get _typeLabel => switch (_type) {
    _EntryType.expense         => '→ รายจ่าย${_amount != null ? " ฿$_amount" : ""}',
    _EntryType.taskWithBudget  => '→ งาน + งบผูก${_amount != null ? " ฿$_amount" : ""}',
    _EntryType.task            => '→ งานใหม่',
    null                       => '',
  };

  Color get _typeColor => switch (_type) {
    _EntryType.expense         => const Color(0xFFE7D3A5),
    _EntryType.taskWithBudget  => const Color(0xFF1A2018),
    _EntryType.task            => const Color(0xFFC0D8C4),
    null                       => Colors.transparent,
  };

  Color get _typeBg => switch (_type) {
    _EntryType.expense         => const Color(0x2ED8A93F),
    _EntryType.taskWithBudget  => const Color(0xFFE0B455),
    _EntryType.task            => const Color(0x384F7A5B),
    null                       => Colors.transparent,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFBF8F0), Color(0xFFF1EAD9)]),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kCText.withValues(alpha: .18), borderRadius: BorderRadius.circular(999)))),
          const SizedBox(height: 16),
          const Text('จุดบันทึกเดียว', style: TextStyle(fontSize: 10.5, color: kCGoldDark, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(
              controller: widget.ctrl,
              autofocus: true,
              onChanged: _analyse,
              textInputAction: TextInputAction.done,
              onSubmitted: (v) { widget.onSubmit(v); Navigator.pop(context); },
              style: const TextStyle(fontSize: 15, color: kCText, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'เช่น "ซื้อชอล์ก 150 บาท" หรือ "ส่งเกรดศุกร์นี้"',
                hintStyle: TextStyle(color: kCText.withValues(alpha: .4), fontSize: 13.5),
                filled: true, fillColor: kCText.withValues(alpha: .06),
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kCGoldDark, width: 1.5)),
              ),
            )),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () { widget.onSubmit(widget.ctrl.text); Navigator.pop(context); },
              child: Container(width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: const SweepGradient(startAngle: 3.5, colors: [kCGoldDark, kCGoldLight, kCGold, kCGoldDark]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: kCGoldDark.withValues(alpha: .9), blurRadius: 16, offset: const Offset(0, 8))],
                ),
                child: const Center(child: Icon(Icons.arrow_upward_rounded, color: Color(0xFF1A2018), size: 20))),
            ),
          ]),
          if (_type != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: _typeBg, borderRadius: BorderRadius.circular(999)),
                child: Text(_typeLabel, style: TextStyle(fontFamily: _kMono, fontSize: 11, fontWeight: FontWeight.w600, color: _typeColor)),
              ),
            ]),
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
