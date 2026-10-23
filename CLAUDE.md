# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get          # install dependencies
flutter run              # run on connected device/emulator
flutter build apk        # build Android APK
flutter analyze          # lint (flutter_lints)
flutter test             # run tests
```

## Architecture

Single-screen Flutter app — no routing library, no state management package. Everything flows through `HomeScreen` in `lib/home_screen.dart` (settings and task detail are pushed as plain routes).

**State lives in `_HomeScreenState`** — `_tasks` is a plain Dart lists mutated directly and re-persisted via `SharedPreferences` on every change (`tasks_json`). No streams, no ChangeNotifier. Habits were removed; there is no habit model or tab.

**Five tabs** (index → builder in `_buildMain()`): 0 วันนี้ (`_todayContent`), 1 กล่องรับ (`_inboxContent`), 2 ไอเดีย (`_ideaContent`), 3 ประวัติ (`_historyContent`), 4 เก็บถาวร (`_archivedContent`).

**GTD flow** — the + button captures text into the inbox (`type: 'inbox'`). Moving an inbox item to a task (`_moveToTask`) requires a `nextAction` and optionally an `area` (สอน/ส่วนตัว/บ้าน). Other types: `idea` (resurfaces after `reviewCount >= 3`, archived after 60 idle days), `waiting` (flagged "ติดตาม" after 7 idle days). Rules run in `_runRules()` on load. `NotificationService.scheduleWeeklyReview()` posts a weekly reminder (id 9999).

**วันนี้ tab** — pending tasks are ranked by `_rankForFocus` (overdue → due today → due within 2 days → priority). The top 5 are shown as "โฟกัสวันนี้"; the rest sit behind a toggle.

**Android home-screen widgets** — Kotlin AppWidgets (`MtbTasksWidget`, add-task activity) communicate with Flutter via `home_widget` + `SharedPreferences` (app group `group.com.example.mtb`). The Kotlin side reads and rewrites `flutter.tasks_json` and addresses tasks **by list index**; `widgetCallback` in `main.dart` is the background entry point for checkbox toggles. After any state change, call `_updateWidget()`.

**Task ids** — every `TaskItem` has a persistent `id` (generated in `models.dart`, back-filled on load for old data or tasks added by the widget). Use `task.id` for notification ids (`NotificationService.scheduleDeadline(task.id, task)` / `.cancel(task.id)`; priority-1 tasks also use `id + 10000`) and for UI keys such as `_expandedCards`. Never use the list index for either — deleting a task shifts indices. When ids are missing on load, `_migrateNotificationIds()` cancels everything and reschedules. The widget's index-based toggle is the one remaining index dependency.

**Recurrence** — when a recurring task (`TaskItem.recurrence != null`) is toggled done, `_HomeScreenState._toggle()` appends a cloned task (keeping priority, area, nextAction) with the next deadline. No separate recurring-task model.

## Models (`lib/models.dart`)

- `TaskItem` — serializable to/from JSON, including `id` and `subTasks`.
- Color constants (`kC*`) and font constant (`kMono = 'IBM Plex Mono'`) live here and are imported everywhere.

## Key wiring points

- Widget → Flutter: `HomeWidget.widgetClicked` stream → `_handleWidgetLaunch` in `HomeScreen`
- Flutter → Widget: `HomeWidget.saveWidgetData(key, value)` then `HomeWidget.updateWidget(androidName:)`
- Notifications: called from `_toggle()`, `TaskDetailScreen._save()` / `_pickDeadline()` / `_clearDeadline()`, and the delete handlers
