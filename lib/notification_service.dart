import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'models.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  static Future<void> scheduleDeadline(int id, TaskItem task) async {
    if (!_ready || task.deadline == null || task.done) return;
    final deadline = task.deadline!;
    final notifyAt = deadline.subtract(const Duration(hours: 1));
    if (notifyAt.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      id,
      'กำหนดส่งงานใกล้แล้ว',
      task.title,
      tz.TZDateTime.from(notifyAt, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_deadline', 'กำหนดส่งงาน',
          channelDescription: 'แจ้งเตือนเมื่องานใกล้ถึงกำหนด',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancel(int id) async {
    if (!_ready) return;
    await _plugin.cancel(id);
  }

  static Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  static Future<void> scheduleWeeklyReview() async {
    if (!_ready) return;
    await _plugin.cancel(9999);
    final now = DateTime.now();
    final daysUntil = (7 - now.weekday) % 7;
    var next = now.add(Duration(days: daysUntil == 0 ? 7 : daysUntil));
    next = DateTime(next.year, next.month, next.day, 9, 0);
    await _plugin.zonedSchedule(
      9999,
      'Weekly Review',
      'เปิด inbox + idea bucket มาเคลียร์กัน',
      tz.TZDateTime.from(next, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_review', 'Weekly Review',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }
}
