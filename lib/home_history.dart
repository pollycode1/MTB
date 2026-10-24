part of 'home_screen.dart';

extension _ArchiveHistoryTab on _HomeScreenState {
  // ── Archive tab ───────────────────────────────────────────────────────────────

  Widget _archivedContent() {
    final indices = _archivedIdx;
    if (indices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(child: Text('ไม่มีรายการเก็บถาวร', style: TextStyle(fontSize: 14, color: _cText.withValues(alpha: .4)))),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('เก็บถาวร · ${indices.length} รายการ'),
      const SizedBox(height: 4),
      Text('กู้คืนได้ทุกเมื่อ', style: TextStyle(fontSize: 11, color: _cText.withValues(alpha: .3))),
      const SizedBox(height: 12),
      ...indices.map((i) {
        final t = _tasks[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: _cSurf.withValues(alpha: .5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cText.withValues(alpha: .07)),
          ),
          child: Row(children: [
            Icon(Icons.archive_outlined, size: 14, color: _cText.withValues(alpha: .35)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.title, style: TextStyle(fontSize: 13.5, color: _cText.withValues(alpha: .55), fontWeight: FontWeight.w500)),
              Text(t.type, style: TextStyle(fontSize: 10, color: _cText.withValues(alpha: .3))),
            ])),
            GestureDetector(
              onTap: () { _set(() { t.archivedAt = null; t.lastUpdatedAt = DateTime.now(); }); _saveTasks(); },
              child: Text('กู้คืน', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _cGoldDark)),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () { NotificationService.cancel(t.id); _set(() => _tasks.removeAt(i)); _saveTasks(); _updateWidget(); },
              child: Icon(Icons.delete_outline, size: 14, color: _cRed.withValues(alpha: .5)),
            ),
          ]),
        );
      }),
    ]);
  }

  // ── History tab ───────────────────────────────────────────────────────────────

  Widget _historyContent() {
    final filters = ['วันนี้', 'สัปดาห์นี้', 'เดือนนี้', 'ปีนี้', 'เดือนที่แล้ว', 'ปีที่แล้ว', 'ทั้งหมด'];
    final now = DateTime.now();
    final done = _tasks.where((t) => t.done && t.doneAt != null).where((t) {
      final d = t.doneAt!;
      switch (_historyFilter) {
        case 'วันนี้':       return d.year == now.year && d.month == now.month && d.day == now.day;
        case 'สัปดาห์นี้':  return now.difference(d).inDays < 7;
        case 'เดือนนี้':    return d.year == now.year && d.month == now.month;
        case 'ปีนี้':       return d.year == now.year;
        case 'เดือนที่แล้ว':return d.year == now.year && d.month == now.month - 1
              || (now.month == 1 && d.year == now.year - 1 && d.month == 12);
        case 'ปีที่แล้ว':   return d.year == now.year - 1;
        default:             return true;
      }
    }).toList()
      ..sort((a, b) => b.doneAt!.compareTo(a.doneAt!));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // งานเดือนเดียวกันของปีที่แล้ว → เลือกมาทำซ้ำเป็นงานใหม่
      GestureDetector(
        onTap: _openLastYear,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _cSurf,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cGoldDark.withValues(alpha: .35)),
          ),
          child: Row(children: [
            const Icon(Icons.history_rounded, size: 18, color: _cGoldDark),
            const SizedBox(width: 10),
            const Expanded(child: Text('งานเดือนนี้ของปีที่แล้ว', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _cText))),
            Text('เลือกมาทำซ้ำ ›', style: TextStyle(fontSize: 12, color: _cText.withValues(alpha: .45))),
          ]),
        ),
      ),
      SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, idx) {
            final f = filters[idx];
            final active = _historyFilter == f;
            return GestureDetector(
              onTap: () => _set(() => _historyFilter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? _cGreen : _cText.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(f, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: active ? Colors.white : _cText.withValues(alpha: .55))),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 16),
      if (done.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(child: Text('ไม่มีงานที่เสร็จใน$_historyFilter',
            style: TextStyle(fontSize: 13, color: _cText.withValues(alpha: .38)))),
        )
      else ...[
        Text('${done.length} งาน', style: TextStyle(fontSize: 11,
          fontWeight: FontWeight.w600, color: _cText.withValues(alpha: .4))),
        const SizedBox(height: 10),
        ...done.map((t) => _historyTile(t)),
      ],
      const SizedBox(height: 80),
    ]);
  }

  Widget _historyTile(TaskItem t) {
    final months = ['ม.ค.','ก.พ.','มี.ค.','เม.ย.','พ.ค.','มิ.ย.','ก.ค.','ส.ค.','ก.ย.','ต.ค.','พ.ย.','ธ.ค.'];
    final d = t.doneAt!;
    final timeStr = '${d.day} ${months[d.month-1]} · ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')} น.';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _cSurf.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cText.withValues(alpha: .07)),
      ),
      child: Row(children: [
        Container(width: 20, height: 20,
          decoration: BoxDecoration(color: _cGreen, borderRadius: BorderRadius.circular(6)),
          child: const Icon(Icons.check, size: 12, color: Colors.white)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600,
            color: _cText.withValues(alpha: .7), decoration: TextDecoration.lineThrough,
            decorationColor: _cText.withValues(alpha: .4))),
          const SizedBox(height: 2),
          Text(timeStr, style: TextStyle(fontSize: 10.5, color: _cText.withValues(alpha: .38))),
        ])),
        if (t.tags.isNotEmpty)
          Text(t.tags.map((x) => '#$x').join(' '), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _cGoldDark)),
      ]),
    );
  }
}
