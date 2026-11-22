import 'dart:async';
import 'package:flutter/material.dart';
import 'laundry.dart';
import 'models.dart';

class LaundryScreen extends StatefulWidget {
  const LaundryScreen({super.key});
  @override
  State<LaundryScreen> createState() => _LaundryScreenState();
}

class _LaundryScreenState extends State<LaundryScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    Laundry.changed.addListener(_refresh);
    Laundry.load();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _tick?.cancel();
    Laundry.changed.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() { if (mounted) setState(() {}); }

  static String _mmss(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final st = Laundry.status(now);
    final isSat = now.weekday == LaundrySettings.weekday;
    final round2 = st.round == 1;
    // ขั้นถัดไปที่จะเริ่มเมื่อกด (ตอนขั้นปัจจุบันครบเวลาแล้ว รอกด)
    final nextStep = st.phase == LaundryPhase.waitStep && st.pos + 1 < laundryRows.length ? laundryRows[st.pos + 1].$2 : null;
    final (headline, sub) = switch (st.phase) {
      LaundryPhase.idle => (isSat ? 'วันนี้วันซักผ้า 🧺' : 'ซักผ้า', 'เริ่มได้ทุกวัน กดตอนเปิดน้ำเข้าเครื่อง'),
      LaundryPhase.waitWaterOff => ('ปิดน้ำหรือยัง?', 'ครบ 5 นาทีแล้ว ปิดน้ำแล้วกดปุ่มด้านล่าง'),
      LaundryPhase.waitStep => ('${st.step?.label ?? ''}ครบแล้ว',
          nextStep == null ? 'กดเพื่อไปขั้นต่อไป' : 'กดเพื่อเริ่ม${nextStep.label} ${nextStep.minutes} นาที'),
      LaundryPhase.betweenRounds => ('ต่อรอบ 2', 'เปิดน้ำเข้า ใส่น้ำยาปรับผ้านุ่ม แล้วกดเริ่ม'),
      LaundryPhase.done => ('เสร็จแล้ว ✅', 'เอาผ้าไปตากได้เลย'),
      _ => (_mmss(st.left(now)), '${laundryRounds[st.round].name} · กำลัง${st.step?.label ?? ''}'),
    };
    final waiting = st.phase == LaundryPhase.waitWaterOff || st.phase == LaundryPhase.waitStep;
    return Scaffold(
      backgroundColor: kCBg,
      appBar: AppBar(
        backgroundColor: kCBg, elevation: 0,
        title: const Text('ซักผ้า', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCText)),
        actions: [
          IconButton(
            tooltip: 'ตั้งเวลา',
            icon: const Icon(Icons.tune_rounded, color: kCGoldDark),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LaundrySettingsScreen())),
          ),
          if (st.phase != LaundryPhase.idle)
            TextButton(
              onPressed: Laundry.reset,
              child: Text(st.phase == LaundryPhase.done ? 'เริ่มใหม่' : 'ยกเลิก',
                style: const TextStyle(color: kCGoldDark, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 32), children: [
        Center(child: Text(headline, style: TextStyle(
          fontSize: headline.contains(':') ? 56 : 28, fontWeight: FontWeight.w700,
          fontFamily: headline.contains(':') ? kMono : null,
          color: waiting ? kCRed : kCText))),
        const SizedBox(height: 6),
        Center(child: Text(sub, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: kCText.withValues(alpha: .55)))),
        const SizedBox(height: 24),
        if (st.phase == LaundryPhase.idle || st.phase == LaundryPhase.done)
          _bigButton('เริ่มปล่อยน้ำเข้า (5 นาที)', Icons.water_drop_outlined, kCGreen, Laundry.startFill),
        if (st.phase == LaundryPhase.betweenRounds)
          _bigButton('เริ่มรอบ 2 — ปล่อยน้ำเข้า (5 นาที)', Icons.water_drop_outlined, kCGreen, Laundry.startFill),
        if (st.phase == LaundryPhase.filling || st.phase == LaundryPhase.waitWaterOff)
          _bigButton(round2 ? 'ปิดน้ำแล้ว — เริ่มปั่นกับน้ำยา' : 'ปิดน้ำแล้ว — เริ่มแช่ผ้า',
            Icons.check_rounded, st.phase == LaundryPhase.waitWaterOff ? kCRed : kCSurf, Laundry.confirmWaterOff),
        if (st.phase == LaundryPhase.waitStep)
          _bigButton(nextStep == null ? 'ไปขั้นต่อไป' : 'เริ่ม${nextStep.label} (${nextStep.minutes} นาที)',
            Icons.play_arrow_rounded, kCRed, Laundry.confirmNextStep),
        const SizedBox(height: 24),
        for (final (i, (r, s)) in laundryRows.indexed) ...[
          if (i == 0 || laundryRows[i - 1].$1 != r)
            Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8, top: i == 0 ? 0 : 10),
              child: Text(laundryRounds[r].name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCGoldDark)),
            ),
          _stepRow(i, s, st, now),
        ],
        const SizedBox(height: 16),
        Text('กดเริ่มเองได้ทุกวัน (ปุ่ม 🧺 มุมบนของหน้าแรก) · ทุก${laundryDayLabel()} มีแจ้งเตือนวันซักผ้าด้วย · '
            'ทุกขั้นครบเวลาจะเตือนแล้ว "หยุดรอให้กดก่อน" ไม่เดินหน้าเอง — ปล่อยน้ำเข้าครบกด "ปิดน้ำแล้ว" ขั้นอื่นกด "ไปขั้นต่อไป" '
            '(ถ้ายังไม่กดจะเตือนซ้ำทุก ${LaundrySettings.nagEvery} นาที) · จบรอบ 1 กด "เริ่มรอบ 2" ในแจ้งเตือนได้ · '
            'ปรับเวลาทุกขั้นได้ที่ปุ่ม ⚙ มุมขวาบน',
          style: TextStyle(fontSize: 11.5, height: 1.5, color: kCText.withValues(alpha: .4))),
      ]),
    );
  }

  Widget _bigButton(String label, IconData icon, Color bg, Future<void> Function() onTap) => FilledButton.icon(
    style: FilledButton.styleFrom(backgroundColor: bg, padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    onPressed: onTap,
    icon: Icon(icon, color: Colors.white),
    label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
  );

  // i = ลำดับใน laundryRows · ก่อนขั้นปัจจุบัน = เสร็จ (ขั้นที่ครบเวลาแล้วรอกด ก็ถือว่าเสร็จแล้ว)
  Widget _stepRow(int i, LaundryStep s, LaundryStatus st, DateTime now) {
    final stepDone = (st.phase == LaundryPhase.waitWaterOff || st.phase == LaundryPhase.waitStep) && i == st.pos;
    final done = i < st.pos || stepDone;
    final active = i == st.pos && !stepDone && st.endsAt != null;
    final next = i == st.pos && st.phase == LaundryPhase.betweenRounds;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: active || next ? kCGold.withValues(alpha: .1) : kCSurf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: active || next ? kCGoldDark.withValues(alpha: .5) : kCText.withValues(alpha: .07)),
      ),
      child: Row(children: [
        Icon(done ? Icons.check_circle_rounded : active ? Icons.timelapse_rounded : Icons.radio_button_unchecked_rounded,
          size: 18, color: done ? kCGreenDk : kCText.withValues(alpha: active ? .8 : .35)),
        const SizedBox(width: 10),
        Expanded(child: Text(s.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
          color: kCText.withValues(alpha: done ? .45 : .9)))),
        Text(active ? _mmss(st.left(now)) : '${s.minutes} นาที',
          style: TextStyle(fontSize: 12.5, fontFamily: active ? kMono : null, color: kCText.withValues(alpha: .5))),
      ]),
    );
  }
}

