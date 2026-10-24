part of 'home_screen.dart';

extension _IdeasTab on _HomeScreenState {
  // ── Idea tab ───────────────────────────────────────────────────────────────────
  void _ideaMenu(TaskItem t) {
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
            leading: const Icon(Icons.task_alt_rounded, color: _cGreenDark),
            title: const Text('ย้ายเป็นงาน', style: TextStyle(fontSize: 14.5, color: _cText)),
            subtitle: Text('เป็นงานของวันนี้', style: TextStyle(fontSize: 12, color: _cText.withValues(alpha: .45))),
            onTap: () {
              Navigator.pop(ctx);
              final n = DateTime.now();
              _set(() { t.type = 'task'; t.reviewCount = 0; t.lastUpdatedAt = n; t.plannedFor = DateTime(n.year, n.month, n.day); });
              NotificationService.scheduleDeadline(t.id, t);
              _saveTasks();
              _updateWidget();
            },
          ),
        ]),
      ),
    );
  }

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
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onLongPress: () => _ideaMenu(t), // กดค้าง = ให้ AI ติดแท็ก / ย้ายเป็นงาน
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailScreen(allTasks: _tasks, 
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
              border: Border.all(color: _cGold.withValues(alpha: .15)),
            ),
            child: Row(children: [
              Icon(Icons.lightbulb_outline, size: 16, color: _cGoldDark),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _cText)),
                if (t.tags.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(t.tags.map((x) => '#$x').join('  '), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _cGoldDark)),
                ],
              ])),
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
