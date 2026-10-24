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
    const keys   = ['all', 'today', 'week', 'month'];
    const labels = ['ทั้งหมด', 'วันนี้', 'สัปดาห์', 'เดือน'];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _cText.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: List.generate(keys.length, (i) {
        final active = _period == keys[i];
        return Expanded(child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _set(() => _period = keys[i]),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: active ? _cText.withValues(alpha: .14) : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(child: Text(labels[i], style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600,
              color: active ? _cText : _cText.withValues(alpha: .45)))),
          ),
        ));
      })),
    );
  }

  // หมวด (สอน/ส่วนตัว/บ้าน) ซ่อนไว้ในเมนู ไม่ต้องกินแถวของตัวเอง
  // กรองตามแท็ก (ย่อไว้ในเมนูเหมือนหมวด)
  Widget _tagMenu() {
    // เฉพาะแท็กที่ติดอยู่กับงานจริง (ไม่รวมแท็กในรายการกลางที่ยังไม่มีงานใช้)
    final used = {for (final t in _tasks) if (t.type == 'task' && t.archivedAt == null) ...t.tags};
    if (_tagFilter.isNotEmpty && !used.contains(_tagFilter)) _tagFilter = ''; // ไม่มีงานไหนใช้แท็กนี้แล้ว
    final tags = ['', ...Tags.list.where(used.contains), ...used.where((t) => !Tags.list.contains(t))];
    final active = _tagFilter.isNotEmpty;
    return PopupMenuButton<String>(
      initialValue: _tagFilter,
      color: _cSurf,
      onSelected: (v) => _set(() => _tagFilter = v),
      itemBuilder: (_) => [
        for (final t in tags)
          PopupMenuItem(value: t, child: Text(t.isEmpty ? 'ทุกแท็ก' : '#$t',
            style: const TextStyle(fontSize: 14, color: _cText))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: active ? _cGold.withValues(alpha: .15) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? _cGoldDark.withValues(alpha: .45) : _cText.withValues(alpha: .12)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(active ? '#$_tagFilter' : 'แท็ก', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
            color: active ? _cText : _cText.withValues(alpha: .5))),
          Icon(Icons.arrow_drop_down, size: 16, color: _cText.withValues(alpha: active ? .7 : .4)),
        ]),
      ),
    );
  }

  Widget _areaMenu() {
    final areas = ['', ...Categories.list];
    final active = _areaFilter.isNotEmpty;
    return PopupMenuButton<String>(
      initialValue: _areaFilter,
      color: _cSurf,
      onSelected: (v) => _set(() => _areaFilter = v),
      itemBuilder: (_) => [
        for (final a in areas)
          PopupMenuItem(value: a, child: Text(a.isEmpty ? 'ทุกหมวด' : a,
            style: const TextStyle(fontSize: 14, color: _cText))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: active ? _cGreen.withValues(alpha: .15) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? _cGreen.withValues(alpha: .4) : _cText.withValues(alpha: .12)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(active ? _areaFilter : 'ทุกหมวด', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
            color: active ? _cGreenDark : _cText.withValues(alpha: .5))),
          Icon(Icons.arrow_drop_down, size: 16, color: active ? _cGreenDark : _cText.withValues(alpha: .4)),
        ]),
      ),
    );
  }

  Widget _todayContent() {
    var pending = _pendingIdx.where((i) => _inPeriod(_tasks[i])).toList();
    var done    = _doneIdx;
    if (_areaFilter.isNotEmpty) {
      pending = pending.where((i) => _tasks[i].area == _areaFilter).toList();
      done    = done.where((i) => _tasks[i].area == _areaFilter).toList();
    }
    if (_tagFilter.isNotEmpty) {
      pending = pending.where((i) => _tasks[i].tags.contains(_tagFilter)).toList();
      done    = done.where((i) => _tasks[i].tags.contains(_tagFilter)).toList();
    }
    // งานใหม่ล่าสุดอยู่บนสุด (เวลาสร้างเท่ากัน = อันที่อยู่ท้ายลิสต์ใหม่กว่า) · แท็บ "วันนี้" ปักกบไว้บนสุด
    pending.sort((a, b) {
      if (_period == 'today' && _tasks[a].isFrog != _tasks[b].isFrog) return _tasks[a].isFrog ? -1 : 1;
      final c = _tasks[b].createdAt.compareTo(_tasks[a].createdAt);
      return c != 0 ? c : b.compareTo(a);
    });
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
      const SizedBox(height: 14),
      // ว่างจริงๆ เท่านั้น (ไม่ใช่ว่างเพราะตัวกรอง) — ไม่งั้นปุ่มตัวกรองจะหายจนเปลี่ยนกลับไม่ได้
      if (_pendingIdx.isEmpty && _doneIdx.isEmpty && inbox.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(child: Text('ยังไม่มีงาน กด + เพื่อเพิ่ม',
            style: TextStyle(fontSize: 13, color: _cText.withValues(alpha: .4)))),
        )
      else ...[
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _sectionLabel('${periodLabel[_period]} · ${pending.length} งาน'),
          Row(children: [
            _areaMenu(),
            _tagMenu(),
            // ปุ่ม "วันนี้" = เปิดหน้าเลือกงานของวันนี้ (หน้าเดียวกับที่เด้งตอนเปิดแอพครั้งแรกของวัน) ได้ทุกเมื่อ
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openMorningPlan,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _cGreen.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _cGreen.withValues(alpha: .4)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.today_rounded, size: 14, color: _cGreenDark),
                  SizedBox(width: 4),
                  Text('วันนี้', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _cGreenDark)),
                ]),
              ),
            ),
          ]),
        ]),
        const SizedBox(height: 10),
        if (pending.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(_areaFilter.isEmpty && _tagFilter.isEmpty ? 'ไม่มีงานในช่วงนี้' : 'ไม่มีงานที่ตรงกับตัวกรอง', style: TextStyle(fontSize: 13, color: _cText.withValues(alpha: .4))),
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
                  onTap: () { _set(() { t.tags.remove('ติดตาม'); t.lastUpdatedAt = DateTime.now(); }); _saveTasks(); },
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
      onLongPress: done ? null : () => _cardMenu(t), // กดค้าง = เมนูย้ายไปไอเดีย
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
        TaskDetailScreen(allTasks: _tasks, 
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
                  if (t.slotStart != null && !done) ...[
                    const SizedBox(height: 4),
                    Text('🕘 ${t.slotStart!.day}/${t.slotStart!.month} · ${hm(t.slotStart!.hour * 60 + t.slotStart!.minute)}–${hm(t.slotStart!.hour * 60 + t.slotStart!.minute + t.slotMin)}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _cGreenDark)),
                  ],
                  if (t.tags.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(t.tags.map((x) => '#$x').join('  '), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: _cGoldDark.withValues(alpha: done ? .5 : 1))),
                  ],
                  if (t.meta.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(t.meta, style: TextStyle(fontSize: 10.5,
                      color: (!done && t.warn) ? _cRed : _cText.withValues(alpha: done ? .32 : .5))),
                  ],
                  if (t.deadline != null && !done) ...[
                    const SizedBox(height: 5),
                    _deadlineBadge(t.deadline!),
                  ],
                  if (!done && _isDue(t)) ...[
                    const SizedBox(height: 7),
                    _dueActions(t),
                  ],
                  if (t.subTasks.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    _subTaskProgress(t.subTasks),
                  ],
                ])),
                if (!done) ...[
                  const SizedBox(width: 8),
                  _cardAreaChip(t),
                ],
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  // ปุ่มเปลี่ยนหมวดท้ายการ์ดงาน (แตะส่วนอื่นของการ์ด = เปิดรายละเอียด)
  Widget _cardAreaChip(TaskItem t) {
    final areas = [...Categories.list, ''];
    final has = t.area != null && t.area!.isNotEmpty;
    return PopupMenuButton<String>(
      color: _cSurf,
      onSelected: (v) {
        _set(() { t.area = v.isEmpty ? null : v; t.lastUpdatedAt = DateTime.now(); });
        _saveTasks();
        _updateWidget();
      },
      itemBuilder: (_) => [
        for (final a in areas)
          PopupMenuItem(value: a, child: Text(a.isEmpty ? 'ไม่ระบุหมวด' : a,
            style: TextStyle(fontSize: 14, color: a == (t.area ?? '') ? _cGreenDark : _cText))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: has ? _cGreen.withValues(alpha: .15) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: has ? _cGreen.withValues(alpha: .4) : _cText.withValues(alpha: .15)),
        ),
        child: Text(has ? t.area! : '+ หมวด', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600,
          color: has ? _cGreenDark : _cText.withValues(alpha: .4))),
      ),
    );
  }

  // งานถึงวันทำแล้ว: ป้าย "วันนี้" + เลื่อน / ไม่ทำ
  void _cardMenu(TaskItem t) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        decoration: const BoxDecoration(color: _cSurf, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _cText)),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share_rounded, color: _cText),
            title: const Text('แชร์ข้อมูลทั้งหมด (JSON)', style: TextStyle(fontSize: 14.5, color: _cText)),
            subtitle: Text('รวมขั้นตอนย่อย แท็ก หมายเหตุ และไฟล์แนบ', style: TextStyle(fontSize: 12, color: _cText.withValues(alpha: .45))),
            onTap: () { Navigator.pop(ctx); shareTask(t); },
          ),
          ListTile(
            leading: const Icon(Icons.sell_outlined, color: _cGoldDark),
            title: const Text('ให้ AI ติดแท็ก', style: TextStyle(fontSize: 14.5, color: _cText)),
            onTap: () { Navigator.pop(ctx); _aiTag(t); },
          ),
          ListTile(
            leading: const Icon(Icons.lightbulb_outline_rounded, color: _cGoldDark),
            title: const Text('ย้ายไปไอเดีย', style: TextStyle(fontSize: 14.5, color: _cText)),
            onTap: () { Navigator.pop(ctx); _moveToIdea(t); },
          ),
        ]),
      ),
    );
  }

  // ย้ายงานไปแท็บไอเดีย (ข้อมูลเดิมอยู่ครบ) · มีปุ่มเลิกทำ
  void _moveToIdea(TaskItem t) {
    final before = (t.plannedFor, t.isFrog);
    _set(() {
      t.type = 'idea';
      t.plannedFor = null;
      t.isFrog = false;
      t.reviewCount = 0;
      t.lastUpdatedAt = DateTime.now();
    });
    NotificationService.cancel(t.id);
    _saveTasks();
    _updateWidget();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('ย้าย "${t.title}" ไปไอเดียแล้ว'),
      action: SnackBarAction(label: 'เลิกทำ', onPressed: () {
        _set(() { t.type = 'task'; t.plannedFor = before.$1; t.isFrog = before.$2; });
        NotificationService.scheduleDeadline(t.id, t);
        _saveTasks();
        _updateWidget();
      }),
    ));
  }

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