// การ์ดบนแท็บงาน: วันซักผ้า (ค่าเริ่มต้นเสาร์) หรือกำลังซักอยู่ · นับเวลาเองทุก 15 วิ (หน้าแรกไม่ได้ rebuild ตามเวลา)
class LaundryCard extends StatefulWidget {
  final VoidCallback onTap;
  const LaundryCard({super.key, required this.onTap});
  @override
  State<LaundryCard> createState() => _LaundryCardState();
}

class _LaundryCardState extends State<LaundryCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    Laundry.changed.addListener(_refresh);
    _tick = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  @override
  void dispose() {
    _tick?.cancel();
    Laundry.changed.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final st = Laundry.status(now);
    if (st.phase == LaundryPhase.idle && now.weekday != LaundrySettings.weekday) return const SizedBox.shrink();
    final mins = (st.left(now).inSeconds / 60).ceil();
    final text = switch (st.phase) {
      LaundryPhase.idle => 'วันนี้วันซักผ้า · กดเพื่อเริ่มปล่อยน้ำเข้า',
      LaundryPhase.waitWaterOff => 'ปิดน้ำหรือยัง? กดเพื่อยืนยัน',
      LaundryPhase.waitStep => '${st.step?.label ?? ''}ครบแล้ว · กดเพื่อไปขั้นต่อไป',
      LaundryPhase.betweenRounds => 'ต่อรอบ 2 · เปิดน้ำ ใส่น้ำยาปรับผ้านุ่ม แล้วกดเริ่ม',
      LaundryPhase.done => 'ซักผ้าเสร็จแล้ว ✅',
      _ => '${st.round == 1 ? 'รอบ 2 · ' : ''}กำลัง${st.step?.label ?? ''} · อีก $mins นาที',
    };
    final alert = st.phase == LaundryPhase.waitWaterOff || st.phase == LaundryPhase.waitStep || st.phase == LaundryPhase.betweenRounds;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: alert ? kCRed.withValues(alpha: .15) : kCSurf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: alert ? kCRed.withValues(alpha: .5) : kCText.withValues(alpha: .08)),
        ),
        child: Row(children: [
          Icon(Icons.local_laundry_service_outlined, size: 18, color: kCText.withValues(alpha: .7)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: kCText.withValues(alpha: .9)))),
          Icon(Icons.chevron_right_rounded, size: 18, color: kCText.withValues(alpha: .35)),
        ]),
      ),
    );
  }
}

