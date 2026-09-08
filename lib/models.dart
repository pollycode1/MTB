import 'package:flutter/material.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const kCBg        = Color(0xFF111111);
const kCSurf      = Color(0xFF1C1C1C);
const kCText      = Color(0xFFE2E2E2);
const kCGold      = Color(0xFFCCCCCC);
const kCGoldDark  = Color(0xFF888888);
const kCGoldLight = Color(0xFFEEEEEE);
const kCCream     = Color(0xFFDDDDDD);  // used as light text inside dark cards
const kCGreen     = Color(0xFF4A7A58);
const kCGreenDk   = Color(0xFF72A880);  // brighter for dark bg legibility
const kCRed       = Color(0xFFD06050);
const kCDark      = Color(0xFF060606);
const kMono       = 'IBM Plex Mono';

// ── Models ────────────────────────────────────────────────────────────────────
class SubTask {
  String title;
  bool done;
  final List<SubTask> children;
  SubTask({required this.title, this.done = false}) : children = [];
}

// type values: 'inbox' | 'task' | 'idea' | 'waiting'
// recurrence values: 'daily' | 'weekly' | 'monthly' | 'yearly'
class TaskItem {
  String title, meta;
  bool warn, done;
  String? tag;
  Color? tagBg, tagColor;
  int? budget;
  DateTime? doneAt;
  DateTime? deadline;
  String? recurrence;
  String type;       // 'inbox' | 'task' | 'idea' | 'waiting'
  String? nextAction;
  String? area;      // 'สอน' | 'ส่วนตัว' | 'บ้าน' | null
  final List<SubTask> subTasks;

  TaskItem({
    required this.title,
    this.meta = '',
    this.warn = false,
    this.done = false,
    this.tag,
    this.tagBg,
    this.tagColor,
    this.budget,
    this.doneAt,
    this.deadline,
    this.recurrence,
    this.type = 'task',
    this.nextAction,
    this.area,
    List<SubTask>? subTasks,
  }) : subTasks = subTasks ?? [];

  Map<String, dynamic> toJson() => {
    'title': title,
    'meta': meta,
    'warn': warn,
    'done': done,
    'tag': tag,
    'tagBg': tagBg?.value,
    'tagColor': tagColor?.value,
    'budget': budget,
    'doneAt': doneAt?.toIso8601String(),
    'deadline': deadline?.toIso8601String(),
    'recurrence': recurrence,
    'type': type,
    'nextAction': nextAction,
    'area': area,
  };

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
    title: j['title'] as String,
    meta: j['meta'] as String? ?? '',
    warn: j['warn'] as bool? ?? false,
    done: j['done'] as bool? ?? false,
    tag: j['tag'] as String?,
    tagBg: j['tagBg'] != null ? Color(j['tagBg'] as int) : null,
    tagColor: j['tagColor'] != null ? Color(j['tagColor'] as int) : null,
    budget: j['budget'] as int?,
    doneAt: j['doneAt'] != null ? DateTime.tryParse(j['doneAt'] as String) : null,
    deadline: j['deadline'] != null ? DateTime.tryParse(j['deadline'] as String) : null,
    recurrence: j['recurrence'] as String?,
    type: j['type'] as String? ?? 'task',
    nextAction: j['nextAction'] as String?,
    area: j['area'] as String?,
  );
}

class ExpenseItem {
  String label;
  int amount;
  final DateTime time;
  ExpenseItem(this.label, this.amount) : time = DateTime.now();
}
