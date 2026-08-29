import 'package:flutter/material.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const kCBg        = Color(0xFFF4EEDF);
const kCSurf      = Color(0xFFFBF8F0);
const kCText      = Color(0xFF20291F);
const kCGold      = Color(0xFFD8A93F);
const kCGoldDark  = Color(0xFFB98A2E);
const kCGoldLight = Color(0xFFF7DF9E);
const kCCream     = Color(0xFFF1EAD9);
const kCGreen     = Color(0xFF4F7A5B);
const kCGreenDk   = Color(0xFF3F6349);
const kCRed       = Color(0xFFB7503A);
const kCDark      = Color(0xFF0E120C);
const kMono       = 'IBM Plex Mono';

// ── Models ────────────────────────────────────────────────────────────────────
class SubTask {
  String title;
  bool done;
  final List<SubTask> children;
  SubTask({required this.title, this.done = false}) : children = [];
}

class TaskItem {
  String title, meta;
  bool warn, done;
  String? tag;
  Color? tagBg, tagColor;
  int? budget;
  DateTime? doneAt;
  final List<SubTask> subTasks;

  TaskItem({
    required this.title,
    required this.meta,
    this.warn = false,
    this.done = false,
    this.tag,
    this.tagBg,
    this.tagColor,
    this.budget,
    List<SubTask>? subTasks,
  }) : subTasks = subTasks ?? [];
}

class HabitItem {
  String title;
  int streak;
  bool doneToday;
  HabitItem({required this.title, this.streak = 0, this.doneToday = false});
}

class ExpenseItem {
  String label;
  int amount;
  final DateTime time;
  ExpenseItem(this.label, this.amount) : time = DateTime.now();
}
