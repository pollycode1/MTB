part of 'home_screen.dart';

// แผนเช้า: วันละครั้งตอนเปิดแอพ เลือกงานโฟกัส + กบของวัน (เก็บใน plannedFor / isFrog)
extension _MorningPlan on _HomeScreenState {
  String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  bool _isPlannedToday(TaskItem t) {
    final p = t.plannedFor, n = DateTime.now();
    return p != null && p.year == n.year && p.month == n.month && p.day == n.day;
  }

  Future<void> _maybeShowMorningPlan() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('last_plan_date') == _dayKey(DateTime.now())) return;
    if (_pendingIdx.isEmpty || !mounted) return;
    _openMorningPlan();
  }

  void _openMorningPlan() {
    final cands = _rankForFocus(_pendingIdx);
    final planned = cands.where((i) => _isPlannedToday(_tasks[i])).toList();
    final picked = <int>{...(planned.isNotEmpty ? planned : cands.take(5))};
    int? frog;
    for (final i in cands) {
      if (_tasks[i].isFrog) frog = i;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .85),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _cText.withValues(alpha: .18), borderRadius: BorderRadius.circular(999)))),
          const SizedBox(height: 16),
          const Text('วางแผนวันนี้', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _cText)),
          const SizedBox(height: 4),
          Text('ติ๊กงานที่จะทำวันนี้ · กด 🐸 เลือกงานที่ไม่อยากทำที่สุด ทำเป็นอย่างแรก',
            style: TextStyle(fontSize: 11.5, color: _cText.withValues(alpha: .5))),
          const SizedBox(height: 12),
          Flexible(child: ListView(shrinkWrap: true, children: [
            for (final i in cands)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setS(() {
                      if (!picked.remove(i)) picked.add(i);
                      if (frog == i && !picked.contains(i)) frog = null;
                    }),
                    child: Row(children: [
                      Icon(picked.contains(i) ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        size: 22, color: picked.contains(i) ? _cGreen : _cText.withValues(alpha: .4)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_tasks[i].title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, color: _cText))),
                    ]),
                  )),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setS(() { picked.add(i); frog = frog == i ? null : i; }),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Opacity(opacity: frog == i ? 1 : .25, child: const Text('🐸', style: TextStyle(fontSize: 18))),
                    ),
                  ),
                ]),
              ),
          ])),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              final now = DateTime.now();
              final day = DateTime(now.year, now.month, now.day);
              _set(() {
                for (final i in cands) {
                  final t = _tasks[i];
                  t.plannedFor = picked.contains(i) ? day : null;
                  t.isFrog = frog == i;
                }
              });
              _saveTasks();
              _updateWidget();
              SharedPreferences.getInstance().then((p) => p.setString('last_plan_date', _dayKey(now)));
              Navigator.pop(ctx);
            },
            child: Container(
              width: double.infinity, height: 48,
              decoration: BoxDecoration(color: _cSurf, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cText.withValues(alpha: .25))),
              child: Center(child: Text('เริ่มวัน · ${picked.length} งาน', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _cText))),
            ),
          ),
        ]),
      )),
    );
  }
}
