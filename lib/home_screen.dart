import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'task_detail_screen.dart';
import 'settings_screen.dart';
import 'weekly_summary_screen.dart';
import 'ai_service.dart';
import 'categories.dart';
import 'tags.dart';
import 'search_screen.dart';
import 'share_task.dart';
import 'last_year_screen.dart';
import 'schedule_screen.dart';
import 'notification_service.dart';
part 'home_today.dart';
part 'home_inbox.dart';
part 'home_ideas.dart';
part 'home_history.dart';
part 'home_sheets.dart';
part 'home_plan.dart';

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
  final Set<int> _aiBusy = {}; // id ของรายการในกล่องรับที่ AI กำลังจัดให้
  String _tagFilter = ''; // '' = ทุกแท็ก
  String _period = 'all'; // ตัวกรองแท็บงาน: all | today | week | month (เปิดแอพมาเห็นทั้งหมดก่อน)
  int _tabIdx = 0;
  String _historyFilter = 'เดือนนี้';
  String _areaFilter = '';
  String? _pendingIdeaTitle;
  String? _pendingTaskTitle;
  bool _tasksLoaded = false;

  final List<TaskItem> _tasks = [
    TaskItem(title: 'เตรียมสื่อการสอนคณิต', meta: 'เสร็จ 08:12 · เร็วกว่ากำหนด 48 นาที', done: true),
    TaskItem(title: 'ตรวจใบงาน ป.4 (18 ชุด)', meta: 'เลื่อนมาแล้ว 2 ครั้ง', warn: true,
        tag: 'สอน', tagBg: const Color(0x284F7A5B), tagColor: const Color(0xFF3F6349)),
    TaskItem(title: 'ซื้ออุปกรณ์ทำสื่อ', meta: 'ภายในวันพุธ'),
  ];

  String _userName = '';

  // extensions ใน part ไฟล์เรียก setState ตรงๆ ไม่ได้ (protected)
  void _set(VoidCallback f) => setState(f);

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 30), () { if (mounted) setState(() => _entered = true); });
    WidgetsBinding.instance.addObserver(this);
    HomeWidget.setAppGroupId('group.com.example.mtb');
    NotificationService.scheduleWeeklyReview();
    _loadSettings();
    NotificationService.onWeeklyTap = _openWeeklySummary;
    NotificationService.onPlanTap = _openMorningPlan;
    _loadTasks().then((_) async {
      _tasksLoaded = true;
      Tags.mergeFrom(_tasks);
      if (await AiService.hasKey()) {
        for (final t in _tasks.where((t) => t.aiTodo).toList()) {
          _aiTriage(t);
        }
      }
      // เปิดจากแจ้งเตือนรีวิวรายสัปดาห์ → ไปหน้าสรุปก่อน แทนแผนเช้า
      final launch = await NotificationService.launchPayload();
      if (launch == 'weekly') {
        _openWeeklySummary();
      } else if (launch == 'plan') {
        _openMorningPlan();
      } else {
        _maybeShowMorningPlan();
      }
      Future.delayed(const Duration(milliseconds: 500), _updateWidget);
      if (_pendingTaskTitle != null) {
        final t = _pendingTaskTitle!;
        _pendingTaskTitle = null;
        _openIdeaByTitle(t, type: 'task');
      }
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

  Future<void> _openTaskDetail(TaskItem t) => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailScreen(
    allTasks: _tasks,
    task: t,
    taskIndex: _tasks.indexOf(t),
    onDelete: () {
      NotificationService.cancel(t.id);
      setState(() => _tasks.remove(t));
      _saveTasks();
      _updateWidget();
    },
    onChanged: () { _saveTasks(); _updateWidget(); setState(() {}); },
  ))).then((_) { if (mounted) setState(() {}); });

  void _openSchedule() {
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ScheduleScreen(
      tasks: _tasks,
      onAdd: (t) {
        _set(() => _tasks.add(t));
        _saveTasks();
        _updateWidget();
        AiService.hasKey().then((k) { if (k && mounted) _aiTag(t); }); // ติดแท็กให้ (ไม่ย้ายประเภท/เวลา)
      },
      onOpen: _openTaskDetail,
      onToggle: (t) { final i = _tasks.indexOf(t); if (i >= 0) _toggle(i); },
    ))).then((_) { if (mounted) setState(() {}); });
  }

  void _openSearch() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SearchScreen(tasks: _tasks, onOpen: _openTaskDetail)))
        .then((_) { if (mounted) setState(() {}); });
  }

  void _openWeeklySummary() {
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => WeeklySummaryScreen(tasks: _tasks)));
  }

  void _openSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(
      tasks: _tasks,
      userName: _userName,
      onTasksChanged: () {
        _set(() { if (_areaFilter.isNotEmpty && !Categories.list.contains(_areaFilter)) _areaFilter = ''; });
        _saveTasks();
        _updateWidget();
      },
      onImport: (restored) {
        _set(() {
          _tasks
            ..clear()
            ..addAll(restored);
        });
        _migrateNotificationIds(); // ตั้งแจ้งเตือนใหม่ทั้งหมด + บันทึก
        _updateWidget();
      },
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
      // ข้อมูลเก่าเคยใส่คำว่า "inbox" เป็นหมายเหตุ → ล้างให้ว่าง
      for (final t in _tasks) {
        if (t.meta == 'inbox') t.meta = '';
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
        if (now.difference(last).inDays >= 7 && !t.tags.contains('ติดตาม')) {
          t.tags.add('ติดตาม');
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

  List<String> get _allTags => Tags.list;

  // active tasks (type=task, not done) — used for widget count
  List<int> get _pendingIdx => List.generate(_tasks.length, (i) => i)
      .where((i) => _tasks[i].type == 'task' && !_tasks[i].done && _tasks[i].archivedAt == null).toList();
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
      .where((i) => _tasks[i].type == 'waiting' && _tasks[i].tags.contains('ติดตาม') && !_tasks[i].done && _tasks[i].archivedAt == null).toList();

  void _openIdeaByTitle(String title, {String type = 'idea'}) {
    // ponytail: search after delay so _loadTasks() from didChangeAppLifecycleState can finish first
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final idx = _tasks.indexWhere((t) => t.type == type && t.title == title);
      if (idx < 0) return;
      setState(() => _tabIdx = type == 'idea' ? 2 : 0);
      Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailScreen(allTasks: _tasks, 
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
        final taskTitle = uri.queryParameters['t'];
        if (taskTitle != null && taskTitle.isNotEmpty) {
          if (_tasksLoaded) {
            _openIdeaByTitle(taskTitle, type: 'task');
          } else {
            _pendingTaskTitle = taskTitle;
          }
        }
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
      case 'schedule': // ปุ่มตารางใน widget
        Future.delayed(const Duration(milliseconds: 600), _openSchedule);
      case 'open':
        break;
    }
  }

  Future<void> _updateWidget() async {
    await HomeWidget.saveWidgetData('pending_tasks', _pendingIdx.length);
    await HomeWidget.saveWidgetData('total_tasks', _tasks.length);
    // ลำดับเดียวกับ flutter.tasks_json — widget ติ๊กงานตามดัชนี ห้ามเรียงใหม่ที่นี่ (Kotlin เรียงตอนแสดงเอง)
    final tasksJson = jsonEncode(_tasks.map((t) => t.toJson()).toList());
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
        if (t.recurrence != null && (t.deadline != null || t.slotStart != null)) {
          final next = t.deadline == null ? null : _nextDeadline(t.deadline!, t.recurrence!);
          final nextSlot = t.slotStart == null ? null : _nextDeadline(t.slotStart!, t.recurrence!);
          final clone = TaskItem(
            title: t.title, meta: t.meta, warn: t.warn,
            tags: [...t.tags],
            deadline: next, recurrence: t.recurrence,
            slotStart: nextSlot, slotMin: t.slotMin,
            plannedFor: nextSlot == null ? null : DateTime(nextSlot.year, nextSlot.month, nextSlot.day),
            priority: t.priority, area: t.area, nextAction: t.nextAction,
            lastUpdatedAt: DateTime.now(),
          );
          _tasks.add(clone);
          NotificationService.scheduleDeadline(clone.id, clone);
        }
      } else {
        t.doneAt = null;
        t.actualMin = null;
        NotificationService.scheduleDeadline(t.id, t);
      }
    });
    _saveTasks();
    _updateWidget();
    if (t.done && t.estimateMin != null) _askActualMinutes(t);
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
        _tabBtn(0, 'งาน', badge: _inboxIdx.length),
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
          onTap: _openSchedule,
          child: Container(
            width: 36, height: 36,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _cText.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.calendar_view_week_rounded, size: 18, color: _cText.withValues(alpha: .55)),
          ),
        ),
        GestureDetector(
          onTap: _openSearch,
          child: Container(
            width: 36, height: 36,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _cText.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.search_rounded, size: 18, color: _cText.withValues(alpha: .55)),
          ),
        ),
        GestureDetector(
          onTap: _openWeeklySummary,
          child: Container(
            width: 36, height: 36,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _cText.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.insights_outlined, size: 17, color: _cText.withValues(alpha: .55)),
          ),
        ),
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

