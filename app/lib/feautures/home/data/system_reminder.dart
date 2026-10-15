import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'chat_gateway.dart';

class SystemReminder {
  SystemReminder._();

  static final instance = SystemReminder._();
  static const _prefsKey = 'scheduled_reminder_ids';

  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;
  var _zonesReady = false;

  bool get isReady => _ready;

  Future<void> initialize() async {
    if (_ready || kIsWeb) return;
    try {
      await _prepareZones();
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
        windows: WindowsInitializationSettings(
          appName: 'Track',
          appUserModelId: 'Track.TrackApp',
          guid: 'a7c31e4b-2d58-4f0a-9b16-6e8d4c1a0f73',
        ),
      );
      await _plugin.initialize(settings: settings);
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> showNow(StoredTask task) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: _notificationId(task.id),
        title: task.title,
        body: task.subtitle,
        notificationDetails: _details(),
      );
    } catch (_) {}
  }

  Future<void> cancel(String taskId) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _notificationId(taskId));
    } catch (_) {}
  }

  Future<void> schedule(List<StoredTask> tasks) async {
    if (!_ready) return;
    final now = DateTime.now().toUtc();
    final previous = await _storedIds();
    final keepShown = <String>{
      for (final task in tasks)
        if (_isPast(task, now)) task.id,
    };
    for (final id in previous) {
      if (keepShown.contains(id)) continue;
      try {
        await _plugin.cancel(id: _notificationId(id));
      } catch (_) {}
    }

    final scheduled = <String>[];
    for (final task in tasks) {
      final at = task.remindAt?.toUtc();
      if (at == null || !at.isAfter(now)) continue;
      if (await _scheduleAt(task, at)) scheduled.add(task.id);
    }
    await _storeIds(scheduled);
  }

  Future<bool> _scheduleAt(StoredTask task, DateTime at) async {
    final when = tz.TZDateTime.from(at, tz.UTC);
    final id = _notificationId(task.id);
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: task.title,
        body: task.subtitle,
        scheduledDate: when,
        notificationDetails: _details(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      return true;
    } catch (_) {}
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: task.title,
        body: task.subtitle,
        scheduledDate: when,
        notificationDetails: _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _prepareZones() async {
    if (_zonesReady) return;
    tz_data.initializeTimeZones();
    _zonesReady = true;
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'track_reminders',
        'Напоминания',
        channelDescription: 'Напоминания о задачах',
        importance: Importance.high,
        priority: Priority.high,
        color: Color(0xFFE5E1E4),
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
      windows: WindowsNotificationDetails(
        header: WindowsHeader(
          id: 'track',
          title: 'Track',
          arguments: 'reminder',
        ),
        duration: WindowsNotificationDuration.long,
      ),
    );
  }

  Future<List<String>> _storedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_prefsKey) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _storeIds(List<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, ids);
    } catch (_) {}
  }

  bool _isPast(StoredTask task, DateTime now) {
    final at = task.remindAt?.toUtc();
    return at != null && !at.isAfter(now);
  }

  int _notificationId(String id) {
    var hash = 0;
    for (final unit in id.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
