part of 'home_screen.dart';

extension _TodayTab on _HomeScreenState {
  // ── งาน tab: กล่องรับ (รอคัดแยก) + งานตามช่วงเวลา ──────────────────────────────
  // วันที่ที่งานควรทำ = plannedFor ?? deadline (ไม่มีทั้งคู่ = งานค้างเก่า เห็นเฉพาะ "ทั้งหมด")
  DateTime? _dueDay(TaskItem t) {
    final d = t.plannedFor ?? t.deadline;
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  bool _inPeriod(TaskItem t) {
    if (_period == 'all') return true;
    final d = _dueDay(t);
    if (d == null) return false;
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final DateTime end = switch (_period) {
      'week'  => today.add(Duration(days: 7 - n.weekday)),       // อาทิตย์นี้
      'month' => DateTime(n.year, n.month + 1, 0),               // วันสุดท้ายของเดือน
      _       => today,
    };
    return !d.isAfter(end); // รวมงานที่เลยมาแล้ว (ยังไม่เสร็จ) ไว้ด้วย
  }

  bool _isDue(TaskItem t) {
    final d = _dueDay(t);
    final n = DateTime.now();
    return d != null && !d.isAfter(DateTime(n.year, n.month, n.day));
  }

  Widget _periodRow() {
    const keys   = ['today', 'week', 'month', 'all'];
    const labels = ['วันนี้', 'สัปดาห์นี้', 'เดือนนี้', 'ทั้งหมด'];
    return Row(children: List.generate(keys.length, (i) {
      final active = _period == keys[i];
      return Padding(
        padding: EdgeInsets.only(right: i < keys.length - 1 ? 8 : 0),
        child: GestureDetector(
          onTap: () => _set(() => _period = keys[i]),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: active ? _cGold.withValues(alpha: .15) : _cText.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: active ? _cGoldDark.withValues(alpha: .45) : _cText.withValues(alpha: .08)),
            ),
            child: Text(labels[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: active ? _cText : _cText.withValues(alpha: .5))),
          ),
        ),
      );
    }));
  }

  Widget _todayContent() {
    var pending = _pendingIdx.where((i) => _inPeriod(_tasks[i])).toList();
    var done    = _doneIdx;
    if (_areaFilter.isNotEmpty) {
      pending = pending.where((i) => _tasks[i].area == _areaFilter).toList();
      done    = done.where((i) => _tasks[i].area == _areaFilter).toList();
    }
    // กบก่อน → วางแผนไว้วันนี้ → ลำดับอัตโนมัติ
    pending = _rankForFocus(pending);
    int pri(int i) => _tasks[i].isFrog ? 0 : _isPlannedToday(_tasks[i]) ? 1 : 2;
    pending.sort((a, b) => pri(a).compareTo(pri(b))); // sort เสถียร: ลำดับเดิมคงไว้ในกลุ่มเดียวกัน
    final inbox = _inboxIdx;
    const periodLabel = {'today': 'วันนี้', 'week': 'สัปดาห์นี้', 'month': 'เดือนนี้', 'all': 'ทั้งหมด'};
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (inbox.isNotEmpty) ...[
        _sectionLabel('รอคัดแยก · ${inbox.length} รายการ'),
        const SizedBox(height: 10),
        ...inbox.asMap().entries.map((e) => _staggered(e.key, _inboxCard(e.value))),
        const SizedBox(height: 10),
      ],
      _periodRow(),
      const SizedBox(height: 10),
      _areaFilterRow(),
      const SizedBox(height: 12),
      if (pending.isEmpty && done.isEmpty && inbox.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(child: Text('ยังไม่มีงาน กด + เพื่อเพิ่ม',
            style: TextStyle(fontSize: 13, color: _cText.withValues(alpha: .4)))),
        )
      else ...[
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _sectionLabel('${periodLabel[_period]} · ${pending.length} งาน'),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openMorningPlan,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Text('วางแผน', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _cGoldDark)),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        if (pending.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('ไม่มีงานในช่วงนี้', style: TextStyle(fontSize: 13, color: _cText.withValues(alpha: .4))),
          ),
        ...pending.asMap().entries.map((e) => _staggered(e.key, _taskCard(e.value, done: false))),
        if (done.isNotEmpty) ...[
          const SizedBox(height: 6),
          _sectionLabel('เสร็จแล้ว · ${done.length} งาน'),
          const SizedBox(height: 8),
          ...done.map((i) => _taskCard(i, done: true)),
        ],
        if (_escalatedWaitingIdx.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionLabel('ติดตาม — รอเกิน 7 วัน'),
          const SizedBox(height: 8),
          ..._escalatedWaitingIdx.map((i) {
            final t = _tasks[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: _cSurf,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _cGoldDark.withValues(alpha: .35)),
              ),
              child: Row(children: [
                Icon(Icons.hourglass_top_rounded, size: 15, color: _cGoldDark),
                const SizedBox(width: 10),
                Expanded(child: Text(t.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _cText))),
                GestureDetector(
                  onTap: () { _set(() { t.tag = null; t.tagBg = null; t.tagColor = null; t.lastUpdatedAt = DateTime.now(); }); _saveTasks(); },
                  child: Text('อัปเดตแล้ว', style: TextStyle(fontSize: 11, color: _cGoldDark, fontWeight: FontWeight.w600)),
                ),
              ]),
            );
          }),
        ],
      ],
    ]);
  }

  List<int> _rankForFocus(List<int> idxs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int rank(TaskItem t) {
      final d = t.deadline;
      if (d != null) {
        if (d.isBefore(now)) return 0;
        if (d.isBefore(today.add(const Duration(days: 1)))) return 1;
        if (d.isBefore(today.add(const Duration(days: 3)))) return 2;
      }
      return 2 + t.priority; // priority 1..3 → 3..5
    }
    final sorted = [...idxs];
    sorted.sort((a, b) {
      final ta = _tasks[a], tb = _tasks[b];
      final r = rank(ta).compareTo(rank(tb));
      if (r != 0) return r;
      final p = ta.priority.compareTo(tb.priority);
      if (p != 0) return p;
      final da = ta.deadline, db = tb.deadline;
      if (da != null && db != null) {
        final c = da.compareTo(db);
        if (c != 0) return c;
      } else if (da != null) {
        return -1;
      } else if (db != null) {
        return 1;
      }
      return a.compareTo(b);
    });
    return sorted;
  }

  Widget _areaFilterRow() {
    const areas  = ['', 'สอน', 'ส่วนตัว', 'บ้าน'];
    const labels = ['ทั้งหมด', 'สอน', 'ส่วนตัว', 'บ้าน'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: List.generate(areas.length, (i) {
        final active = _areaFilter == areas[i];
        return GestureDetector(
          onTap: () => _set(() => _areaFilter = areas[i]),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: EdgeInsets.only(right: i < areas.length - 1 ? 7 : 0),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
            decoration: BoxDecoration(
              color: active ? _cGreen.withValues(alpha: .15) : _cText.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: active ? _cGreen.withValues(alpha: .4) : _cText.withValues(alpha: .08)),
            ),
            child: Text(labels[i], style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
              color: active ? _cGreenDark : _cText.withValues(alpha: .5))),
          ),
        );
      })),
    );
  }

  // ── Task card ─────────────────────────────────────────────────────────────────
  Widget _staggered(int listIdx, Widget child) {
    final dur = Duration(milliseconds: 220 + listIdx * 50);
    return AnimatedOpacity(
      opacity: _entered ? 1 : 0, duration: dur, curve: Curves.easeOut,
      child: AnimatedSlide(offset: _entered ? Offset.zero : const Offset(0, 0.08), duration: dur, curve: Curves.easeOutQuart, child: child),
    );
  }

  Widget _taskCard(int i, {required bool done}) {
    final t = _tasks[i];
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
        TaskDetailScreen(
          task: t,
          taskIndex: i,
          onDelete: () {
            NotificationService.cancel(t.id);
            _set(() => _tasks.remove(t));
            _saveTasks();
            _updateWidget();
          },
          onChanged: () { _saveTasks(); _set(() {}); },
        )
      )).then((_) => _set(() {})),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, left: 7),
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(left: -14, top: 0, bottom: 0, child: Center(child: Container(
            width: 14, height: 14,
            decoration: BoxDecoration(color: done ? _cGreen.withValues(alpha: .3) : const Color(0xFF2A2A2A), shape: BoxShape.circle)))),
          Positioned(left: -8, top: 10, bottom: 10, child: Container(width: 1.5,
            decoration: BoxDecoration(border: Border(left: BorderSide(color: _cText.withValues(alpha: .13), width: 1.5))))),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 13, 14, 13),
            decoration: BoxDecoration(
              color: done ? _cSurf.withValues(alpha: .6) : _cSurf.withValues(alpha: .95),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _cText.withValues(alpha: done ? .05 : .09)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .4), blurRadius: 26, offset: const Offset(0, 14), spreadRadius: -22)],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
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
                  Text((t.isFrog && !done ? '🐸 ' : '') + t.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                    color: done ? _cText.withValues(alpha: .4) : _cText, height: 1.35,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: _cText.withValues(alpha: .4))),
                  const SizedBox(height: 4),
                  Text(t.meta, style: TextStyle(fontSize: 10.5,
                    color: (!done && t.warn) ? _cRed : _cText.withValues(alpha: done ? .32 : .5))),
                  if (t.deadline != null && !done) ...[
                    const SizedBox(height: 5),
                    _deadlineBadge(t.deadline!),
                  ],
                  if (!done && _isDue(t)) ...[
                    const SizedBox(height: 7),
                    _dueActions(t),
                  ],
                  if (t.subTasks.isNotEmpty && !_expandedCards.contains(t.id)) ...[
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
                // expand toggle
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _set(() {
                    if (_expandedCards.contains(t.id)) _expandedCards.remove(t.id);
                    else _expandedCards.add(t.id);
                  }),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 2, 0),
                    child: Icon(
                      _expandedCards.contains(t.id) ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 18, color: _cText.withValues(alpha: .28),
                    ),
                  ),
                ),
              ]),
              if (_expandedCards.contains(t.id)) ...[
                Divider(color: _cText.withValues(alpha: .07), height: 18),
                ...t.subTasks.map((s) => SubTaskTile(
                  sub: s, depth: 0,
                  onChanged: () { _saveTasks(); _set(() {}); },
                  onDelete: () { _set(() => t.subTasks.remove(s)); _saveTasks(); },
                )),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () { _set(() => t.subTasks.add(SubTask(title: 'ขั้นตอนใหม่'))); _saveTasks(); },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 2, left: 2),
                    child: Text('+ เพิ่มขั้นตอน',
                      style: TextStyle(fontSize: 12, color: _cText.withValues(alpha: .3))),
                  ),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  // งานถึงวันทำแล้ว: ป้าย "วันนี้" + เลื่อน / ไม่ทำ
  Widget _dueActions(TaskItem t) {
    Widget btn(String label, Color fg, VoidCallback onTap) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 14, top: 2, bottom: 2),
        child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg)),
      ),
    );
    return Row(children: [
      Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: _cGreen.withValues(alpha: .15), borderRadius: BorderRadius.circular(999)),
        child: const Text('วันนี้', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _cGreenDark)),
      ),
      btn('เลื่อน', _cGoldDark, () => _openDefer(t)),
      btn('ไม่ทำ', _cText.withValues(alpha: .45), () => _archiveTask(t)),
    ]);
  }

  Widget _deadlineBadge(DateTime d) {
    final now = DateTime.now();
    final diff = d.difference(DateTime(now.year, now.month, now.day)).inDays;
    final isOverdue = d.isBefore(now);
    final color = isOverdue ? _cRed : diff == 0 ? _cGoldDark : _cGreen.withValues(alpha: .8);
    final months = ['ม.ค.','ก.พ.','มี.ค.','เม.ย.','พ.ค.','มิ.ย.','ก.ค.','ส.ค.','ก.ย.','ต.ค.','พ.ย.','ธ.ค.'];
    final label = isOverdue ? 'เกินกำหนด'
        : diff == 0 ? 'วันนี้'
        : diff == 1 ? 'พรุ่งนี้'
        : '${d.day} ${months[d.month-1]}';
    return Row(children: [
      Icon(Icons.alarm_rounded, size: 10, color: color),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _subTaskProgress(List<SubTask> subs) {
    int total = 0, done = 0;
    void count(List<SubTask> list) { for (final s in list) { total++; if (s.done) done++; count(s.children); } }
    count(subs);
    return Row(children: [
      Text('$done/$total ขั้นตอน', style: TextStyle(fontSize: 10, color: _cText.withValues(alpha: .4), fontFamily: _kMono)),
    ]);
  }
}
