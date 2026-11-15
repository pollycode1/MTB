import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'models.dart';
import 'notif_log.dart';
import 'schedule_data.dart';
import 'last_year_screen.dart' show lastYearReminders;
import 'laundry.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  // HomeScreen ตั้งไว้ให้เปิดหน้าสรุปสัปดาห์เมื่อกดแจ้งเตือนรีวิว
  static void Function()? onWeeklyTap;
  static void Function()? onPlanTap;
  static void Function()? onLastYearTap;
  static void Function()? onLaundryTap;
  static void Function()? onLaundryWaterOff; // กด "ปิดน้ำแล้ว" ในแจ้งเตือน
  static const planReminderHour = 7; // เตือนวางแผนทุกวัน 07:00

  static Future<void> init() async {
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (r) {
        if (r.actionId == _waterOffAction) {
          onLaundryWaterOff?.call();
          return;
        }
        if (r.payload == 'laundry') onLaundryTap?.call();
        if (r.payload == 'weekly') onWeeklyTap?.call();
        if (r.payload == 'plan') onPlanTap?.call();
        if (r.payload == 'lastyear') onLastYearTap?.call();
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await NotifLog.load();
    NotifLog.backfillRepeating(DateTime.now(), planHour: planReminderHour);
    await NotifLog.save();
    _ready = true;
  }

  // payload ของแจ้งเตือนที่เปิดแอพขึ้นมาตอนปิดอยู่ ('weekly' | 'plan' | 'lastyear' | 'laundry' | 'laundry_water_off' | null)
  static Future<String?> launchPayload() async {
    final d = await _plugin.getNotificationAppLaunchDetails();
    if (d?.didNotificationLaunchApp != true) return null;
    final r = d!.notificationResponse;
    return r?.actionId == _waterOffAction ? 'laundry_water_off' : r?.payload;
  }

  // priority 1=สูง → แจ้ง 24h+1h ก่อน, 2=กลาง → 3h ก่อน, 3=ต่ำ → 1h ก่อน
  static Future<void> scheduleDeadline(int id, TaskItem task) async {
    if (!_ready || task.deadline == null || task.done) return;
    final deadline = task.deadline!;
    final now = DateTime.now();

    final leadHours = task.priority == 1 ? 24 : task.priority == 3 ? 1 : 3;
    final notifyAt = deadline.subtract(Duration(hours: leadHours));
    if (notifyAt.isAfter(now)) {
      NotifLog.add(NotifEntry(id, notifyAt, 'กำหนดส่งงานใกล้แล้ว', task.title, taskId: task.id));
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
        NotifLog.add(NotifEntry(id + 10000, notifyAt1h, '⚠️ งานสำคัญ — ใกล้ถึงกำหนดแล้ว', task.title, taskId: task.id));
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
    await NotifLog.save();
  }

  static Future<void> cancel(int id) async {
    if (!_ready) return;
    await _plugin.cancel(id);
    await _plugin.cancel(id + 10000); // priority-1 extra reminder
    NotifLog.removeFuture((x) => x == id || x == id + 10000);
    await NotifLog.save();
  }

  static Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
    NotifLog.removeFuture((_) => true);
    await NotifLog.save();
  }

  // ── แจ้งเตือนที่คิดจากข้อมูล (ก่อนคาบ ฯลฯ) id 20000–29999 · ลบของเดิมแล้วตั้งใหม่ทั้งชุด ─────
  // เรียกตอนเปิดแอพ/กลับเข้าแอพ/ออกจากแอพ/ปิดหน้าตาราง ข้อความจะได้ตรงกับงานค้างล่าสุด
  static const _derivedBase = 20000;

  static Future<void> rescheduleDerived(List<TaskItem> tasks) async {
    if (!_ready) return;
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (p.id >= _derivedBase && p.id < _derivedBase + 10000) await _plugin.cancel(p.id);
    }
    NotifLog.removeFuture((x) => x >= _derivedBase && x < _derivedBase + 10000);
    var id = _derivedBase;
    for (final r in classReminders(ScheduleStore.blocks, tasks, DateTime.now())) {
      NotifLog.add(NotifEntry(id, r.at, r.title, r.body));
      await _plugin.zonedSchedule(
        id++, r.title, r.body,
        tz.TZDateTime.from(r.at, tz.local),
        const NotificationDetails(android: AndroidNotificationDetails(
          'class_reminder', 'เตือนก่อนคาบ',
          channelDescription: 'แจ้งก่อนเริ่มคาบสอน/งานพิเศษ 10 นาที พร้อมงานค้างของห้อง',
          importance: Importance.high, priority: Priority.high,
        )),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
    for (final r in lastYearReminders(tasks, DateTime.now())) {
      NotifLog.add(NotifEntry(id, r.at, r.title, r.body, payload: 'lastyear'));
      await _plugin.zonedSchedule(
        id++, r.title, r.body,
        tz.TZDateTime.from(r.at, tz.local),
        const NotificationDetails(android: AndroidNotificationDetails(
          'last_year', 'ปีที่แล้ววันนี้',
          channelDescription: 'งานที่ทำในวัน/เดือนเดียวกันของปีที่แล้ว',
          importance: Importance.defaultImportance, priority: Priority.defaultPriority,
        )),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'lastyear',
      );
    }
    await NotifLog.save();
  }

  // ตั้งแจ้งเตือนประจำ 3 อย่าง: รีวิวรายสัปดาห์ (9999) วางแผนทุกเช้า (9998) และวันซักผ้าทุกเสาร์ (9997)
  static Future<void> scheduleWeeklyReview() async {
    if (!_ready) return;
    await _schedulePlanReminder();
    await _scheduleLaundryDay();
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

  // ── ซักผ้า ─────────────────────────────────────────────────────────────────
  // 9990 = ปล่อยน้ำเข้าครบ (มีปุ่มปิดน้ำแล้ว) · 9991–9993 = ถามซ้ำทุก 2 นาทีถ้ายังไม่กด
  // 9994–9996 = แช่/ปั่น/ปล่อยน้ำออกครบ · 9997 = เตือนวันซักผ้าทุกเสาร์
  static const _waterOffAction = 'water_off';
  static const _laundryFillId = 9990, _laundryNagCount = 3, _laundryWashId = 9994, laundryDayId = 9997;

  static Future<void> _laundryAt(int id, DateTime at, String title, String body, {bool askWaterOff = false}) async {
    NotifLog.add(NotifEntry(id, at, title, body, payload: 'laundry'));
    await _plugin.zonedSchedule(
      id, title, body,
      tz.TZDateTime.from(at, tz.local),
      NotificationDetails(android: AndroidNotificationDetails(
        'laundry_timer', 'จับเวลาซักผ้า',
        channelDescription: 'แจ้งเมื่อปล่อยน้ำ/แช่/ปั่นครบเวลา',
        importance: Importance.max, priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        actions: askWaterOff
            ? const [AndroidNotificationAction(_waterOffAction, 'ปิดน้ำแล้ว ✓', showsUserInterface: true, cancelNotification: true)]
            : null,
      )),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'laundry',
    );
  }

  static Future<void> scheduleLaundryFill(DateTime end) async {
    if (!_ready) return;
    await _laundryAt(_laundryFillId, end, laundryFill.endTitle, laundryFill.endBody, askWaterOff: true);
    for (var i = 1; i <= _laundryNagCount; i++) {
      await _laundryAt(_laundryFillId + i, end.add(Duration(minutes: 2 * i)),
          '🚰 ยังไม่ได้ปิดน้ำ?', 'ปล่อยน้ำเข้าเกินมา ${2 * i} นาทีแล้ว', askWaterOff: true);
    }
    await NotifLog.save();
  }

  static Future<void> scheduleLaundryWash(List<(LaundryStep, DateTime)> ends) async {
    if (!_ready) return;
    var id = _laundryWashId;
    for (final (s, at) in ends) {
      await _laundryAt(id++, at, s.endTitle, s.endBody);
    }
    await NotifLog.save();
  }

  // ยกเลิกตัวจับเวลาซักผ้าทั้งหมด (ไม่รวมเตือนวันเสาร์) + ปิดแจ้งเตือนที่ค้างอยู่บนเครื่อง
  static Future<void> cancelLaundry() async {
    if (!_ready) return;
    for (var id = _laundryFillId; id < laundryDayId; id++) {
      await _plugin.cancel(id);
    }
    NotifLog.removeFuture((x) => x >= _laundryFillId && x < laundryDayId);
    await NotifLog.save();
  }

  static Future<void> _scheduleLaundryDay() async {
    await _plugin.cancel(laundryDayId);
    await _plugin.zonedSchedule(
      laundryDayId,
      '🧺 วันนี้วันซักผ้า',
      'กดเพื่อเริ่มปล่อยน้ำเข้า 5 นาที',
      tz.TZDateTime.from(nextSaturday(DateTime.now(), laundryHour), tz.local),
      const NotificationDetails(android: AndroidNotificationDetails(
        'laundry_day', 'วันซักผ้า (เสาร์)',
        importance: Importance.defaultImportance, priority: Priority.defaultPriority,
      )),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'laundry',
    );
  }
}
