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

Single-screen Flutter app — no routing library, no state management package. Everything flows through `HomeScreen` in `home_screen.dart`.

**State lives in `_HomeScreenState`** — `_tasks`, `_expenses`, `_habits` are plain Dart lists mutated directly and re-persisted via `SharedPreferences` (key `tasks_json`) on every change. No streams, no ChangeNotifier.

**Three tabs inline** — งาน (tasks), นิสัย (habits), ประวัติ (history) — all rendered as `if (_tabIdx == N)` branches inside `_buildMain()`. `habits_screen.dart` exists but is currently unused; the habits UI was moved inline into `HomeScreen`.

**Auto-categorizer** (`_detect` + `_extractAmount` in `home_screen.dart`) — the single text input classifies itself: Thai baht amounts → expense, keyword `งบ`/`budget` → task-with-budget, otherwise → plain task.

**Android home-screen widgets** — two Kotlin AppWidgets (`MtbBudgetWidget`, `MtbTasksWidget`) communicate with Flutter via `home_widget` package + `SharedPreferences` (app group `group.com.example.mtb`). Widget interactions (toggle checkbox) are handled by `widgetCallback` in `main.dart` — a `@pragma('vm:entry-point')` background entry point that runs without the full Flutter app. After any state change, call `_updateWidget()` to push data to both widgets.

**Notification IDs** — `NotificationService` uses the task's list index as the notification ID. This means index-stable operations (toggle, edit) work correctly, but deletions shift IDs. Be aware when inserting/removing tasks mid-list.

**Recurrence** — when a recurring task (`TaskItem.recurrence != null`) is toggled done, `_HomeScreenState._toggle()` auto-appends a cloned task with the next deadline. No separate recurring-task model.

## Models (`lib/models.dart`)

- `TaskItem` — serializable to/from JSON, stored in `tasks_json`. `subTasks` are NOT serialized (field exists, `toJson` omits them — they reset on app restart).
- `HabitItem` / `ExpenseItem` — in-memory only, not persisted.
- Color constants (`kC*`) and font constant (`kMono = 'IBM Plex Mono'`) live here and are imported everywhere.

## Key wiring points

- Widget → Flutter: `HomeWidget.widgetClicked` stream → `_handleWidgetLaunch` in `HomeScreen`
- Flutter → Widget: `HomeWidget.saveWidgetData(key, value)` then `HomeWidget.updateWidget(androidName:)`
- Notifications: `NotificationService.scheduleDeadline(taskIndex, task)` / `.cancel(taskIndex)` — called from `_toggle()` and `TaskDetailScreen._save()`
