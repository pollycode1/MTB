import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'models.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  // HomeScreen ตั้งไว้ให้เปิดหน้าสรุปสัปดาห์เมื่อกดแจ้งเตือนรีวิว
  static void Function()? onWeeklyTap;
  static void Function()? onPlanTap;
  static const planReminderHour = 7; // เตือนวางแผนทุกวัน 07:00

  static Future<void> init() async {
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (r) {
        if (r.payload == 'weekly') onWeeklyTap?.call();
        if (r.payload == 'plan') onPlanTap?.call();
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  // payload ของแจ้งเตือนที่เปิดแอพขึ้นมาตอนปิดอยู่ ('weekly' | 'plan' | null)
  static Future<String?> launchPayload() async {
    final d = await _plugin.getNotificationAppLaunchDetails();
    return d?.didNotificationLaunchApp == true ? d?.notificationResponse?.payload : null;
  }

  // priority 1=สูง → แจ้ง 24h+1h ก่อน, 2=กลาง → 3h ก่อน, 3=ต่ำ → 1h ก่อน
  static Future<void> scheduleDeadline(int id, TaskItem task) async {
    if (!_ready || task.deadline == null || task.done) return;
    final deadline = task.deadline!;
    final now = DateTime.now();

    final leadHours = task.priority == 1 ? 24 : task.priority == 3 ? 1 : 3;
    final notifyAt = deadline.subtract(Duration(hours: leadHours));
    if (notifyAt.isAfter(now)) {
      await _plugin.zonedSchedule(
        id,
        'กำหนดส่งงานใกล้แล้ว',
        task.title,
        tz.TZDateTime.from(notifyAt, tz.local),
        const NotificationDetails(android: AndroidNotificationDetails(
          'task_deadline', 'กำหนดส่งงาน',
          channelDescription: 'แจ้งเตือนเมื่องานใกล้ถึงกำหนด',
          importance: Importance.high, priority: Priority.high,
        )),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
    // priority สูง: แจ้งอีกครั้ง 1h ก่อนด้วย (id offset +10000)
    if (task.priority == 1) {
      final notifyAt1h = deadline.subtract(const Duration(hours: 1));
      if (notifyAt1h.isAfter(now)) {
        await _plugin.zonedSchedule(
          id + 10000,
          '⚠️ งานสำคัญ — ใกล้ถึงกำหนดแล้ว',
          task.title,
          tz.TZDateTime.from(notifyAt1h, tz.local),
          const NotificationDetails(android: AndroidNotificationDetails(
            'task_deadline', 'กำหนดส่งงาน',
            importance: Importance.max, priority: Priority.max,
          )),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }

  static Future<void> cancel(int id) async {
    if (!_ready) return;
    await _plugin.cancel(id);
    await _plugin.cancel(id + 10000); // priority-1 extra reminder
  }

  static Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  // ตั้งแจ้งเตือนประจำ 2 อย่าง: รีวิวรายสัปดาห์ (9999) และวางแผนทุกเช้า (9998)
  static Future<void> scheduleWeeklyReview() async {
    if (!_ready) return;
    await _schedulePlanReminder();
    await _plugin.cancel(9999);
    final now = DateTime.now();
    final daysUntil = (7 - now.weekday) % 7;
    var next = now.add(Duration(days: daysUntil == 0 ? 7 : daysUntil));
    next = DateTime(next.year, next.month, next.day, 9, 0);
    await _plugin.zonedSchedule(
      9999,
      'Weekly Review',
      'ดูสรุปสัปดาห์ + เคลียร์กล่องรับ',
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
      payload: 'weekly',
    );
  }

  static Future<void> _schedulePlanReminder() async {
    await _plugin.cancel(9998);
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, planReminderHour);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      9998,
      'วางแผนวันนี้',
      'เลือกงานที่จะทำวันนี้ และงานกบ 🐸',
      tz.TZDateTime.from(next, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'plan_reminder', 'วางแผนทุกเช้า',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'plan',
    );
  }
}
