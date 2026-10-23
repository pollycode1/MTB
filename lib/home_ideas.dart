part of 'home_screen.dart';

extension _IdeasTab on _HomeScreenState {
  // ── Idea tab ───────────────────────────────────────────────────────────────────
  Widget _ideaContent() {
    final indices = _ideaIdx;
    if (indices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(child: Text('ยังไม่มีไอเดีย', style: TextStyle(fontSize: 14, color: _cText.withValues(alpha: .4)))),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('${indices.length} ไอเดีย'),
      const SizedBox(height: 10),
      ...indices.map((i) {
        final t = _tasks[i];
        final resurface = t.reviewCount >= 3;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (resurface)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: _cGreen.withValues(alpha: .12), borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _cGreen.withValues(alpha: .3))),
              child: Row(children: [
                Icon(Icons.auto_awesome, size: 13, color: _cGreen),
                const SizedBox(width: 6),
                Expanded(child: Text('สนใจมา 3 รอบแล้ว — แปลงเป็น task?',
                  style: TextStyle(fontSize: 12, color: _cGreen, fontWeight: FontWeight.w600))),
                GestureDetector(
                  onTap: () {
                    _set(() { t.type = 'task'; t.meta = ''; t.reviewCount = 0; t.lastUpdatedAt = DateTime.now(); });
                    _saveTasks();
                  },
                  child: Text('แปลง ✓', style: TextStyle(fontSize: 11, color: _cGreen, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailScreen(
              task: t,
              taskIndex: i,
              onDelete: () { NotificationService.cancel(t.id); _set(() => _tasks.remove(t)); _saveTasks(); _updateWidget(); },
              onChanged: () { _saveTasks(); _updateWidget(); _set(() {}); },
            ))).then((_) => _set(() {})),
            child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            decoration: BoxDecoration(
              color: _cSurf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: resurface ? _cGreen.withValues(alpha: .25) : _cGold.withValues(alpha: .15)),
            ),
            child: Row(children: [
              Icon(Icons.lightbulb_outline, size: 16, color: _cGoldDark),
              const SizedBox(width: 10),
              Expanded(child: Text(t.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _cText))),
              // ยังสนใจอยู่ — นับ review
              GestureDetector(
                onTap: () {
                  _set(() { t.reviewCount++; t.lastUpdatedAt = DateTime.now(); });
                  _saveTasks();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('★', style: TextStyle(fontSize: 13,
                    color: t.reviewCount > 0 ? _cGoldDark : _cText.withValues(alpha: .25))),
                ),
              ),
              GestureDetector(
                onTap: () { _set(() => _tasks[i].type = 'inbox'); _saveTasks(); _set(() => _tabIdx = 1); },
                child: Text('→ inbox', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _cGoldDark)),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  _set(() { t.archivedAt = DateTime.now(); });
                  _saveTasks();
                },
                child: Icon(Icons.close, size: 14, color: _cText.withValues(alpha: .3)),
              ),
            ]),
          ),
          ),
        ]);
      }),
    ]);
  }
}
