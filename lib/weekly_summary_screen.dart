import 'package:flutter/material.dart';
import 'models.dart';

// สรุปสัปดาห์ (จันทร์–อาทิตย์) คำนวณจากข้อมูลที่มีอยู่ ไม่เก็บอะไรเพิ่ม
class WeekSummary {
  final DateTime weekStart;
  final int doneThis, doneLast, pending, overdue, inbox;
  final int timedCount, estMin, actMin; // งานเสร็จสัปดาห์นี้ที่มีทั้งเวลาประมาณและเวลาจริง
  final Map<String, int> doneByArea;
  final List<TaskItem> mostPostponed;
  WeekSummary({
    required this.weekStart, required this.doneThis, required this.doneLast,
    required this.pending, required this.overdue, required this.inbox,
    required this.timedCount, required this.estMin, required this.actMin,
    required this.doneByArea, required this.mostPostponed,
  });
}

WeekSummary computeWeekSummary(List<TaskItem> tasks, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(Duration(days: now.weekday - 1));
  final lastStart = start.subtract(const Duration(days: 7));
  final byArea = <String, int>{};
  var doneThis = 0, doneLast = 0, timedCount = 0, estMin = 0, actMin = 0;
  for (final t in tasks.where((t) => t.type == 'task' && t.done && t.doneAt != null)) {
    final d = t.doneAt!;
    if (!d.isBefore(start)) {
      doneThis++;
      byArea[t.area ?? 'อื่นๆ'] = (byArea[t.area ?? 'อื่นๆ'] ?? 0) + 1;
      if (t.estimateMin != null && t.actualMin != null) {
        timedCount++;
        estMin += t.estimateMin!;
        actMin += t.actualMin!;
      }
    } else if (!d.isBefore(lastStart)) {
      doneLast++;
    }
  }
  final pending = tasks.where((t) => t.type == 'task' && !t.done && t.archivedAt == null).toList();
  final stuck = pending.where((t) => t.postponeCount > 0).toList()
    ..sort((a, b) => b.postponeCount.compareTo(a.postponeCount));
  return WeekSummary(
    weekStart: start,
    doneThis: doneThis,
    doneLast: doneLast,
    pending: pending.length,
    overdue: pending.where((t) => t.deadline != null && t.deadline!.isBefore(now)).length,
    inbox: tasks.where((t) => t.type == 'inbox').length,
    timedCount: timedCount,
    estMin: estMin,
    actMin: actMin,
    doneByArea: byArea,
    mostPostponed: stuck.take(3).toList(),
  );
}

class WeeklySummaryScreen extends StatelessWidget {
  final List<TaskItem> tasks;
  const WeeklySummaryScreen({super.key, required this.tasks});

  static const _months = ['ม.ค.','ก.พ.','มี.ค.','เม.ย.','พ.ค.','มิ.ย.','ก.ค.','ส.ค.','ก.ย.','ต.ค.','พ.ย.','ธ.ค.'];
  String _fmt(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  Widget _stat(String label, String value, {Color color = kCText}) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
    decoration: BoxDecoration(color: kCSurf, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: kCText.withValues(alpha: .08))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: TextStyle(fontFamily: kMono, fontSize: 28, fontWeight: FontWeight.w600, color: color)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 11, color: kCText.withValues(alpha: .5))),
    ]),
  ));

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 8),
    child: Text(t, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: kCText.withValues(alpha: .4))),
  );

  @override
  Widget build(BuildContext context) {
    final s = computeWeekSummary(tasks, DateTime.now());
    final end = s.weekStart.add(const Duration(days: 6));
    final diff = s.doneThis - s.doneLast;
    final cmp = s.doneLast == 0 && s.doneThis == 0
        ? 'สัปดาห์ก่อนยังไม่มีงานเสร็จ'
        : diff == 0 ? 'เท่าสัปดาห์ก่อน (${s.doneLast})'
        : diff > 0 ? 'มากกว่าสัปดาห์ก่อน $diff (${s.doneLast})'
        : 'น้อยกว่าสัปดาห์ก่อน ${-diff} (${s.doneLast})';
    return Scaffold(
      backgroundColor: kCBg,
      appBar: AppBar(
        backgroundColor: kCBg, elevation: 0,
        title: const Text('สรุปสัปดาห์', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kCText)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
        Text('${_fmt(s.weekStart)} – ${_fmt(end)}', style: const TextStyle(fontSize: 12, color: kCGoldDark, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(children: [
          _stat('เสร็จสัปดาห์นี้', '${s.doneThis}', color: kCGreenDk),
          const SizedBox(width: 10),
          _stat('ยังค้าง', '${s.pending}'),
        ]),
        const SizedBox(height: 8),
        Text(cmp, style: TextStyle(fontSize: 12, color: kCText.withValues(alpha: .5))),
        const SizedBox(height: 10),
        Row(children: [
          _stat('เกินกำหนด', '${s.overdue}', color: s.overdue > 0 ? kCRed : kCText),
          const SizedBox(width: 10),
          _stat('รอคัดแยกในกล่องรับ', '${s.inbox}'),
        ]),
        if (s.doneByArea.isNotEmpty) ...[
          _label('เสร็จแยกตามหมวด'),
          ...s.doneByArea.entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(e.key, style: const TextStyle(fontSize: 14, color: kCText)),
              Text('${e.value}', style: const TextStyle(fontFamily: kMono, fontSize: 14, color: kCGoldDark)),
            ]),
          )),
        ],
        if (s.timedCount > 0) ...[
          _label('ประมาณเวลา vs ใช้จริง · ${s.timedCount} งาน'),
          Text('คาดไว้ ${s.estMin} นาที · ใช้จริง ${s.actMin} นาที (${(s.actMin * 100 / s.estMin).round()}%)',
            style: const TextStyle(fontSize: 14, color: kCText)),
          const SizedBox(height: 4),
          Text(s.actMin > s.estMin ? 'งานใช้เวลานานกว่าที่คาด — รอบหน้าลองประมาณเพิ่มขึ้น' : 'ประมาณเวลาได้ใกล้เคียงหรือเผื่อไว้พอดี',
            style: TextStyle(fontSize: 12, color: kCText.withValues(alpha: .5))),
        ],
        _label('งานที่ถูกเลื่อนบ่อยสุด'),
        if (s.mostPostponed.isEmpty)
          Text('ไม่มีงานค้างที่ถูกเลื่อน', style: TextStyle(fontSize: 13, color: kCText.withValues(alpha: .4)))
        else
          ...s.mostPostponed.map((t) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Expanded(child: Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: kCText))),
              Text('เลื่อน ${t.postponeCount} ครั้ง', style: const TextStyle(fontSize: 11.5, color: kCRed, fontWeight: FontWeight.w600)),
            ]),
          )),
      ]),
    );
  }
}
