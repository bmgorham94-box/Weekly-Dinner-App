import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Daily "show up" nudges — the app's core job is to make consistency
/// frictionless, especially after travel.
class NotificationsService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    try {
      tz.initializeTimeZones();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
      _ready = true;
    } catch (e) {
      debugPrint('Notifications init failed (non-fatal): $e');
    }
  }

  static Future<void> requestPermissions() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Notification permission request failed (non-fatal): $e');
    }
  }

  /// Schedules a daily nudge at [hour]:[minute] local time.
  static Future<void> scheduleDailyNudge({int hour = 8, int minute = 30}) async {
    if (!_ready) await init();
    try {
      await _plugin.zonedSchedule(
        100,
        'The Log',
        "Phase 1 · Show up. Hit protein first — log today's first meal.",
        _nextInstance(hour, minute),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_nudge',
            'Daily nudges',
            channelDescription: 'A daily reminder to log and train.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Schedule nudge failed (non-fatal): $e');
    }
  }

  static tz.TZDateTime _nextInstance(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
