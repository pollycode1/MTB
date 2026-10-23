part of 'home_screen.dart';

// แผนเช้า: วันละครั้งตอนเปิดแอพ เลือกงานโฟกัส + กบของวัน (เก็บใน plannedFor / isFrog)
// งานที่ถูกเลื่อนครบ kStuckAt ครั้ง ต้องตัดสินใจก่อนเริ่มวัน: ทำวันนี้ / แตกย่อย / ลบ
const kStuckAt = 3;

extension _MorningPlan on _HomeScreenState {
  String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  bool _isPlannedToday(TaskItem t) {
    final p = t.plannedFor, n = DateTime.now();
    return p != null && p.year == n.year && p.month == n.month && p.day == n.day;
  }

  // ถามเวลาที่ใช้จริงตอนกดเสร็จ (เฉพาะงานที่ตั้งเวลาประมาณไว้) ไว้เทียบในสรุปสัปดาห์
  void _askActualMinutes(TaskItem t) {
    const options = [10, 15, 30, 45, 60, 90, 120, 180];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ใช้เวลาจริงเท่าไร?', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _cText)),
          const SizedBox(height: 4),
          Text('${t.title} · คาดไว้ ${t.estimateMin} นาที', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: _cText.withValues(alpha: .5))),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in options)
              GestureDetector(
                onTap: () {
                  _set(() => t.actualMin = m);
                  _saveTasks();
                  Navigator.pop(ctx);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: _cSurf, borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _cText.withValues(alpha: .2))),
                  child: Text('$m นาที', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _cText)),
                ),
              ),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text('ข้าม', style: TextStyle(fontSize: 13, color: _cText.withValues(alpha: .45))),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _maybeShowMorningPlan() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('last_plan_date') == _dayKey(DateTime.now())) return;
    if (_pendingIdx.isEmpty || !mounted) return;
    _openMorningPlan();
  }

  void _openMorningPlan() {
    final items = _rankForFocus(_pendingIdx).map((i) => _tasks[i]).toList();
    final planned = items.where(_isPlannedToday).toList();
    final picked = <TaskItem>{...(planned.isNotEmpty ? planned : items.take(5))};
    TaskItem? frog;
    for (final t in items) {
      if (t.isFrog) frog = t;
    }
    final decided = <TaskItem, String>{}; // 'do' | 'split' | 'drop'
    final stuck = items.where((t) => t.postponeCount >= kStuckAt).toList();
    for (final t in stuck) {
      picked.add(t); // ค่าเริ่มต้นของงานที่ติด: ยังไม่ตัดสินใจ แต่ติ๊กไว้ให้เห็น
    }

    Widget chip(String label, VoidCallback onTap, {bool danger = false}) => GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8, top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: (danger ? _cRed : _cText).withValues(alpha: .08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: (danger ? _cRed : _cText).withValues(alpha: .3)),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: danger ? _cRed : _cText)),
      ),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final ready = stuck.every(decided.containsKey);
        final count = picked.where((t) => decided[t] != 'drop').length;
        return Container(
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
              for (final t in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setS(() {
                          if (!picked.remove(t)) picked.add(t);
                          if (frog == t && !picked.contains(t)) frog = null;
                        }),
                        child: Row(children: [
                          Icon(picked.contains(t) ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                            size: 22, color: picked.contains(t) ? _cGreen : _cText.withValues(alpha: .4)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, color: _cText,
                              decoration: decided[t] == 'drop' ? TextDecoration.lineThrough : null))),
                        ]),
                      )),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setS(() { picked.add(t); frog = frog == t ? null : t; }),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Opacity(opacity: frog == t ? 1 : .25, child: const Text('🐸', style: TextStyle(fontSize: 18))),
                        ),
                      ),
                    ]),
                    if (stuck.contains(t))
                      Padding(
                        padding: const EdgeInsets.only(left: 32),
                        child: decided.containsKey(t)
                          ? Text(const {'do': 'ตัดสินใจแล้ว: ทำวันนี้', 'split': 'ตัดสินใจแล้ว: แตกย่อย', 'drop': 'ตัดสินใจแล้ว: ลบ'}[decided[t]]!,
                              style: TextStyle(fontSize: 11.5, color: _cText.withValues(alpha: .5)))
                          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('เลื่อนมา ${t.postponeCount} ครั้งแล้ว — ต้องตัดสินใจ',
                                style: const TextStyle(fontSize: 11.5, color: _cRed, fontWeight: FontWeight.w600)),
                              Row(children: [
                                chip('ทำวันนี้', () => setS(() { decided[t] = 'do'; picked.add(t); })),
                                chip('แตกย่อย', () {
                                  setS(() { decided[t] = 'split'; picked.add(t); });
                                  final idx = _tasks.indexOf(t);
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailScreen(
                                    task: t, taskIndex: idx,
                                    onDelete: () { NotificationService.cancel(t.id); _set(() => _tasks.remove(t)); _saveTasks(); _updateWidget(); },
                                    onChanged: () { _saveTasks(); _set(() {}); },
                                  )));
                                }),
                                chip('ลบ', () => setS(() { decided[t] = 'drop'; picked.remove(t); if (frog == t) frog = null; }), danger: true),
                              ]),
                            ]),
                      ),
                  ]),
                ),
            ])),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: !ready ? null : () {
                final now = DateTime.now();
                final day = DateTime(now.year, now.month, now.day);
                _set(() {
                  for (final t in items) {
                    // เคยวางแผนไว้วันก่อนแล้วยังไม่เสร็จ = ถูกเลื่อน 1 ครั้ง
                    if (t.plannedFor != null && t.plannedFor!.isBefore(day)) t.postponeCount++;
                    if (decided[t] == 'do' || decided[t] == 'split') t.postponeCount = 0;
                    t.plannedFor = picked.contains(t) ? day : null;
                    t.isFrog = frog == t;
                  }
                  for (final t in items.where((t) => decided[t] == 'drop')) {
                    NotificationService.cancel(t.id);
                    _tasks.remove(t);
                  }
                });
                _saveTasks();
                _updateWidget();
                SharedPreferences.getInstance().then((p) => p.setString('last_plan_date', _dayKey(now)));
                Navigator.pop(ctx);
              },
              child: Opacity(
                opacity: ready ? 1 : .4,
                child: Container(
                  width: double.infinity, height: 48,
                  decoration: BoxDecoration(color: _cSurf, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cText.withValues(alpha: .25))),
                  child: Center(child: Text(ready ? 'เริ่มวัน · $count งาน' : 'ตัดสินใจงานที่เลื่อนก่อน',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _cText))),
                ),
              ),
            ),
          ]),
        );
      }),
    );
  }
}
