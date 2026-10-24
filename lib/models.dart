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
  String note;
  bool done;
  final List<SubTask> children;
  SubTask({required this.title, this.note = '', this.done = false, List<SubTask>? children})
      : children = children ?? [];

  Map<String, dynamic> toJson() => {
    'title': title, 'done': done,
    if (note.isNotEmpty) 'note': note,
    'children': children.map((c) => c.toJson()).toList(),
  };

  factory SubTask.fromJson(Map<String, dynamic> j) => SubTask(
    title: j['title'] as String,
    note: j['note'] as String? ?? '',
    done: j['done'] as bool? ?? false,
    children: (j['children'] as List? ?? [])
        .map((c) => SubTask.fromJson(c as Map<String, dynamic>)).toList(),
  );
}

// ติ๊ก/ยกเลิกขั้นตอน: ขั้นย่อยทั้งหมดตามไปด้วย แล้วปรับขั้นที่สูงกว่าให้ตรงกัน
void setStepDone(List<SubTask> roots, SubTask s, bool done) {
  void deep(SubTask x) { x.done = done; x.children.forEach(deep); }
  deep(s);
  syncSteps(roots);
}

// ขั้นที่มีขั้นย่อย = เสร็จเมื่อขั้นย่อยเสร็จครบ (คิดจากล่างขึ้นบน)
void syncSteps(List<SubTask> list) {
  for (final s in list) {
    if (s.children.isEmpty) continue;
    syncSteps(s.children);
    s.done = s.children.every((c) => c.done);
  }
}

int countSteps(List<SubTask> list, {bool onlyDone = false}) =>
    list.fold(0, (n, s) => n + ((!onlyDone || s.done) ? 1 : 0) + countSteps(s.children, onlyDone: onlyDone));

// type values: 'inbox' | 'task' | 'idea' | 'waiting'
// recurrence values: 'daily' | 'weekly' | 'monthly' | 'yearly'
class TaskItem {
  String title, meta;
  bool warn, done;
  final List<String> tags; // แท็กทั้งหมดของงาน (หลายแท็กได้)
  Color? tagBg, tagColor; // เลิกใช้แสดงผลแล้ว เก็บไว้ให้ข้อมูลเก่าอ่านได้
  String? get tag => tags.isEmpty ? null : tags.first;
  set tag(String? v) { tags.clear(); if (v != null && v.isNotEmpty) tags.add(v); }
  DateTime? doneAt;
  DateTime? deadline;
  String? recurrence;
  String type;       // 'inbox' | 'task' | 'idea' | 'waiting'
  String? nextAction;
  String? area;      // ชื่อหมวดจาก Categories.list (ตั้งค่า → หมวดหมู่) | null
  int priority;      // 1=สูง 2=กลาง 3=ต่ำ
  DateTime? lastUpdatedAt;
  int reviewCount;   // idea resurface counter
  DateTime? archivedAt;
  DateTime? plannedFor; // วันที่เลือกไว้ในแผนเช้า (เทียบเฉพาะวัน)
  bool isFrog;          // งานกบของวัน
  int postponeCount;    // จำนวนครั้งที่ถูกเลื่อน (ดู home_plan.dart / _pickDeadline)
  int? estimateMin;     // เวลาที่คาดว่าจะใช้ (นาที)
  int? actualMin;       // เวลาที่ใช้จริง ถามตอนกดเสร็จ ถ้ามี estimateMin
  bool aiTodo;          // เพิ่มจาก widget แล้วยังไม่ได้ให้ AI จัดหมวด/ความสำคัญ
  final List<String> attachments; // ไฟล์แนบ: path สัมพัทธ์ใน Attachments.rootPath
  DateTime? slotStart; // ลงเวลาในตาราง (วัน+เวลาเริ่ม)
  int slotMin;         // ระยะเวลาในตาราง (นาที)
  final DateTime createdAt; // ใช้เรียงงานใหม่ไว้บนสุด (ข้อมูลเก่าไม่มี = ถือว่าเก่าที่สุด)
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
    String? tag,
    List<String>? tags,
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
    this.postponeCount = 0,
    this.estimateMin,
    this.actualMin,
    this.aiTodo = false,
    DateTime? createdAt,
    this.slotStart,
    this.slotMin = 60,
    List<String>? attachments,
    List<SubTask>? subTasks,
  }) : id = id ?? _genId(),
       tags = tags ?? [if (tag != null && tag.isNotEmpty) tag],
       createdAt = createdAt ?? DateTime.now(),
       attachments = attachments ?? [],
       subTasks = subTasks ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'meta': meta,
    'warn': warn,
    'done': done,
    'tag': tag, // แท็กแรก ให้ widget/ข้อมูลเก่าอ่านได้
    'tags': tags,
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
    'postponeCount': postponeCount,
    'estimateMin': estimateMin,
    'actualMin': actualMin,
    if (aiTodo) 'aiTodo': true,
    'createdAt': createdAt.toIso8601String(),
    if (slotStart != null) 'slotStart': slotStart!.toIso8601String(),
    if (slotStart != null) 'slotMin': slotMin,
    if (attachments.isNotEmpty) 'attachments': attachments,
    'subTasks': subTasks.map((s) => s.toJson()).toList(),
  };

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
    id: (j['id'] as num?)?.toInt(),
    title: j['title'] as String,
    meta: j['meta'] as String? ?? '',
    warn: j['warn'] as bool? ?? false,
    done: j['done'] as bool? ?? false,
    tags: (j['tags'] as List?)?.cast<String>().toList() ?? [if (j['tag'] is String && (j['tag'] as String).isNotEmpty) j['tag'] as String],
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
    postponeCount: j['postponeCount'] as int? ?? 0,
    estimateMin: (j['estimateMin'] as num?)?.toInt(),
    actualMin: (j['actualMin'] as num?)?.toInt(),
    aiTodo: j['aiTodo'] as bool? ?? false,
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime(2000),
    slotStart: j['slotStart'] != null ? DateTime.tryParse(j['slotStart'] as String) : null,
    slotMin: (j['slotMin'] as num?)?.toInt() ?? 60,
    attachments: (j['attachments'] as List?)?.cast<String>().toList(),
    subTasks: (j['subTasks'] as List? ?? [])
        .map((s) => SubTask.fromJson(s as Map<String, dynamic>)).toList(),
  );
}
