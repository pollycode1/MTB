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
          _quickBtn('⏳ รอ', _cText.withValues(alpha: .06), _cText.withValues(alpha: .5), _cText.withValues(alpha: .12),
            onTap: () { _set(() => _tasks[i].type = 'waiting'); _saveTasks(); }),
        ]),
      ]),
    );
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
              child: Row(children: ['สอน', 'ส่วนตัว', 'บ้าน'].map((a) =>
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
