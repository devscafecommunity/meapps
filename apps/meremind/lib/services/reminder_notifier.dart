import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Delivers reminders as system notifications. The store talks to this
/// interface only, so tests and unsupported platforms use [NoopReminderNotifier].
abstract interface class ReminderNotifier {
  Future<void> init();

  /// Schedules (or re-schedules) the notification for a reminder.
  Future<void> schedule({
    required String id,
    required String title,
    required DateTime when,
  });

  Future<void> cancel(String id);
  Future<void> cancelAll();

  /// Picks the implementation for the current platform.
  factory ReminderNotifier.platform() {
    if (kIsWeb) return NoopReminderNotifier();
    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS => LocalReminderNotifier(),
      // Linux / Windows plugins cannot schedule notifications for later.
      _ => NoopReminderNotifier(),
    };
  }
}

class NoopReminderNotifier implements ReminderNotifier {
  @override
  Future<void> init() async {}
  @override
  Future<void> schedule({
    required String id,
    required String title,
    required DateTime when,
  }) async {}
  @override
  Future<void> cancel(String id) async {}
  @override
  Future<void> cancelAll() async {}
}

/// Stable 31-bit notification id derived from the reminder's string id
/// (FNV-1a), so the same reminder always maps to the same notification.
int notificationIdFor(String id) {
  var hash = 0x811c9dc5;
  for (final unit in id.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

class LocalReminderNotifier implements ReminderNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  AndroidScheduleMode _mode = AndroidScheduleMode.inexactAllowWhileIdle;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Lembretes',
      channelDescription: 'Avisos dos lembretes do MeRemind',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
  );

  @override
  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } on Object catch (e) {
      // Unknown zone name: keep UTC; the absolute instant is still right.
      debugPrint('meremind: timezone fallback to UTC ($e)');
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
      ),
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      await android.requestNotificationsPermission();
      if (await android.canScheduleExactNotifications() ?? false) {
        _mode = AndroidScheduleMode.exactAllowWhileIdle;
      }
    }
    _ready = true;
  }

  @override
  Future<void> schedule({
    required String id,
    required String title,
    required DateTime when,
  }) async {
    if (!_ready) return;
    final nid = notificationIdFor(id);
    if (!when.isAfter(DateTime.now())) {
      await _plugin.cancel(id: nid);
      return;
    }
    await _plugin.zonedSchedule(
      id: nid,
      title: title,
      body: 'Lembrete',
      payload: id,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: _details,
      androidScheduleMode: _mode,
    );
  }

  @override
  Future<void> cancel(String id) async {
    if (!_ready) return;
    await _plugin.cancel(id: notificationIdFor(id));
  }

  @override
  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }
}
