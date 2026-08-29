import 'package:flutter/material.dart';
import 'models.dart';

class HabitsScreen extends StatefulWidget {
  final List<HabitItem> habits;
  const HabitsScreen({super.key, required this.habits});
  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final _addCtrl = TextEditingController();

  @override
  void dispose() { _addCtrl.dispose(); super.dispose(); }

  void _toggle(HabitItem h) {
    setState(() {
      if (!h.doneToday) {
        h.doneToday = true;
        h.streak++;
      } else {
        h.doneToday = false;
        if (h.streak > 0) h.streak--;
      }
    });
  }

  void _add() {
    final t = _addCtrl.text.trim();
    if (t.isEmpty) return;
    setState(() => widget.habits.add(HabitItem(title: t)));
    _addCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final done   = widget.habits.where((h) => h.doneToday).length;
    final total  = widget.habits.length;
    return Scaffold(
      backgroundColor: kCBg,
      body: Column(children: [
        // header
        Container(
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 16),
          decoration: BoxDecoration(
            color: kCSurf,
            border: Border(bottom: BorderSide(color: kCText.withValues(alpha: .09))),
          ),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(width: 34, height: 34,
                decoration: BoxDecoration(color: kCText.withValues(alpha: .07), borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('‹', style: TextStyle(fontSize: 20, color: kCText)))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('นิสัยประจำวัน', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kCText)),
              if (total > 0)
                Text('ทำแล้ว $done/$total วันนี้', style: TextStyle(fontSize: 10.5, color: kCGreenDk, fontWeight: FontWeight.w600)),
            ])),
          ]),
        ),

        // list
        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
          ...widget.habits.map((h) => _habitTile(h)),
        ])),

        // add bar
        Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 16),
          decoration: BoxDecoration(
            color: kCSurf.withValues(alpha: .97),
            border: Border(top: BorderSide(color: kCText.withValues(alpha: .09))),
          ),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _addCtrl,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _add(),
              style: const TextStyle(fontSize: 14.5, color: kCText),
              decoration: InputDecoration(
                hintText: 'เพิ่มนิสัยใหม่…',
                hintStyle: TextStyle(color: kCText.withValues(alpha: .35), fontSize: 14),
                filled: true, fillColor: kCBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kCGreenDk, width: 1.5)),
              ),
            )),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _add,
              child: Container(width: 44, height: 44,
                decoration: BoxDecoration(color: kCGreen, borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: kCGreen.withValues(alpha: .5), blurRadius: 14, offset: const Offset(0, 6))]),
                child: const Icon(Icons.add, color: Colors.white, size: 22)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _habitTile(HabitItem h) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: h.doneToday ? kCGreen.withValues(alpha: .08) : kCSurf.withValues(alpha: .95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: h.doneToday ? kCGreen.withValues(alpha: .35) : kCText.withValues(alpha: .08)),
        boxShadow: [BoxShadow(color: kCText.withValues(alpha: .7), blurRadius: 16, offset: const Offset(0, 7), spreadRadius: -14)],
      ),
      child: Row(children: [
        // toggle button
        GestureDetector(
          onTap: () => _toggle(h),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: h.doneToday ? kCGreen : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kCGreen, width: 1.8),
              boxShadow: [BoxShadow(color: h.doneToday ? kCGreen.withValues(alpha: .6) : Colors.transparent, blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: Center(child: Text(h.doneToday ? '✓' : '${h.streak}',
              style: TextStyle(fontFamily: kMono, fontSize: 13, fontWeight: FontWeight.w700,
                color: h.doneToday ? Colors.white : kCGreenDk))),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(h.title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: kCText)),
          const SizedBox(height: 3),
          Text(
            h.doneToday ? '${h.streak} วันติด · ทำแล้ววันนี้' : '${h.streak} วันติด · ยังไม่ได้ทำ',
            style: const TextStyle(fontSize: 10.5, color: kCGreenDk),
          ),
        ])),
        // delete
        GestureDetector(
          onTap: () => setState(() => widget.habits.remove(h)),
          child: Padding(padding: const EdgeInsets.all(6),
            child: Icon(Icons.close, size: 16, color: kCText.withValues(alpha: .28))),
        ),
      ]),
    );
  }
}
