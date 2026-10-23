part of 'home_screen.dart';

extension _InputSheets on _HomeScreenState {
  void _openInput() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF1C1C1C), Color(0xFF141414)]),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: _cText.withValues(alpha: .18), borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 16),
            const Align(alignment: Alignment.centerLeft,
              child: Text('จับความคิด', style: TextStyle(fontSize: 10.5, color: _cGoldDark, fontWeight: FontWeight.w600))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(
                controller: ctrl, autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (v) { if (v.trim().isNotEmpty) _addToInbox(v.trim()); Navigator.pop(context); },
                style: const TextStyle(fontSize: 15, color: _cText),
                decoration: InputDecoration(
                  hintText: 'พิมอะไรก็ได้ บันทึกก่อน เคลียร์ทีหลัง',
                  hintStyle: TextStyle(color: _cText.withValues(alpha: .4), fontSize: 13.5),
                  filled: true, fillColor: _cText.withValues(alpha: .06),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _cGoldDark, width: 1.5)),
                ),
              )),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () { if (ctrl.text.trim().isNotEmpty) _addToInbox(ctrl.text.trim()); Navigator.pop(context); },
                child: Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: _cSurf, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cText.withValues(alpha: .2))),
                  child: Center(child: Icon(Icons.arrow_upward_rounded, color: _cText.withValues(alpha: .7), size: 20))),
              ),
            ]),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  void _addToInbox(String text) {
    _set(() => _tasks.add(TaskItem(title: text, meta: 'inbox', type: 'inbox', lastUpdatedAt: DateTime.now())));
    _saveTasks();
    _updateWidget();
    // 2-minute rule: งานสั้น ไม่มี deadline → ถามว่าทำเลยไหม
    if (text.length < 30) {
      Future.microtask(() {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _cSurf,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text('ทำเลยไหม? ⚡', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _cText)),
            content: Text('"$text"\nดูเหมือนใช้เวลาไม่เกิน 2 นาที', style: TextStyle(fontSize: 13, color: _cText.withValues(alpha: .7))),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('เข้า inbox ก่อน', style: TextStyle(color: _cText.withValues(alpha: .5)))),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  // convert ล่าสุดเป็น task type แล้ว mark done ทันที
                  _set(() {
                    final t = _tasks.last;
                    t.type = 'task';
                    t.meta = 'ทำเสร็จแล้ว (2-min rule)';
                    t.done = true;
                    t.doneAt = DateTime.now();
                  });
                  _saveTasks();
                  _updateWidget();
                },
                child: const Text('ทำเสร็จแล้ว ✓', style: TextStyle(color: _cGreen, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      });
    }
  }

  void _openIdeaInput() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: _cText.withValues(alpha: .18), borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 16),
            const Align(alignment: Alignment.centerLeft,
              child: Text('บันทึกไอเดีย', style: TextStyle(fontSize: 10.5, color: _cGoldDark, fontWeight: FontWeight.w600))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(
                controller: ctrl, autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) { _set(() => _tasks.add(TaskItem(title: v.trim(), meta: 'ไอเดีย', type: 'idea'))); _saveTasks(); }
                  Navigator.pop(context);
                },
                style: const TextStyle(fontSize: 15, color: _cText),
                decoration: InputDecoration(
                  hintText: 'ไอเดียอะไรก็ได้…',
                  hintStyle: TextStyle(color: _cText.withValues(alpha: .4), fontSize: 13.5),
                  filled: true, fillColor: _cText.withValues(alpha: .06),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _cGoldDark, width: 1.5)),
                ),
              )),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  if (ctrl.text.trim().isNotEmpty) { _set(() => _tasks.add(TaskItem(title: ctrl.text.trim(), meta: 'ไอเดีย', type: 'idea'))); _saveTasks(); }
                  Navigator.pop(context);
                },
                child: Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: _cSurf, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cText.withValues(alpha: .2))),
                  child: Center(child: Icon(Icons.arrow_upward_rounded, color: _cText.withValues(alpha: .7), size: 20))),
              ),
            ]),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}
