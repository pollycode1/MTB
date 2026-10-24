part of 'home_screen.dart';

extension _NotifsTab on _HomeScreenState {
  // ── แจ้งเตือน: กำลังจะแจ้ง + ประวัติย้อนหลัง (NotifLog) ─────────────────────────────────

  Widget _notifContent() {
    final now = DateTime.now();
    final upcoming = NotifLog.upcoming(now).take(20).toList();
    final past = NotifLog.past(now);
    if (upcoming.isEmpty && past.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(child: Text('ยังไม่มีแจ้งเตือน', style: TextStyle(fontSize: 14, color: _cText.withValues(alpha: .4)))),
      );
    }
    final today = DateTime(now.year, now.month, now.day);
    String dayLabel(DateTime d) {
      final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
      const months = ['ม.ค.','ก.พ.','มี.ค.','เม.ย.','พ.ค.','มิ.ย.','ก.ค.','ส.ค.','ก.ย.','ต.ค.','พ.ย.','ธ.ค.'];
      return switch (diff) { 0 => 'วันนี้', 1 => 'เมื่อวาน', -1 => 'พรุ่งนี้', _ => '${d.day} ${months[d.month - 1]}' };
    }
    final rows = <Widget>[];
    String? lastDay;
    for (final e in past) {
      final label = dayLabel(e.at);
      if (label != lastDay) { rows.add(Padding(padding: const EdgeInsets.only(top: 10, bottom: 6), child: _sectionLabel(label))); lastDay = label; }
      rows.add(_notifRow(e, dim: false));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (upcoming.isNotEmpty) ...[
        _sectionLabel('กำลังจะแจ้ง'),
        const SizedBox(height: 8),
        for (final e in upcoming) _notifRow(e, dim: true, day: dayLabel(e.at)),
        const SizedBox(height: 14),
      ],
      if (past.isNotEmpty) ...[
        _sectionLabel('แจ้งแล้ว · ย้อนหลัง ${NotifLog.keepDays} วัน'),
        ...rows,
      ],
    ]);
  }

  Widget _notifRow(NotifEntry e, {required bool dim, String? day}) {
    final task = e.taskId == null ? null : _tasks.where((t) => t.id == e.taskId).firstOrNull;
    final time = '${day == null ? '' : '$day '}${e.at.hour.toString().padLeft(2, '0')}:${e.at.minute.toString().padLeft(2, '0')}';
    void Function()? onTap = switch (e.payload) {
      'weekly' => _openWeeklySummary,
      'plan' => _openMorningPlan,
      'lastyear' => _openLastYear,
      _ => task == null ? null : () => _openTaskDetail(task),
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(
          color: _cSurf.withValues(alpha: dim ? .5 : 1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _cText.withValues(alpha: .07)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(dim ? Icons.schedule_rounded : Icons.notifications_none_rounded, size: 15, color: _cText.withValues(alpha: .4)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _cText.withValues(alpha: dim ? .6 : .9))),
            if (e.body.isNotEmpty)
              Text(e.body, style: TextStyle(fontSize: 12, color: _cText.withValues(alpha: .5))),
          ])),
          const SizedBox(width: 8),
          Text(time, style: TextStyle(fontSize: 11, color: _cText.withValues(alpha: .4))),
        ]),
      ),
    );
  }
}
