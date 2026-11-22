import 'package:flutter/services.dart';
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
  static void Function()? onLaundryNextRound; // กด "เริ่มรอบ 2" ในแจ้งเตือน
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
        if (r.actionId == _nextRoundAction) {
          onLaundryNextRound?.call();
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

  // payload ของแจ้งเตือนที่เปิดแอพขึ้นมาตอนปิดอยู่ ('weekly' | 'plan' | 'lastyear' | 'laundry' | 'laundry_water_off' | 'laundry_next_round' | null)
  static Future<String?> launchPayload() async {
    final d = await _plugin.getNotificationAppLaunchDetails();
    if (d?.didNotificationLaunchApp != true) return null;
    final r = d!.notificationResponse;
    return switch (r?.actionId) {
      _waterOffAction => 'laundry_water_off',
      _nextRoundAction => 'laundry_next_round',
      _ => r?.payload,
    };
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
    await Laundry.resync(); // ล้างแจ้งเตือนทั้งหมดมา → ตั้งของรอบซักผ้าที่ค้างอยู่กลับ
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
  // 9988 = สถานะนับถอยหลังค้างไว้ใน status bar ของขั้นที่กำลังทำอยู่ (เงียบ ไม่มีเสียง/ปุ่ม อัปเดต/แทนที่ตอนเปลี่ยนขั้น)
  // 9990 = ปล่อยน้ำเข้าครบ (มีปุ่มปิดน้ำแล้ว) · 9991–9993 = ถามซ้ำทุก nagEvery นาทีถ้ายังไม่กด
  // 9994–9996 = ขั้นหลังปิดน้ำครบ (รอบ 1 แช่/ปั่น/ปล่อยออก · รอบ 2 ปั่นกับน้ำยา/ปล่อยออก) — ทีละรอบ จึงใช้ id ซ้ำได้ · 9997 = เตือนวันซักผ้าทุกเสาร์
  static const _waterOffAction = 'water_off', _nextRoundAction = 'next_round';
  static const _laundryCountdownId = 9988;
  static const _laundryFillId = 9990, _laundryNagCount = 3, _laundryWashId = 9994, laundryDayId = 9997;

  // แจ้งเตือนค้างไว้ (ongoing) โชว์นาฬิกานับถอยหลังของขั้นที่กำลังทำอยู่ใน status bar · เงียบ ไม่ปลุก ไม่มีปุ่ม
  static NotificationDetails _laundryCountdownDetails(DateTime end) => NotificationDetails(android: AndroidNotificationDetails(
    'laundry_countdown', 'นับถอยหลังซักผ้า',
    channelDescription: 'ค้างไว้ใน status bar ระหว่างจับเวลาแต่ละขั้น',
    importance: Importance.low, priority: Priority.low,
    playSound: false, enableVibration: false, ongoing: true, onlyAlertOnce: true,
    showWhen: true, when: end.millisecondsSinceEpoch, usesChronometer: true, chronometerCountDown: true,
  ));

  static Future<void> _showLaundryCountdownNow(String title, DateTime end) =>
      _plugin.show(_laundryCountdownId, title, null, _laundryCountdownDetails(end));

  static Future<void> _scheduleLaundryCountdownAt(DateTime start, String title, DateTime end) => _plugin.zonedSchedule(
    _laundryCountdownId, title, null, tz.TZDateTime.from(start, tz.local), _laundryCountdownDetails(end),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    payload: 'laundry',
  );

  // ขั้นนี้กำลังทำอยู่ตอนนี้ → โชว์นับถอยหลังเลย · ยังไม่เริ่ม → ตั้งให้โผล่ (แทนที่ของขั้นก่อน) ตอนขั้นนี้เริ่ม
  static Future<void> _showOrScheduleLaundryCountdown(LaundryStep step, DateTime start, DateTime end, DateTime now) async {
    if (!end.isAfter(now)) return;
    final title = '${step.emoji} กำลัง${step.label}';
    if (!start.isAfter(now)) {
      await _showLaundryCountdownNow(title, end);
    } else {
      await _scheduleLaundryCountdownAt(start, title, end);
    }
  }

  static Future<void> _laundryAt(int id, DateTime at, String title, String body, {bool askWaterOff = false, bool nextRound = false}) async {
    NotifLog.add(NotifEntry(id, at, title, body, payload: 'laundry'));
    final details = NotificationDetails(android: AndroidNotificationDetails(
      'laundry_alarm', 'ซักผ้า (เสียงปลุก)',
      // ดังที่ "ระดับเสียงปลุก" เดิมของเครื่องเท่านั้น — ห้ามเพิ่มโค้ดดันเสียงเครื่อง หรือ FLAG_INSISTENT (เสียงวนจนกว่าจะกดปุ่มเดียว เท่านั้นถึงหยุด)
      channelDescription: 'แจ้งเมื่อปล่อยน้ำ/แช่/ปั่นครบเวลา ดังแม้ปิดเสียงแต่ไม่ดันเสียงเครื่อง ปัด/กดอะไรก็หยุดได้',
      importance: Importance.max, priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      actions: [
        if (askWaterOff) const AndroidNotificationAction(_waterOffAction, 'ปิดน้ำแล้ว ✓', showsUserInterface: true, cancelNotification: true),
        if (nextRound) const AndroidNotificationAction(_nextRoundAction, 'เริ่มรอบ 2 (เปิดน้ำแล้ว)', showsUserInterface: true, cancelNotification: true),
      ],
    ));
    Future<void> schedule(AndroidScheduleMode mode) => _plugin.zonedSchedule(
      id, title, body, tz.TZDateTime.from(at, tz.local), details,
      androidScheduleMode: mode,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'laundry',
    );
    try {
      await schedule(AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException {
      // Android 14+ ยังไม่ได้อนุญาต "การปลุกและการช่วยเตือน" → ใช้แบบไม่ตรงเป๊ะแทน (อาจช้าไปบ้าง)
      await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  // [now] = ข้ามอันที่เลยเวลาไปแล้ว (ตอนตั้งใหม่ให้รอบที่ค้างอยู่)
  static Future<void> scheduleLaundryFill(int round, DateTime end, {DateTime? now}) async {
    if (!_ready) return;
    final n = now ?? DateTime.now();
    final fill = laundryRounds[round].fill;
    final (title, body) = laundryEndText(round, fill);
    final every = LaundrySettings.nagEvery;
    for (var i = 0; i <= _laundryNagCount; i++) {
      final at = end.add(Duration(minutes: every * i));
      if (!at.isAfter(n)) continue;
      await _laundryAt(_laundryFillId + i, at,
          i == 0 ? title : '🚰 ยังไม่ได้ปิดน้ำ?',
          i == 0 ? body : 'ปล่อยน้ำเข้าเกินมา ${every * i} นาทีแล้ว', askWaterOff: true);
    }
    await _showOrScheduleLaundryCountdown(fill, n, end, n); // ปล่อยน้ำเข้าเริ่มทันทีที่เรียกเสมอ
    await NotifLog.save();
  }

  static Future<void> scheduleLaundryWash(int round, List<(LaundryStep, DateTime)> ends, {DateTime? now}) async {
    if (!_ready) return;
    final n = now ?? DateTime.now();
    var id = _laundryWashId;
    var start = ends.isEmpty ? n : ends.first.$2.subtract(Duration(minutes: ends.first.$1.minutes));
    for (final (s, at) in ends) {
      final (title, body) = laundryEndText(round, s);
      if (at.isAfter(n)) await _laundryAt(id, at, title, body, nextRound: s.nextRound);
      await _showOrScheduleLaundryCountdown(s, start, at, n);
      start = at;
      id++;
    }
    await NotifLog.save();
  }

  // ยกเลิกตัวจับเวลาซักผ้าทั้งหมด (ไม่รวมเตือนวันเสาร์) + ปิดแจ้งเตือนที่ค้างอยู่บนเครื่อง
  static Future<void> cancelLaundry() async {
    if (!_ready) return;
    await _plugin.cancel(_laundryCountdownId);
    for (var id = _laundryFillId; id < laundryDayId; id++) {
      await _plugin.cancel(id);
    }
    NotifLog.removeFuture((x) => x >= _laundryFillId && x < laundryDayId);
    await NotifLog.save();
  }

  // เปลี่ยนวัน/เวลาวันซักผ้าในหน้าตั้งค่า → ตั้งใหม่
  static Future<void> rescheduleLaundryDay() async {
    if (!_ready) return;
    await _plugin.cancel(laundryDayId);
    await _scheduleLaundryDay();
  }

  static Future<void> _scheduleLaundryDay() async {
    // ตั้งไว้แล้วไม่ต้องตั้งใหม่ — ยกเลิกแล้วคิดจากตอนนี้ จะข้ามวันนี้ถ้าเปิดแอพหลังเวลาเตือน ก่อน Android ส่งแจ้งเตือน
    if ((await _plugin.pendingNotificationRequests()).any((p) => p.id == laundryDayId)) return;
    await _plugin.zonedSchedule(
      laundryDayId,
      '🧺 วันนี้วันซักผ้า',
      'กดเพื่อเริ่มปล่อยน้ำเข้า ${laundryRounds.first.fill.minutes} นาที',
      tz.TZDateTime.from(nextLaundryDay(DateTime.now(), LaundrySettings.weekday, LaundrySettings.hour, LaundrySettings.minute), tz.local),
      const NotificationDetails(android: AndroidNotificationDetails(
        'laundry_day', 'วันซักผ้าประจำสัปดาห์',
        importance: Importance.defaultImportance, priority: Priority.defaultPriority,
      )),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'laundry',
    );
  }
}
