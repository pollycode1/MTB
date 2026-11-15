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
    final isSat = now.weekday == DateTime.saturday;
    final round2 = st.round == 1;
    final (headline, sub) = switch (st.phase) {
      LaundryPhase.idle => (isSat ? 'วันนี้วันซักผ้า 🧺' : 'ซักผ้า', 'เริ่มได้ทุกวัน กดตอนเปิดน้ำเข้าเครื่อง'),
      LaundryPhase.waitWaterOff => ('ปิดน้ำหรือยัง?', 'ครบ 5 นาทีแล้ว ปิดน้ำแล้วกดปุ่มด้านล่าง'),
      LaundryPhase.betweenRounds => ('ต่อรอบ 2', 'เปิดน้ำเข้า ใส่น้ำยาปรับผ้านุ่ม แล้วกดเริ่ม'),
      LaundryPhase.done => ('เสร็จแล้ว ✅', 'เอาผ้าไปตากได้เลย'),
      _ => (_mmss(st.left(now)), '${laundryRounds[st.round].name} · กำลัง${st.step?.label ?? ''}'),
    };
    final waiting = st.phase == LaundryPhase.waitWaterOff;
    return Scaffold(
      backgroundColor: kCBg,
      appBar: AppBar(
        backgroundColor: kCBg, elevation: 0,
        title: const Text('ซักผ้า', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCText)),
        actions: [
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
        if (st.phase == LaundryPhase.filling || waiting)
          _bigButton(round2 ? 'ปิดน้ำแล้ว — เริ่มปั่นกับน้ำยา' : 'ปิดน้ำแล้ว — เริ่มแช่ผ้า',
            Icons.check_rounded, waiting ? kCRed : kCSurf, Laundry.confirmWaterOff),
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
        Text('กดเริ่มเองได้ทุกวัน (ปุ่ม 🧺 มุมบนของหน้าแรก) · ทุกวันเสาร์ 0$laundryHour:00 มีแจ้งเตือนวันซักผ้าด้วย · แต่ละขั้นครบเวลาจะแจ้งเตือน '
            'ตอนปล่อยน้ำเข้าครบกด "ปิดน้ำแล้ว" ในแจ้งเตือนได้เลย (ถ้ายังไม่กดจะถามซ้ำทุก 2 นาที) · จบรอบ 1 กด "เริ่มรอบ 2" ในแจ้งเตือนได้',
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

  // i = ลำดับใน laundryRows · ก่อนขั้นปัจจุบัน = เสร็จ (ขั้นปล่อยน้ำเข้าถือว่าเสร็จตั้งแต่รอปิดน้ำ)
  Widget _stepRow(int i, LaundryStep s, LaundryStatus st, DateTime now) {
    final fillDone = st.phase == LaundryPhase.waitWaterOff && i == st.pos;
    final done = i < st.pos || fillDone;
    final active = i == st.pos && !fillDone && st.endsAt != null;
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

// การ์ดบนแท็บงาน: วันเสาร์ หรือกำลังซักอยู่ · นับเวลาเองทุก 15 วิ (หน้าแรกไม่ได้ rebuild ตามเวลา)
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
    if (st.phase == LaundryPhase.idle && now.weekday != DateTime.saturday) return const SizedBox.shrink();
    final mins = (st.left(now).inSeconds / 60).ceil();
    final text = switch (st.phase) {
      LaundryPhase.idle => 'วันนี้วันซักผ้า · กดเพื่อเริ่มปล่อยน้ำเข้า',
      LaundryPhase.waitWaterOff => 'ปิดน้ำหรือยัง? กดเพื่อยืนยัน',
      LaundryPhase.betweenRounds => 'ต่อรอบ 2 · เปิดน้ำ ใส่น้ำยาปรับผ้านุ่ม แล้วกดเริ่ม',
      LaundryPhase.done => 'ซักผ้าเสร็จแล้ว ✅',
      _ => '${st.round == 1 ? 'รอบ 2 · ' : ''}กำลัง${st.step?.label ?? ''} · อีก $mins นาที',
    };
    final alert = st.phase == LaundryPhase.waitWaterOff || st.phase == LaundryPhase.betweenRounds;
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
