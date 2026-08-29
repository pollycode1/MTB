import 'package:flutter/material.dart';
import 'dart:async';

const _kBg = Color(0xFF0E120C);
const _kSurface = Color(0xFFF4EEDF);
const _kSurfaceLight = Color(0xFFFBF8F0);
const _kTextDark = Color(0xFF20291F);
const _kGold = Color(0xFFD8A93F);
const _kGoldDark = Color(0xFFB98A2E);
const _kGoldLight = Color(0xFFF7DF9E);
const _kCream = Color(0xFFF1EAD9);
const _kGreen = Color(0xFF4F7A5B);
const _kGreenDark = Color(0xFF3F6349);
const _kRed = Color(0xFFB7503A);
const _kMono = 'IBM Plex Mono';

class _Task {
  final String title, meta;
  final bool warn;
  final String? tag;
  final Color? tagBg, tagColor;
  final int? budget;
  const _Task(this.title, this.meta, {this.warn = false, this.tag, this.tagBg, this.tagColor, this.budget});
}

final _tasks = [
  const _Task('เตรียมสื่อการสอนคณิต', 'เสร็จ 08:12 · เร็วกว่ากำหนด 48 นาที'),
  const _Task('ตรวจใบงาน ป.4 (18 ชุด)', 'เลื่อนมาแล้ว 2 ครั้ง', warn: true,
      tag: 'สอน', tagBg: Color(0x284F7A5B), tagColor: Color(0xFF3F6349)),
  const _Task('ซื้ออุปกรณ์ทำสื่อ', 'ภายในวันพุธ · งบผูกไว้',
      tag: 'งบ ฿500', tagBg: Color(0x33D8A93F), tagColor: Color(0xFF7A5A1B), budget: 500),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _spent = 0;
  final List<bool> _done = [false, false, false];
  bool _habit = false;
  int? _askingBudget;
  bool _showDone = false;
  Timer? _timer;

  static const int _weekBase = 1180;
  static const int _weekBudget = 2500;
  static const int _target = 320;

  @override
  void initState() {
    super.initState();
    final step = (_target / 22).ceil();
    _timer = Timer.periodic(const Duration(milliseconds: 45), (t) {
      setState(() => _spent = (_spent + step).clamp(0, _target));
      if (_spent >= _target) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle(int i) {
    final wasDone = _done[i];
    setState(() {
      _done[i] = !wasDone;
      if (!wasDone && _tasks[i].budget != null) _askingBudget = i;
    });
  }

  List<int> get _pending => List.generate(3, (i) => i).where((i) => !_done[i]).toList();
  List<int> get _doneList => List.generate(3, (i) => i).where((i) => _done[i]).toList();
  int get _weekSpent => _weekBase + _spent;
  int get _pct => (_weekSpent / _weekBudget * 100).round().clamp(0, 100);
  bool get _overPace => _pct > 62;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Center(child: _buildPhone()),
    );
  }

  // ── Phone shell ──────────────────────────────────────────────────────────
  Widget _buildPhone() {
    return Container(
      width: 328,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF2C3329), Color(0xFF14180F)],
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .95), blurRadius: 90, offset: const Offset(0, 46))],
        border: Border.all(color: _kGold.withValues(alpha: .18)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: SizedBox(
          height: 648,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [_kSurface, Color(0xFFEBE3CD)]),
            ),
            child: Stack(children: [
              _buildMain(),
              if (_showDone) _buildDonePanel(),
              if (_askingBudget != null) _buildBudgetSheet(),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Main content ─────────────────────────────────────────────────────────
  Widget _buildMain() {
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _header(),
            const SizedBox(height: 18),
            _spendingCard(),
            const SizedBox(height: 24),
            _label('งานที่เหลือวันนี้'),
            const SizedBox(height: 12),
            ..._pending.map(_taskCard),
            if (_pending.isEmpty) _allDoneCard(),
            const SizedBox(height: 4),
            _habitCard(),
          ]),
        ),
      ),
      _inputBar(),
    ]);
  }

  // ── Header ───────────────────────────────────────────────────────────────
  Widget _header() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('จันทร์ 31 ส.ค.', style: TextStyle(fontFamily: _kMono, fontSize: 10.5, letterSpacing: 2, color: _kGoldDark, fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        Text('วันนี้เหลือ ${_pending.length} งาน', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _kTextDark, letterSpacing: -.2)),
      ]),
      GestureDetector(
        onTap: () => setState(() => _showDone = true),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: _kGreen.withValues(alpha: .14),
            border: Border.all(color: _kGreen.withValues(alpha: .28)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 13, height: 13,
              decoration: BoxDecoration(color: _kGreen, borderRadius: BorderRadius.circular(4)),
              child: const Center(child: Icon(Icons.check, size: 9, color: Color(0xFFFBF8F0))),
            ),
            const SizedBox(width: 6),
            Text('เสร็จแล้ว ${_doneList.length}', style: const TextStyle(fontFamily: _kMono, fontSize: 10.5, fontWeight: FontWeight.w600, color: _kGreenDark)),
          ]),
        ),
      ),
    ]);
  }

  // ── Spending card ─────────────────────────────────────────────────────────
  Widget _spendingCard() {
    final left = (_weekBudget - _weekSpent).clamp(0, _weekBudget);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1E241B), Color(0xFF0E120C)]),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .95), blurRadius: 44, offset: const Offset(0, 26))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('ใช้วันนี้', style: TextStyle(fontFamily: _kMono, fontSize: 10.5, letterSpacing: 2, color: Color(0xFFE7D3A5), fontWeight: FontWeight.w600)),
          Text('งบสัปดาห์ ฿$_weekBudget', style: TextStyle(fontFamily: _kMono, fontSize: 10.5, color: _kCream.withValues(alpha: .5))),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFFF1EAD9), Color(0xFFF7DF9E), Color(0xFFD8A93F)],
            ).createShader(b),
            child: Text('฿$_spent', style: const TextStyle(fontFamily: _kMono, fontSize: 52, fontWeight: FontWeight.w600, height: .9, letterSpacing: -1.3, color: Colors.white)),
          ),
          const SizedBox(width: 11),
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text(_overPace ? 'เร็วกว่างบ' : 'อยู่ในงบ',
              style: TextStyle(fontFamily: _kMono, fontSize: 11.5, color: _overPace ? const Color(0xFFE8A08C) : const Color(0xFFC0D8C4))),
          ),
        ]),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 6,
            child: Stack(children: [
              Container(color: _kCream.withValues(alpha: .14)),
              FractionallySizedBox(
                widthFactor: _pct / 100,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_kGoldDark, _kGoldLight]),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [BoxShadow(color: _kGold.withValues(alpha: .9), blurRadius: 12)],
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Text('เหลือในงบ ฿$left', style: TextStyle(fontFamily: _kMono, fontSize: 10, color: _kCream.withValues(alpha: .42))),
      ]),
    );
  }

  // ── Task card ─────────────────────────────────────────────────────────────
  Widget _taskCard(int i) {
    final t = _tasks[i];
    return GestureDetector(
      onTap: () => _toggle(i),
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
        decoration: BoxDecoration(
          color: _kSurfaceLight.withValues(alpha: .95),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kTextDark.withValues(alpha: .09)),
          boxShadow: [BoxShadow(color: _kTextDark.withValues(alpha: .9), blurRadius: 26, offset: const Offset(0, 14), spreadRadius: -22)],
        ),
        child: Row(children: [
          Container(
            width: 23, height: 23,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kTextDark.withValues(alpha: .5), width: 1.8),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: _kTextDark, height: 1.35)),
            const SizedBox(height: 5),
            Text(t.meta, style: TextStyle(fontFamily: _kMono, fontSize: 10.5, color: t.warn ? _kRed : _kTextDark.withValues(alpha: .5))),
          ])),
          if (t.tag != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: t.tagBg, borderRadius: BorderRadius.circular(999)),
              child: Text(t.tag!, style: TextStyle(fontFamily: _kMono, fontSize: 9.5, fontWeight: FontWeight.w700, color: t.tagColor)),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _allDoneCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: _kGreen.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kGreen.withValues(alpha: .35)),
      ),
      child: const Column(children: [
        Text('เคลียร์งานวันนี้ครบแล้ว', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _kGreenDark), textAlign: TextAlign.center),
        SizedBox(height: 6),
        Text('ดูรายการที่เสร็จได้จากปุ่มมุมบนขวา', style: TextStyle(fontFamily: _kMono, fontSize: 10.5, color: Color(0x73202920)), textAlign: TextAlign.center),
      ]),
    );
  }

  // ── Habit card ────────────────────────────────────────────────────────────
  Widget _habitCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xE6DCE7DC), Color(0x7FDCE7DC)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kGreen.withValues(alpha: .25)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => setState(() => _habit = !_habit),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.elasticOut,
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _habit ? _kGreen : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kGreen, width: 1.8),
              boxShadow: _habit ? [BoxShadow(color: _kGreen.withValues(alpha: .95), blurRadius: 16, offset: const Offset(0, 8))] : [],
            ),
            child: Center(child: Text(_habit ? '✓' : '3',
              style: TextStyle(fontFamily: _kMono, fontSize: 13, fontWeight: FontWeight.w700, color: _habit ? _kSurfaceLight : _kGreenDark))),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ออกกำลังกาย 15 นาที', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _kTextDark)),
          const SizedBox(height: 4),
          Text(_habit ? '4 วันติด · รักษาสถิติไว้แล้ว' : '3 วันติด · พลาดไปแล้ว 1 วัน',
            style: const TextStyle(fontFamily: _kMono, fontSize: 10.5, color: _kGreenDark)),
        ])),
      ]),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────
  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: BoxDecoration(
        color: _kSurfaceLight.withValues(alpha: .96),
        border: Border(top: BorderSide(color: _kTextDark.withValues(alpha: .1))),
        boxShadow: [BoxShadow(color: _kTextDark.withValues(alpha: .9), blurRadius: 26, offset: const Offset(0, -12), spreadRadius: -20)],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_kSurface, Color(0xFFEBE3CD)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kGold.withValues(alpha: .35)),
        ),
        child: Row(children: [
          const Text('›', style: TextStyle(fontFamily: _kMono, fontSize: 13, color: _kGoldDark, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Expanded(child: Text('พิมพ์งานหรือรายจ่าย…', style: TextStyle(fontSize: 13.5, color: _kTextDark.withValues(alpha: .45)))),
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              gradient: const SweepGradient(startAngle: 3.5, colors: [_kGoldDark, _kGoldLight, _kGold, _kGoldDark]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: _kGoldDark.withValues(alpha: .95), blurRadius: 18, offset: const Offset(0, 10))],
            ),
            child: const Center(child: Text('+', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w300, color: Color(0xFF1A2018)))),
          ),
        ]),
      ),
    );
  }

  // ── Done panel ────────────────────────────────────────────────────────────
  Widget _buildDonePanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_kSurface, Color(0xFFEBE3CD)]),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _kTextDark.withValues(alpha: .1)))),
          child: Row(children: [
            GestureDetector(
              onTap: () => setState(() => _showDone = false),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: _kTextDark.withValues(alpha: .07), borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('‹', style: TextStyle(fontSize: 16, color: _kTextDark))),
              ),
            ),
            const SizedBox(width: 12),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('จันทร์ 31 ส.ค.', style: TextStyle(fontFamily: _kMono, fontSize: 10.5, letterSpacing: 2, color: _kGreenDark, fontWeight: FontWeight.w600)),
              SizedBox(height: 3),
              Text('งานที่เสร็จแล้ว', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _kTextDark)),
            ]),
          ]),
        ),
        Expanded(
          child: _doneList.isEmpty
              ? Center(child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
                  decoration: BoxDecoration(color: _kTextDark.withValues(alpha: .04), borderRadius: BorderRadius.circular(18), border: Border.all(color: _kTextDark.withValues(alpha: .18))),
                  child: Center(child: Text('ยังไม่มีงานที่เสร็จวันนี้', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _kTextDark.withValues(alpha: .5)))),
                ))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: _doneList.map((i) {
                    final t = _tasks[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 11),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: _kSurfaceLight.withValues(alpha: .95),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _kTextDark.withValues(alpha: .09)),
                        boxShadow: [BoxShadow(color: _kTextDark.withValues(alpha: .9), blurRadius: 26, offset: const Offset(0, 14), spreadRadius: -22)],
                      ),
                      child: Row(children: [
                        Container(
                          width: 23, height: 23,
                          decoration: BoxDecoration(color: _kGreen, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: _kGreen.withValues(alpha: .95), blurRadius: 14, offset: const Offset(0, 6))]),
                          child: const Center(child: Icon(Icons.check, size: 12, color: Color(0xFFFBF8F0))),
                        ),
                        const SizedBox(width: 13),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(t.title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: _kTextDark.withValues(alpha: .5), decoration: TextDecoration.lineThrough)),
                          const SizedBox(height: 5),
                          Text(t.meta, style: TextStyle(fontFamily: _kMono, fontSize: 10.5, color: _kTextDark.withValues(alpha: .42))),
                        ])),
                        GestureDetector(
                          onTap: () => setState(() => _done[i] = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                            decoration: BoxDecoration(color: _kRed.withValues(alpha: .1), border: Border.all(color: _kRed.withValues(alpha: .28)), borderRadius: BorderRadius.circular(999)),
                            child: const Text('ยกเลิก', style: TextStyle(fontFamily: _kMono, fontSize: 10.5, fontWeight: FontWeight.w600, color: _kRed)),
                          ),
                        ),
                      ]),
                    );
                  }).toList(),
                ),
        ),
      ]),
    );
  }

  // ── Budget bottom sheet ───────────────────────────────────────────────────
  Widget _buildBudgetSheet() {
    final taskBudget = _tasks[_askingBudget!].budget!;
    final amounts = [
      (taskBudget * 0.86).round(),
      taskBudget,
      (taskBudget * 1.12).round(),
    ];
    return GestureDetector(
      onTap: () => setState(() => _askingBudget = null),
      child: Container(
        color: const Color(0xFF0E120C).withValues(alpha: .55),
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFBF8F0), Color(0xFFF1EAD9)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _kTextDark.withValues(alpha: .18), borderRadius: BorderRadius.circular(999)))),
                const SizedBox(height: 18),
                Text('งานนี้ผูกงบไว้ ฿$taskBudget', style: const TextStyle(fontFamily: _kMono, fontSize: 10.5, letterSpacing: 2, color: _kGoldDark, fontWeight: FontWeight.w600)),
                const SizedBox(height: 7),
                const Text('ใช้ไปเท่าไหร่จริง', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _kTextDark)),
                const SizedBox(height: 5),
                Text('บันทึกเป็นรายจ่ายให้เลย ไม่ต้องกรอกใหม่ในโมดูลเงิน', style: TextStyle(fontSize: 12.5, height: 1.6, color: _kTextDark.withValues(alpha: .55))),
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
                        color: mid ? null : _kSurfaceLight.withValues(alpha: .95),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _kGold.withValues(alpha: .35)),
                        boxShadow: [BoxShadow(color: _kGoldDark.withValues(alpha: .9), blurRadius: 20, offset: const Offset(0, 10), spreadRadius: -14)],
                      ),
                      child: Center(child: Text('฿$amt', style: TextStyle(fontFamily: _kMono, fontSize: 15, fontWeight: FontWeight.w600, color: mid ? const Color(0xFF1A2018) : _kTextDark))),
                    ),
                  ));
                })),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => setState(() => _askingBudget = null),
                  child: Center(child: Text('ข้ามไปก่อน', style: TextStyle(fontSize: 12.5, color: _kTextDark.withValues(alpha: .45)))),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: TextStyle(fontFamily: _kMono, fontSize: 10, letterSpacing: 2.5, color: _kTextDark.withValues(alpha: .38), fontWeight: FontWeight.w500));
}
