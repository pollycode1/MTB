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
    final item = TaskItem(title: text, type: 'inbox', lastUpdatedAt: DateTime.now());
    _set(() => _tasks.add(item));
    _saveTasks();
    _updateWidget();
    AiService.hasKey().then((k) { if (k && mounted) _aiTriage(item); }); // จัดหมวด/ความสำคัญให้ทันที
  }

  void _addIdea(String text) {
    if (text.trim().isEmpty) return;
    final idea = TaskItem(title: text.trim(), type: 'idea');
    _set(() => _tasks.add(idea));
    _saveTasks();
    AiService.hasKey().then((k) { if (k && mounted) _aiTag(idea); }); // ติดแท็กให้ทันที
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
                  _addIdea(v);
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
                  _addIdea(ctrl.text);
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
