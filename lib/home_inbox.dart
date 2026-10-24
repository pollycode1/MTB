part of 'home_screen.dart';

extension _InboxTab on _HomeScreenState {
  // ── Inbox cards (แสดงบนสุดของแท็บงาน) ───────────────────────────────────────────
  Widget _inboxCard(int i) {
    final t = _tasks[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: _cSurf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cText.withValues(alpha: .09)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: _cText)),
        const SizedBox(height: 10),
        Row(children: [
          _quickBtn('→ งาน', _cGreen.withValues(alpha: .15), _cGreenDark, _cGreen.withValues(alpha: .35),
            onTap: () => _moveToTask(i)),
          const SizedBox(width: 7),
          _quickBtn('💡 ไอเดีย', _cGold.withValues(alpha: .1), _cGoldDark, _cGold.withValues(alpha: .25),
            onTap: () { _set(() => _tasks[i].type = 'idea'); _saveTasks(); }),
          const SizedBox(width: 7),
          _quickBtn(_aiBusy.contains(t.id) ? '…' : '✨ AI จัด', _cText.withValues(alpha: .06), _cText, _cText.withValues(alpha: .18),
            onTap: () { if (!_aiBusy.contains(t.id)) _aiTriage(t); }),
          const SizedBox(width: 7),
          _quickBtn('⏳ รอ', _cText.withValues(alpha: .06), _cText.withValues(alpha: .5), _cText.withValues(alpha: .12),
            onTap: () { _set(() => _tasks[i].type = 'waiting'); _saveTasks(); }),
        ]),
      ]),
    );
  }

  // AI คัดแยกรายการในกล่องรับ: ประเภท หมวด แท็ก ขั้นต่อไป และกำหนดส่ง (ถ้าข้อความบอกไว้)
  Future<void> _aiTriage(TaskItem t) async {
    _set(() => _aiBusy.add(t.id));
    try {
      final examples = _tasks.where((x) => x.type == 'task' && x.area != null).take(30)
          .map((x) => {'title': x.title, 'area': x.area, if (x.tags.isNotEmpty) 'tags': x.tags}).toList();
      final r = await AiService.askJson(
        system: aiSystem,
        prompt: '${todayLine()}\nตัวอย่างงานที่ผู้ใช้จัดหมวดไว้แล้ว: ${jsonEncode(examples)}\n'
            'แท็กที่มีอยู่: ${jsonEncode(_allTags)}\n\n'
            'จัดรายการนี้จากกล่องรับ: "${t.title}"${t.meta.isNotEmpty && t.meta != 'inbox' ? ' (หมายเหตุ: ${t.meta})' : ''}\n'
            '- type: task = ต้องลงมือทำ, idea = ไอเดียเก็บไว้ก่อน, waiting = รอคนอื่น\n'
            '- area: ${[...Categories.list, 'ไม่ระบุ'].join(' / ')}\n'
            '- priority: 1 = สูง (ใกล้กำหนด มีผลต่อนักเรียน/คนอื่น หรือถ้าไม่ทำจะเกิดปัญหา), 2 = กลาง, 3 = ต่ำ (ทำเมื่อว่าง)\n'
            '- area: เลือกจากรายการของผู้ใช้เท่านั้น ห้ามตั้งใหม่ ไม่เข้ากันให้ตอบ ไม่ระบุ\n'
            '- tags: ' + aiTagRule + '\n'
            '- nextAction: การกระทำแรกที่จับต้องได้ เริ่มได้ใน 5 นาที\n'
            '- deadline: YYYY-MM-DD เฉพาะถ้าข้อความบอกวัน/กำหนดส่ง ไม่มีให้ตอบ ""',
        schema: {
          'type': 'object',
          'properties': {
            'type': {'type': 'string', 'enum': ['task', 'idea', 'waiting']},
            'area': {'type': 'string', 'enum': [...Categories.list, 'ไม่ระบุ']},
            'priority': {'type': 'integer', 'enum': [1, 2, 3]},
            'tags': {'type': 'array', 'items': {'type': 'string'}},
            'nextAction': {'type': 'string'},
            'deadline': {'type': 'string'},
          },
          'required': ['type', 'area', 'priority', 'tags', 'nextAction', 'deadline'],
          'additionalProperties': false,
        },
      );
      final type = (r['type'] as String).toLowerCase();
      final area = r['area'] as String;
      final newTags = (r['tags'] as List).cast<String>().map((x) => x.trim().replaceAll('#', ''))
          .where((x) => x.isNotEmpty && x.length <= 20 && !Categories.list.contains(x)).toSet().take(4).toList();
      final due = DateTime.tryParse(r['deadline'] as String);
      final n = DateTime.now();
      _set(() {
        t.type = const {'task', 'idea', 'waiting'}.contains(type) ? type : 'task';
        // ใช้เฉพาะหมวด/แท็กที่ผู้ใช้สร้างไว้ (schema บังคับแล้ว กันไว้อีกชั้น)
        t.area = Categories.list.contains(area) ? area : null;
        final p = (r['priority'] as num?)?.toInt();
        if (p != null && p >= 1 && p <= 3) t.priority = p;
        t.aiTodo = false;
        for (final x in newTags) { Tags.add(x); if (!t.tags.contains(x)) t.tags.add(x); }
        t.nextAction = (r['nextAction'] as String).trim();
        if (due != null && t.type != 'idea') t.deadline = DateTime(due.year, due.month, due.day, 9);
        if (t.type == 'task' && t.deadline == null) t.plannedFor = DateTime(n.year, n.month, n.day);
        t.lastUpdatedAt = n;
      });
      if (t.deadline != null) NotificationService.scheduleDeadline(t.id, t);
      _saveTasks();
      _updateWidget();
    } on AiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) _set(() => _aiBusy.remove(t.id));
    }
  }

  Future<void> _aiTag(TaskItem t) async {
    try {
      final r = await AiService.askJson(
        system: aiSystem,
        prompt: 'งาน: ${jsonEncode(taskForAi(t))}\nขั้นตอน: ${jsonEncode(t.subTasks.map((s) => s.title).toList())}\n'
            'หมวดของผู้ใช้: ${jsonEncode(Categories.list)}\nแท็กที่มีอยู่ในแอพ: ${jsonEncode(_allTags)}\n\n$aiTagRule '
            'รวมแท็กที่งานมีอยู่แล้วด้วยถ้ายังเหมาะ',
        schema: {
          'type': 'object',
          'properties': {'tags': {'type': 'array', 'items': {'type': 'string'}}},
          'required': ['tags'],
          'additionalProperties': false,
        },
      );
      final tags = (r['tags'] as List).cast<String>().map((x) => x.trim().replaceAll('#', ''))
          .where((x) => x.isNotEmpty && x.length <= 20 && !Categories.list.contains(x)).toSet().take(4);
      _set(() { for (final x in tags) { Tags.add(x); if (!t.tags.contains(x)) t.tags.add(x); } });
      _saveTasks();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('แท็ก: ${t.tags.map((x) => '#$x').join(' ')}')));
    } on AiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Widget _quickBtn(String label, Color bg, Color fg, Color border, {required VoidCallback onTap}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: border)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
      ),
    );

  void _moveToTask(int i) {
    final ctrl = TextEditingController();
    String? area;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _cText.withValues(alpha: .18), borderRadius: BorderRadius.circular(999)))),
            const SizedBox(height: 18),
            const Text('Next Action?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _cText)),
            const SizedBox(height: 4),
            Text('ต้องกรอกก่อนย้ายออกจาก inbox', style: TextStyle(fontSize: 12, color: _cText.withValues(alpha: .45))),
            const SizedBox(height: 14),
            _sheetField(ctrl, 'เช่น "โทรหา..." "เปิด doc..." "ซื้อ..."'),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: Categories.list.map((a) =>
                GestureDetector(
                  onTap: () => setLocal(() => area = area == a ? null : a),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 7),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: area == a ? _cGreen.withValues(alpha: .2) : _cText.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: area == a ? _cGreen.withValues(alpha: .5) : _cText.withValues(alpha: .1)),
                    ),
                    child: Text(a, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: area == a ? _cGreenDark : _cText.withValues(alpha: .6))),
                  ),
                ),
              ).toList()),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                final next = ctrl.text.trim();
                if (next.isEmpty) return;
                _set(() {
                  _tasks[i].type = 'task';
                  if (_tasks[i].deadline == null) {
                    final n = DateTime.now();
                    _tasks[i].plannedFor = DateTime(n.year, n.month, n.day);
                  }
                  _tasks[i].nextAction = next;
                  _tasks[i].area = area;
                  _tasks[i].meta = next;
                });
                _saveTasks();
                _updateWidget();
                Navigator.pop(ctx);
              },
              child: Container(width: double.infinity, height: 46,
                decoration: BoxDecoration(
                  color: _cGreen.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _cGreen.withValues(alpha: .35)),
                ),
                child: Center(child: Text('ย้ายไป Tasks →', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _cGreenDark)))),
            ),
          ]),
        ),
      )),
    );
  }
}
