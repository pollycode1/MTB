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
    final (headline, sub) = switch (st.phase) {
      LaundryPhase.idle => (isSat ? 'วันนี้วันซักผ้า 🧺' : 'ซักผ้า', 'กดเริ่มเมื่อเปิดน้ำเข้าเครื่อง'),
      LaundryPhase.filling => (_mmss(st.left(now)), 'กำลังปล่อยน้ำเข้า'),
      LaundryPhase.waitWaterOff => ('ปิดน้ำหรือยัง?', 'ครบ 5 นาทีแล้ว ปิดน้ำแล้วกดปุ่มด้านล่าง'),
      LaundryPhase.soak => (_mmss(st.left(now)), 'กำลังแช่ผ้า'),
      LaundryPhase.spin => (_mmss(st.left(now)), 'กำลังปั่น'),
      LaundryPhase.drain => (_mmss(st.left(now)), 'กำลังปล่อยน้ำออก'),
      LaundryPhase.done => ('เสร็จแล้ว ✅', 'เอาผ้าไปตากได้เลย'),
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
        Center(child: Text(sub, style: TextStyle(fontSize: 13.5, color: kCText.withValues(alpha: .55)))),
        const SizedBox(height: 24),
        if (st.phase == LaundryPhase.idle || st.phase == LaundryPhase.done)
          _bigButton('เริ่มปล่อยน้ำเข้า (5 นาที)', Icons.water_drop_outlined, kCGreen, Laundry.startFill),
        if (st.phase == LaundryPhase.filling || waiting)
          _bigButton('ปิดน้ำแล้ว — เริ่มแช่ผ้า', Icons.check_rounded, waiting ? kCRed : kCSurf, Laundry.confirmWaterOff),
        const SizedBox(height: 24),
        _stepRow(1, laundryFill, st, now),
        for (final (i, s) in laundryWash.indexed) _stepRow(i + 2, s, st, now),
        const SizedBox(height: 16),
        Text('ทุกวันเสาร์ 0$laundryHour:00 มีแจ้งเตือนวันซักผ้า · แต่ละขั้นครบเวลาจะแจ้งเตือน '
            'ตอนปล่อยน้ำเข้าครบกด "ปิดน้ำแล้ว" ในแจ้งเตือนได้เลย (ถ้ายังไม่กดจะถามซ้ำทุก 2 นาที)',
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

  Widget _stepRow(int n, LaundryStep s, LaundryStatus st, DateTime now) {
    final order = LaundryPhase.values;
    final active = st.phase == s.phase;
    // ขั้นปล่อยน้ำเข้าถือว่าเสร็จตั้งแต่รอปิดน้ำ
    final done = order.indexOf(st.phase) > order.indexOf(s.phase) && st.phase != LaundryPhase.idle;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: active ? kCGold.withValues(alpha: .1) : kCSurf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: active ? kCGoldDark.withValues(alpha: .5) : kCText.withValues(alpha: .07)),
      ),
      child: Row(children: [
        Icon(done ? Icons.check_circle_rounded : active ? Icons.timelapse_rounded : Icons.radio_button_unchecked_rounded,
          size: 18, color: done ? kCGreenDk : kCText.withValues(alpha: active ? .8 : .35)),
        const SizedBox(width: 10),
        Expanded(child: Text('$n. ${s.label}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
          color: kCText.withValues(alpha: done ? .45 : .9)))),
        Text(active ? _mmss(st.left(now)) : '${s.minutes} นาที',
          style: TextStyle(fontSize: 12.5, fontFamily: active ? kMono : null, color: kCText.withValues(alpha: .5))),
      ]),
    );
  }
}
