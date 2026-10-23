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
  SubTask({required this.title, this.done = false, List<SubTask>? children})
      : children = children ?? [];

  Map<String, dynamic> toJson() => {
    'title': title, 'done': done,
    'children': children.map((c) => c.toJson()).toList(),
  };

  factory SubTask.fromJson(Map<String, dynamic> j) => SubTask(
    title: j['title'] as String,
    done: j['done'] as bool? ?? false,
    children: (j['children'] as List? ?? [])
        .map((c) => SubTask.fromJson(c as Map<String, dynamic>)).toList(),
  );
}

// type values: 'inbox' | 'task' | 'idea' | 'waiting'
// recurrence values: 'daily' | 'weekly' | 'monthly' | 'yearly'
class TaskItem {
  String title, meta;
  bool warn, done;
  String? tag;
  Color? tagBg, tagColor;
  DateTime? doneAt;
  DateTime? deadline;
  String? recurrence;
  String type;       // 'inbox' | 'task' | 'idea' | 'waiting'
  String? nextAction;
  String? area;      // 'สอน' | 'ส่วนตัว' | 'บ้าน' | null
  int priority;      // 1=สูง 2=กลาง 3=ต่ำ
  DateTime? lastUpdatedAt;
  int reviewCount;   // idea resurface counter
  DateTime? archivedAt;
  DateTime? plannedFor; // วันที่เลือกไว้ในแผนเช้า (เทียบเฉพาะวัน)
  bool isFrog;          // งานกบของวัน
  final List<SubTask> subTasks;
  // รหัสประจำงาน — ใช้เป็น notification id และ key ของ UI แทนลำดับในลิสต์
  final int id;

  static int _lastId = 0;
  static int _genId() {
    var v = 100000 + DateTime.now().microsecondsSinceEpoch % 1000000000;
    if (v <= _lastId) v = _lastId + 1;
    _lastId = v;
    return v;
  }

  TaskItem({
    int? id,
    required this.title,
    this.meta = '',
    this.warn = false,
    this.done = false,
    this.tag,
    this.tagBg,
    this.tagColor,
    this.doneAt,
    this.deadline,
    this.recurrence,
    this.type = 'task',
    this.nextAction,
    this.area,
    this.priority = 2,
    this.lastUpdatedAt,
    this.reviewCount = 0,
    this.archivedAt,
    this.plannedFor,
    this.isFrog = false,
    List<SubTask>? subTasks,
  }) : id = id ?? _genId(),
       subTasks = subTasks ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'meta': meta,
    'warn': warn,
    'done': done,
    'tag': tag,
    'tagBg': tagBg?.value,
    'tagColor': tagColor?.value,
    'doneAt': doneAt?.toIso8601String(),
    'deadline': deadline?.toIso8601String(),
    'recurrence': recurrence,
    'type': type,
    'nextAction': nextAction,
    'area': area,
    'priority': priority,
    'lastUpdatedAt': lastUpdatedAt?.toIso8601String(),
    'reviewCount': reviewCount,
    'archivedAt': archivedAt?.toIso8601String(),
    'plannedFor': plannedFor?.toIso8601String(),
    'isFrog': isFrog,
    'subTasks': subTasks.map((s) => s.toJson()).toList(),
  };

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
    id: (j['id'] as num?)?.toInt(),
    title: j['title'] as String,
    meta: j['meta'] as String? ?? '',
    warn: j['warn'] as bool? ?? false,
    done: j['done'] as bool? ?? false,
    tag: j['tag'] as String?,
    tagBg: j['tagBg'] != null ? Color(j['tagBg'] as int) : null,
    tagColor: j['tagColor'] != null ? Color(j['tagColor'] as int) : null,
    doneAt: j['doneAt'] != null ? DateTime.tryParse(j['doneAt'] as String) : null,
    deadline: j['deadline'] != null ? DateTime.tryParse(j['deadline'] as String) : null,
    recurrence: j['recurrence'] as String?,
    type: j['type'] as String? ?? 'task',
    nextAction: j['nextAction'] as String?,
    area: j['area'] as String?,
    priority: j['priority'] as int? ?? 2,
    lastUpdatedAt: j['lastUpdatedAt'] != null ? DateTime.tryParse(j['lastUpdatedAt'] as String) : null,
    reviewCount: j['reviewCount'] as int? ?? 0,
    archivedAt: j['archivedAt'] != null ? DateTime.tryParse(j['archivedAt'] as String) : null,
    plannedFor: j['plannedFor'] != null ? DateTime.tryParse(j['plannedFor'] as String) : null,
    isFrog: j['isFrog'] as bool? ?? false,
    subTasks: (j['subTasks'] as List? ?? [])
        .map((s) => SubTask.fromJson(s as Map<String, dynamic>)).toList(),
  );
}
