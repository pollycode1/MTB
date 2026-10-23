import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'task_detail_screen.dart';
import 'settings_screen.dart';
import 'notification_service.dart';
// import 'habits_screen.dart' — habits now inline in tab;

// ── Palette aliases (kept local so no rename needed) ─────────────────────────
const _cBg        = kCBg;
const _cSurf      = kCSurf;
const _cText      = kCText;
const _cGold      = kCGold;
const _cGoldDark  = kCGoldDark;
const _cGreen     = kCGreen;
const _cGreenDark = kCGreenDk;
const _cRed       = kCRed;
const _kMono      = kMono;


// ── Screen ────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _entered = false;
  bool _showAllPending = false;
  int _tabIdx = 0;
  String _historyFilter = 'เดือนนี้';
  String _areaFilter = '';
  String? _pendingIdeaTitle;
  bool _tasksLoaded = false;

  final Set<int> _expandedCards = {};
  final List<TaskItem> _tasks = [
    TaskItem(title: 'เตรียมสื่อการสอนคณิต', meta: 'เสร็จ 08:12 · เร็วกว่ากำหนด 48 นาที', done: true),
    TaskItem(title: 'ตรวจใบงาน ป.4 (18 ชุด)', meta: 'เลื่อนมาแล้ว 2 ครั้ง', warn: true,
        tag: 'สอน', tagBg: const Color(0x284F7A5B), tagColor: const Color(0xFF3F6349)),
    TaskItem(title: 'ซื้ออุปกรณ์ทำสื่อ', meta: 'ภายในวันพุธ'),
  ];

  String _userName = '';

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 30), () { if (mounted) setState(() => _entered = true); });
    WidgetsBinding.instance.addObserver(this);
    HomeWidget.setAppGroupId('group.com.example.mtb');
    NotificationService.scheduleWeeklyReview();
    _loadSettings();
    _loadTasks().then((_) {
      _tasksLoaded = true;
      Future.delayed(const Duration(milliseconds: 500), _updateWidget);
      if (_pendingIdeaTitle != null) {
        final t = _pendingIdeaTitle!;
        _pendingIdeaTitle = null;
        _openIdeaByTitle(t);
      }
    });
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetLaunch);
    HomeWidget.widgetClicked.listen(_handleWidgetLaunch);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() {
      _userName   = prefs.getString('settings_name') ?? '';
    });
  }

  Future<void> _saveSettings(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings_name', name);
  }

  void _openSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(
      tasks: _tasks,
      userName: _userName,
      onSave: (name, clearedAll) {
        setState(() {
          _userName   = name;
          if (clearedAll) {
            NotificationService.cancelAll().then((_) => NotificationService.scheduleWeeklyReview());
            _tasks.clear();
          }
        });
        _saveSettings(name);
        _saveTasks();
        _updateWidget();
      },
    )));
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_tasks.map((t) => t.toJson()).toList());
    await prefs.setString('tasks_json', encoded);
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // force re-read from disk so Kotlin widget changes are visible
    final raw = prefs.getString('tasks_json');
    if (raw == null) {
      // first run — save the hardcoded defaults so widget callback can read them
      await _saveTasks();
      return;
    }
    try {
      final list = jsonDecode(raw) as List;
      final missingId = list.any((j) => (j as Map<String, dynamic>)['id'] == null);
      if (mounted) {
        setState(() {
          _tasks
            ..clear()
            ..addAll(list.map((j) => TaskItem.fromJson(j as Map<String, dynamic>)));
        });
      }
      // งานเก่า (หรือที่เพิ่มจากวิดเจ็ต) ยังไม่มี id → บันทึกและตั้งการแจ้งเตือนใหม่ทั้งหมด
      if (missingId) await _migrateNotificationIds();
    } catch (_) {
      // corrupt data — keep hardcoded defaults
    }
    _runRules();
  }

  Future<void> _migrateNotificationIds() async {
    await NotificationService.cancelAll();
    await NotificationService.scheduleWeeklyReview();
    for (final t in _tasks) {
      await NotificationService.scheduleDeadline(t.id, t);
    }
    await _saveTasks();
  }

  void _runRules() {
    final now = DateTime.now();
    bool changed = false;
    for (final t in _tasks) {
      if (t.archivedAt != null || t.done) continue;
      // waiting escalation: 7 วันไม่มีการอัปเดต → ติดตาม
      if (t.type == 'waiting') {
        final last = t.lastUpdatedAt ?? t.doneAt ?? now;
        if (now.difference(last).inDays >= 7 && t.tag != 'ติดตาม') {
          t.tag = 'ติดตาม';
          t.tagBg = const Color(0x33D8A93F);
          t.tagColor = kCGoldDark;
          changed = true;
        }
      }
      // idea decay: 60 วันไม่แตะ → archive
      if (t.type == 'idea') {
        final last = t.lastUpdatedAt ?? now;
        if (now.difference(last).inDays >= 60) {
          t.archivedAt = now;
          changed = true;
        }
      }
    }
    if (changed) _saveTasks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadTasks().then((_) => _updateWidget());
    }
  }

  // active tasks (type=task, not done) — used for widget count
  List<int> get _pendingIdx => List.generate(_tasks.length, (i) => i)
      .where((i) => _tasks[i].type == 'task' && !_tasks[i].done).toList();
  List<int> get _doneIdx => List.generate(_tasks.length, (i) => i)
      .where((i) => _tasks[i].type == 'task' && _tasks[i].done)
      .toList()
      ..sort((a, b) => (_tasks[b].doneAt ?? DateTime(0)).compareTo(_tasks[a].doneAt ?? DateTime(0)));
  List<int> get _inboxIdx => List.generate(_tasks.length, (i) => i)
      .where((i) => _tasks[i].type == 'inbox').toList();
  List<int> get _ideaIdx => List.generate(_tasks.length, (i) => i)
      .where((i) => _tasks[i].type == 'idea' && _tasks[i].archivedAt == null).toList();
  List<int> get _archivedIdx => List.generate(_tasks.length, (i) => i)
      .where((i) => _tasks[i].archivedAt != null).toList();
  List<int> get _escalatedWaitingIdx => List.generate(_tasks.length, (i) => i)
      .where((i) => _tasks[i].type == 'waiting' && _tasks[i].tag == 'ติดตาม' && !_tasks[i].done && _tasks[i].archivedAt == null).toList();

  void _openIdeaByTitle(String title) {
    // ponytail: search after delay so _loadTasks() from didChangeAppLifecycleState can finish first
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final idx = _tasks.indexWhere((t) => t.type == 'idea' && t.title == title);
      if (idx < 0) return;
      setState(() => _tabIdx = 2);
      Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailScreen(
        task: _tasks[idx],
        taskIndex: idx,
        onDelete: () {
          NotificationService.cancel(_tasks[idx].id);
          setState(() => _tasks.removeAt(idx));
          _saveTasks();
          _updateWidget();
        },
        onChanged: () { _saveTasks(); _updateWidget(); setState(() {}); },
      ))).then((_) => setState(() {}));
    });
  }

  void _handleWidgetLaunch(Uri? uri) {
    if (uri == null || !mounted) return;
    switch (uri.host) {
      case 'add':
        Future.delayed(const Duration(milliseconds: 400), () { if (mounted) _openInput(); });
      case 'toggle':
        final idx = int.tryParse(uri.pathSegments.firstOrNull ?? '');
        if (idx != null && idx < _tasks.length) _toggle(idx);
      case 'task':
        setState(() => _tabIdx = 0);
      case 'idea':
        setState(() => _tabIdx = 2);
        final title = uri.queryParameters['t'];
        if (title != null && title.isNotEmpty) {
          if (_tasksLoaded) _openIdeaByTitle(title);
          else _pendingIdeaTitle = title;
        }
      case 'idea-del':
        final title = uri.queryParameters['t'];
        if (title != null && title.isNotEmpty) {
          final idx = _tasks.indexWhere((t) => t.type == 'idea' && t.title == title);
          if (idx >= 0) {
            NotificationService.cancel(_tasks[idx].id);
            setState(() => _tasks.removeAt(idx));
            _saveTasks();
            _updateWidget();
          }
          SystemNavigator.pop();  // ย่อแอพกลับไป launcher
        }
      case 'open':
        break;
    }
  }

  Future<void> _updateWidget() async {
    await HomeWidget.saveWidgetData('pending_tasks', _pendingIdx.length);
    await HomeWidget.saveWidgetData('total_tasks', _tasks.length);
    // full task list sorted: pending first, done newest-first
    final pending = _tasks.where((t) => t.type == 'task' && !t.done).toList();
    final done = _tasks.where((t) => t.type == 'task' && t.done).toList()
      ..sort((a, b) => (b.doneAt ?? DateTime(0)).compareTo(a.doneAt ?? DateTime(0)));
    final sorted = [...pending, ...done, ..._tasks.where((t) => t.type != 'task')];
    final tasksJson = jsonEncode(sorted.map((t) => t.toJson()).toList());
    await HomeWidget.saveWidgetData('tasks_json', tasksJson);
    await HomeWidget.updateWidget(androidName: 'MtbTasksWidget');
  }

  void _toggle(int i) {
    final t = _tasks[i];
    setState(() {
      t.done = !t.done;
      if (t.done) {
        t.doneAt = DateTime.now();
        NotificationService.cancel(t.id);
        // auto-create next occurrence for recurring tasks
        if (t.recurrence != null && t.deadline != null) {
          final next = _nextDeadline(t.deadline!, t.recurrence!);
          final clone = TaskItem(
            title: t.title, meta: t.meta, warn: t.warn,
            tag: t.tag, tagBg: t.tagBg, tagColor: t.tagColor,
            deadline: next, recurrence: t.recurrence,
            priority: t.priority, area: t.area, nextAction: t.nextAction,
            lastUpdatedAt: DateTime.now(),
          );
          _tasks.add(clone);
          NotificationService.scheduleDeadline(clone.id, clone);
        }
      } else {
        t.doneAt = null;
        NotificationService.scheduleDeadline(t.id, t);
      }
    });
    _saveTasks();
    _updateWidget();
  }

  DateTime _nextDeadline(DateTime from, String recurrence) {
    switch (recurrence) {
      case 'daily':   return from.add(const Duration(days: 1));
      case 'weekly':  return from.add(const Duration(days: 7));
      case 'monthly': return DateTime(from.year, from.month + 1, from.day, from.hour, from.minute);
      case 'yearly':  return DateTime(from.year + 1, from.month, from.day, from.hour, from.minute);
      default:        return from.add(const Duration(days: 1));
    }
  }

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
    setState(() => _tasks.add(TaskItem(title: text, meta: 'inbox', type: 'inbox', lastUpdatedAt: DateTime.now())));
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
                  setState(() {
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
                  if (v.trim().isNotEmpty) { setState(() => _tasks.add(TaskItem(title: v.trim(), meta: 'ไอเดีย', type: 'idea'))); _saveTasks(); }
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
                  if (ctrl.text.trim().isNotEmpty) { setState(() => _tasks.add(TaskItem(title: ctrl.text.trim(), meta: 'ไอเดีย', type: 'idea'))); _saveTasks(); }
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

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cBg,
      floatingActionButton: _tabIdx < 3
          ? GestureDetector(
              onTap: _tabIdx == 2 ? _openIdeaInput : _openInput,
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: _cSurf,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _cText.withValues(alpha: .2)),
                ),
                child: Center(child: Icon(Icons.add, color: _cText.withValues(alpha: .8), size: 24)),
              ),
            )
          : null,
      body: _buildMain(),
    );
  }

  Widget _buildMain() {
    final top = MediaQuery.of(context).padding.top;
    return Column(children: [
      // ── Fixed header + tab bar ──
      Padding(
        padding: EdgeInsets.fromLTRB(20, top + 24, 20, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _header(_pendingIdx.length),
          const SizedBox(height: 16),
          _tabBar(),
        ]),
      ),
      // ── Scrollable content ──
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_tabIdx == 0)
            _todayContent()
          else if (_tabIdx == 1)
            _inboxContent()
          else if (_tabIdx == 2)
            _ideaContent()
          else if (_tabIdx == 3)
            _historyContent()
          else
            _archivedContent(),
        ]),
      )),
    ]);
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────────
  Widget _tabBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _tabBtn(0, 'วันนี้'),
        const SizedBox(width: 8),
        _tabBtn(1, 'กล่องรับ', badge: _inboxIdx.length),
        const SizedBox(width: 8),
        _tabBtn(2, 'ไอเดีย'),
        const SizedBox(width: 8),
        _tabBtn(3, 'ประวัติ'),
        const SizedBox(width: 8),
        _tabBtn(4, 'เก็บถาวร', badge: _archivedIdx.length),
      ]),
    );
  }

  Widget _tabBtn(int idx, String label, {int badge = 0}) {
    final active = _tabIdx == idx;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _tabIdx = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _cGold.withValues(alpha: .15) : _cText.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? _cGoldDark.withValues(alpha: .45) : _cText.withValues(alpha: .1)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: active ? _cGoldDark : _cText.withValues(alpha: .5))),
          if (badge > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: _cRed.withValues(alpha: .85), borderRadius: BorderRadius.circular(999)),
              child: Text('$badge', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ]),
      ),
    );
  }

  // ── Today tab ──────────────────────────────────────────────────────────────────
  Widget _todayContent() {
    var pending = _pendingIdx;
    var done    = _doneIdx;
    if (_areaFilter.isNotEmpty) {
      pending = pending.where((i) => _tasks[i].area == _areaFilter).toList();
      done    = done.where((i) => _tasks[i].area == _areaFilter).toList();
    }
    pending = _rankForFocus(pending);
    final focus = pending.take(5).toList();
    final rest  = pending.skip(5).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _areaFilterRow(),
      const SizedBox(height: 12),
      if (pending.isEmpty && done.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(child: Text('ยังไม่มีงาน กด + เพื่อเพิ่ม',
            style: TextStyle(fontSize: 13, color: _cText.withValues(alpha: .4)))),
        )
      else ...[
        if (focus.isNotEmpty) ...[
          _sectionLabel('โฟกัสวันนี้ · ${focus.length} งาน'),
          const SizedBox(height: 10),
          ...focus.asMap().entries.map((e) => _staggered(e.key, _taskCard(e.value, done: false))),
        ],
        if (rest.isNotEmpty) ...[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _showAllPending = !_showAllPending),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_showAllPending ? 'ซ่อนงานที่เหลือ ▴' : 'งานที่เหลือ · ${rest.length} งาน ▾',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _cGoldDark)),
            ),
          ),
          if (_showAllPending) ...rest.map((i) => _taskCard(i, done: false)),
        ],
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
                  onTap: () { setState(() { t.tag = null; t.tagBg = null; t.tagColor = null; t.lastUpdatedAt = DateTime.now(); }); _saveTasks(); },
                  child: Text('อัปเดตแล้ว', style: TextStyle(fontSize: 11, color: _cGoldDark, fontWeight: FontWeight.w600)),
                ),
              ]),
            );
          }),
        ],
      ],
    ]);
  }

  // เรียงงานค้างตามความเร่งด่วน: เกินกำหนด → วันนี้ → ภายใน 2 วัน → ตามความสำคัญ
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

  Widget _areaFilterRow() {
    const areas  = ['', 'สอน', 'ส่วนตัว', 'บ้าน'];
    const labels = ['ทั้งหมด', 'สอน', 'ส่วนตัว', 'บ้าน'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: List.generate(areas.length, (i) {
        final active = _areaFilter == areas[i];
        return GestureDetector(
          onTap: () => setState(() => _areaFilter = areas[i]),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: EdgeInsets.only(right: i < areas.length - 1 ? 7 : 0),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
            decoration: BoxDecoration(
              color: active ? _cGreen.withValues(alpha: .15) : _cText.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: active ? _cGreen.withValues(alpha: .4) : _cText.withValues(alpha: .08)),
            ),
            child: Text(labels[i], style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
              color: active ? _cGreenDark : _cText.withValues(alpha: .5))),
          ),
        );
      })),
    );
  }

  // ── Inbox tab ──────────────────────────────────────────────────────────────────
  Widget _inboxContent() {
    final indices = _inboxIdx;
    if (indices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(child: Column(children: [
          Text('inbox ว่างเปล่า', style: TextStyle(fontSize: 14, color: _cText.withValues(alpha: .4))),
          const SizedBox(height: 4),
          Text('กด + เพื่อจับความคิดใหม่', style: TextStyle(fontSize: 12, color: _cText.withValues(alpha: .28))),
        ])),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('${indices.length} รายการรอคัดแยก'),
      const SizedBox(height: 10),
      ...indices.asMap().entries.map((e) => _staggered(e.key, _inboxCard(e.value))),
    ]);
  }

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
            onTap: () { setState(() => _tasks[i].type = 'idea'); _saveTasks(); }),
          const SizedBox(width: 7),
          _quickBtn('⏳ รอ', _cText.withValues(alpha: .06), _cText.withValues(alpha: .5), _cText.withValues(alpha: .12),
            onTap: () { setState(() => _tasks[i].type = 'waiting'); _saveTasks(); }),
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
                setState(() {
                  _tasks[i].type = 'task';
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
                    setState(() { t.type = 'task'; t.meta = ''; t.reviewCount = 0; t.lastUpdatedAt = DateTime.now(); });
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
              onDelete: () { NotificationService.cancel(t.id); setState(() => _tasks.remove(t)); _saveTasks(); _updateWidget(); },
              onChanged: () { _saveTasks(); _updateWidget(); setState(() {}); },
            ))).then((_) => setState(() {})),
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
                  setState(() { t.reviewCount++; t.lastUpdatedAt = DateTime.now(); });
                  _saveTasks();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('★', style: TextStyle(fontSize: 13,
                    color: t.reviewCount > 0 ? _cGoldDark : _cText.withValues(alpha: .25))),
                ),
              ),
              GestureDetector(
                onTap: () { setState(() => _tasks[i].type = 'inbox'); _saveTasks(); setState(() => _tabIdx = 1); },
                child: Text('→ inbox', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _cGoldDark)),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  setState(() { t.archivedAt = DateTime.now(); });
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
              onTap: () { setState(() { t.archivedAt = null; t.lastUpdatedAt = DateTime.now(); }); _saveTasks(); },
              child: Text('กู้คืน', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _cGoldDark)),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () { NotificationService.cancel(t.id); setState(() => _tasks.removeAt(i)); _saveTasks(); _updateWidget(); },
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
              onTap: () => setState(() => _historyFilter = f),
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
        if (t.tag != null)
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: t.tagBg, borderRadius: BorderRadius.circular(999)),
            child: Text(t.tag!, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: t.tagColor))),
      ]),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────
  Widget _header(int remaining) {
    final now = DateTime.now();
    final weekdayTh = ['จันทร์','อังคาร','พุธ','พฤหัส','ศุกร์','เสาร์','อาทิตย์'][now.weekday - 1];
    final monthTh   = ['ม.ค.','ก.พ.','มี.ค.','เม.ย.','พ.ค.','มิ.ย.','ก.ค.','ส.ค.','ก.ย.','ต.ค.','พ.ย.','ธ.ค.'][now.month - 1];
    final dateStr   = '$weekdayTh ${now.day} $monthTh';
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(dateStr, style: const TextStyle(fontSize: 10.5, color: _cGoldDark, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        if (_userName.isNotEmpty)
          Text('สวัสดี $_userName', style: TextStyle(fontSize: 12, color: _cText.withValues(alpha: .45))),
        const SizedBox(height: 2),
        Text('เหลือ $remaining งาน', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _cText)),
      ]),
      Row(children: [
        GestureDetector(
          onTap: _openSettings,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _cText.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.settings_outlined, size: 17, color: _cText.withValues(alpha: .55)),
          ),
        ),
      ]),
    ]);
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
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
        TaskDetailScreen(
          task: t,
          taskIndex: i,
          onDelete: () {
            NotificationService.cancel(t.id);
            setState(() => _tasks.remove(t));
            _saveTasks();
            _updateWidget();
          },
          onChanged: () { _saveTasks(); setState(() {}); },
        )
      )).then((_) => setState(() {})),
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
                  Text(t.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                    color: done ? _cText.withValues(alpha: .4) : _cText, height: 1.35,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: _cText.withValues(alpha: .4))),
                  const SizedBox(height: 4),
                  Text(t.meta, style: TextStyle(fontSize: 10.5,
                    color: (!done && t.warn) ? _cRed : _cText.withValues(alpha: done ? .32 : .5))),
                  if (t.deadline != null && !done) ...[
                    const SizedBox(height: 5),
                    _deadlineBadge(t.deadline!),
                  ],
                  if (t.subTasks.isNotEmpty && !_expandedCards.contains(t.id)) ...[
                    const SizedBox(height: 5),
                    _subTaskProgress(t.subTasks),
                  ],
                ])),
                if (t.tag != null) ...[
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: t.tagBg, borderRadius: BorderRadius.circular(999)),
                    child: Text(t.tag!, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: t.tagColor))),
                ],
                // expand toggle
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() {
                    if (_expandedCards.contains(t.id)) _expandedCards.remove(t.id);
                    else _expandedCards.add(t.id);
                  }),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 2, 0),
                    child: Icon(
                      _expandedCards.contains(t.id) ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 18, color: _cText.withValues(alpha: .28),
                    ),
                  ),
                ),
              ]),
              if (_expandedCards.contains(t.id)) ...[
                Divider(color: _cText.withValues(alpha: .07), height: 18),
                ...t.subTasks.map((s) => SubTaskTile(
                  sub: s, depth: 0,
                  onChanged: () { _saveTasks(); setState(() {}); },
                  onDelete: () { setState(() => t.subTasks.remove(s)); _saveTasks(); },
                )),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () { setState(() => t.subTasks.add(SubTask(title: 'ขั้นตอนใหม่'))); _saveTasks(); },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 2, left: 2),
                    child: Text('+ เพิ่มขั้นตอน',
                      style: TextStyle(fontSize: 12, color: _cText.withValues(alpha: .3))),
                  ),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
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


  Widget _sheetField(TextEditingController ctrl, String hint, {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl, keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, color: _cText),
      decoration: InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: _cText.withValues(alpha: .35)),
        filled: true, fillColor: _cBg,
        contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _cGoldDark, width: 1.5)),
      ),
    );
  }

  Widget _sectionLabel(String text) =>
    Text(text, style: TextStyle(fontSize: 10, color: _cText.withValues(alpha: .38), fontWeight: FontWeight.w500));
}