// ── ตั้งเวลาซักผ้า: นาทีของทุกขั้น · ถามปิดน้ำซ้ำทุกกี่นาที · วัน/เวลาเตือนวันซักผ้า ──────────
class LaundrySettingsScreen extends StatefulWidget {
  const LaundrySettingsScreen({super.key});
  @override
  State<LaundrySettingsScreen> createState() => _LaundrySettingsScreenState();
}

class _LaundrySettingsScreenState extends State<LaundrySettingsScreen> {
  void _changed(VoidCallback f) {
    setState(f);
    Laundry.settingsChanged();
  }

  void _setStep(LaundryStep s, int v) => _changed(() {
    if (v == s.defaultMinutes) {
      LaundrySettings.minutes.remove(s.key);
    } else {
      LaundrySettings.minutes[s.key] = v;
    }
  });

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: LaundrySettings.hour, minute: LaundrySettings.minute),
    );
    if (t != null) _changed(() { LaundrySettings.hour = t.hour; LaundrySettings.minute = t.minute; });
  }

  void _resetAll() => _changed(() {
    LaundrySettings.fromJson({});
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCBg,
      appBar: AppBar(
        backgroundColor: kCBg, elevation: 0,
        title: const Text('ตั้งเวลาซักผ้า', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCText)),
        actions: [
          TextButton(onPressed: _resetAll,
            child: const Text('คืนค่าเริ่มต้น', style: TextStyle(color: kCGoldDark, fontWeight: FontWeight.w600))),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
        for (final (i, (r, s)) in laundryRows.indexed) ...[
          if (i == 0 || laundryRows[i - 1].$1 != r) _label(laundryRounds[r].name, top: i == 0 ? 0 : 12),
          _stepper(s.label, s.minutes, (v) => _setStep(s, v), max: 120,
            changed: s.minutes != s.defaultMinutes),
        ],
        _label('ระหว่างรอปิดน้ำ', top: 12),
        _stepper('ถามซ้ำว่าปิดน้ำหรือยัง ทุก', LaundrySettings.nagEvery,
          (v) => _changed(() => LaundrySettings.nagEvery = v), max: 30,
          changed: LaundrySettings.nagEvery != LaundrySettings.defaultNag),
        _label('แจ้งเตือนวันซักผ้า (ทุกสัปดาห์)', top: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var d = 1; d <= 7; d++)
            ChoiceChip(
              label: Text(laundryWeekdays[d - 1]),
              selected: LaundrySettings.weekday == d,
              onSelected: (_) => _changed(() => LaundrySettings.weekday = d),
            ),
        ]),
        const SizedBox(height: 10),
        _box(Row(children: [
          const Expanded(child: Text('เวลาแจ้งเตือน', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kCText))),
          TextButton(onPressed: _pickTime, child: Text(
            '${LaundrySettings.hour.toString().padLeft(2, '0')}:${LaundrySettings.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 16, fontFamily: kMono, fontWeight: FontWeight.w700, color: kCText))),
        ])),
        const SizedBox(height: 14),
        Text('ปรับระหว่างกำลังซักอยู่ก็ได้ ขั้นที่ยังไม่ครบจะนับตามเวลาใหม่ทันที',
          style: TextStyle(fontSize: 11.5, height: 1.5, color: kCText.withValues(alpha: .4))),
      ]),
    );
  }

  Widget _label(String t, {double top = 0}) => Padding(
    padding: EdgeInsets.only(left: 4, bottom: 8, top: top),
    child: Text(t, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCGoldDark)),
  );

  Widget _box(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
    decoration: BoxDecoration(
      color: kCSurf, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kCText.withValues(alpha: .07)),
    ),
    child: child,
  );

  Widget _stepper(String label, int value, void Function(int) onSet, {required int max, bool changed = false}) => _box(Row(children: [
    Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kCText))),
    IconButton(
      onPressed: value > 1 ? () => onSet(value - 1) : null,
      icon: const Icon(Icons.remove_rounded, size: 18), color: kCText,
    ),
    SizedBox(width: 64, child: Text('$value นาที', textAlign: TextAlign.center,
      style: TextStyle(fontSize: 13.5, fontFamily: kMono, fontWeight: FontWeight.w700,
        color: changed ? kCGreenDk : kCText))),
    IconButton(
      onPressed: value < max ? () => onSet(value + 1) : null,
      icon: const Icon(Icons.add_rounded, size: 18), color: kCText,
    ),
  ]));
}
