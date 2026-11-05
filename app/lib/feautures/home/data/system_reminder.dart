import 'dart:ui' show Color, DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'chat_gateway.dart';
import 'reminder_controller.dart';
import 'task_calendar.dart';

const _channelId = 'track_reminders_v2';
const _legacyChannelId = 'track_reminders';
final _beat = Int64List.fromList([0, 40, 70, 40, 110, 180]);

bool reminderHandledInsideApp(AppLifecycleState? state) {
  return state == null || state == AppLifecycleState.resumed;
}

String? reminderDismissedId(NotificationResponse response) {
  if (response.notificationResponseType ==
      NotificationResponseType.notificationDismissed) {
    return null;
  }
  final action = response.actionId?.trim();
  final payload = response.payload?.trim();
  if (action == 'dismiss') {
    if (payload == null || payload.isEmpty) return null;
    return payload;
  }
  final raw = action ?? payload ?? '';
  const prefix = 'dismiss:';
  if (!raw.startsWith(prefix)) return null;
  final id = raw.substring(prefix.length).trim();
  return id.isEmpty ? null : id;
}

@pragma('vm:entry-point')
void onReminderBackground(NotificationResponse response) {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final id = reminderDismissedId(response);
  if (id == null) return;
  ReminderController.noteDismissed(id);
}

class SystemReminder {
  SystemReminder._();

  static final instance = SystemReminder._();
  static const _prefsKey = 'scheduled_reminder_ids';

  final _plugin = FlutterLocalNotificationsPlugin();
  final _armed = <String>{};
  final _posted = <String>{};
  var _ready = false;
  var _zonesReady = false;
  var _asking = false;
  var _asked = false;

  bool get isReady => _ready;

  Future<void> initialize() async {
    if (_ready || kIsWeb) return;
    try {
      await _prepareZones();
      final darwin = DarwinInitializationSettings(
        notificationCategories: [
          DarwinNotificationCategory(
            'track_reminder',
            actions: [
              DarwinNotificationAction.plain(
                'dismiss',
                'Понятно',
                options: {DarwinNotificationActionOption.foreground},
              ),
            ],
          ),
        ],
      );
      final settings = InitializationSettings(
        android: const AndroidInitializationSettings('@drawable/ic_stat_track'),
        iOS: darwin,
        macOS: darwin,
        windows: const WindowsInitializationSettings(
          appName: 'Track',
          appUserModelId: 'Track.TrackApp',
          guid: 'a7c31e4b-2d58-4f0a-9b16-6e8d4c1a0f73',
        ),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _onResponse,
        onDidReceiveBackgroundNotificationResponse: onReminderBackground,
      );
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.deleteNotificationChannel(channelId: _legacyChannelId);
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          _channelId,
          'Напоминания',
          description: 'Когда подходит время задачи',
          importance: Importance.max,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('badumtss'),
          enableVibration: true,
          vibrationPattern: _beat,
          audioAttributesUsage: AudioAttributesUsage.notification,
        ),
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final response = launch?.notificationResponse;
      if ((launch?.didNotificationLaunchApp ?? false) && response != null) {
        final id = reminderDismissedId(response);
        if (id != null) await ReminderController.noteDismissed(id);
      }
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  bool shouldPostOutside(String id) {
    return id.isNotEmpty && !_armed.contains(id) && !_posted.contains(id);
  }

  Future<void> requestPermissions() async {
    if (kIsWeb || !_ready || _asked || _asking) return;
    _asking = true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    try {
      try {
        await android?.requestNotificationsPermission();
      } catch (_) {}
      try {
        final exact = await android?.canScheduleExactNotifications();
        if (exact == false) await android?.requestExactAlarmsPermission();
      } catch (_) {}
      try {
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      } catch (_) {}
      try {
        await _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      } catch (_) {}
      _asked = true;
    } finally {
      _asking = false;
    }
  }

  void _onResponse(NotificationResponse response) {
    final id = reminderDismissedId(response);
    if (id == null) return;
    ReminderController.noteDismissed(id);
  }

  Future<void> showNow(StoredTask task, {bool audible = true}) async {
    if (!_ready) return;
    try {
      final copy = _copy(task);
      await _plugin.show(
        id: _notificationId(task.id),
        title: copy.title,
        body: copy.glance,
        notificationDetails: _details(task, copy, audible: audible),
        payload: task.id,
      );
      _posted.add(task.id);
    } catch (_) {}
  }

  Future<void> cancel(String taskId) async {
    _armed.remove(taskId);
    _posted.remove(taskId);
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _notificationId(taskId));
    } catch (_) {}
  }

  Future<void> schedule(List<StoredTask> tasks) async {
    if (!_ready) return;
    await _prepareZones();
    final now = DateTime.now().toUtc();
    final modes = await _scheduleModes();
    final scheduled = <String>[];
    final upcoming = <String>{};
    final keepShown = <String>{
      for (final task in tasks)
        if (_isPast(task, now)) task.id,
    };
    for (final task in tasks) {
      final at = task.remindAt?.toUtc();
      if (at == null || !at.isAfter(now)) continue;
      upcoming.add(task.id);
      if (await _scheduleAt(task, at, modes)) {
        scheduled.add(task.id);
        _armed.add(task.id);
      }
    }

    final previous = await _storedIds();
    final retain = {...scheduled, ...keepShown, ...upcoming};
    for (final id in previous) {
      if (retain.contains(id)) continue;
      _armed.remove(id);
      try {
        await _plugin.cancel(id: _notificationId(id));
      } catch (_) {}
    }
    await _storeIds(scheduled);
  }

  Future<List<AndroidScheduleMode>> _scheduleModes() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const [AndroidScheduleMode.exactAllowWhileIdle];
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    var exact = true;
    try {
      exact = await android?.canScheduleExactNotifications() ?? true;
    } catch (_) {}
    if (!exact) return const [AndroidScheduleMode.inexactAllowWhileIdle];
    return const [
      AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.alarmClock,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ];
  }

  Future<bool> _scheduleAt(
    StoredTask task,
    DateTime at,
    List<AndroidScheduleMode> modes,
  ) async {
    final when = tz.TZDateTime.from(at, tz.UTC);
    final id = _notificationId(task.id);
    final copy = _copy(task);
    final details = _details(task, copy, audible: true);
    for (final mode in modes) {
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: copy.title,
          body: copy.glance,
          scheduledDate: when,
          notificationDetails: details,
          androidScheduleMode: mode,
          payload: task.id,
        );
        return true;
      } catch (_) {}
    }
    return false;
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

  _ReminderCopy _copy(StoredTask task) {
    final time = TaskCalendar.clock(task.remindAt);
    final subtitle = task.subtitle.trim();
    final glance = time != null && time.isNotEmpty
        ? time
        : (subtitle.isEmpty ? 'Пора' : subtitle);
    final detail = subtitle.isEmpty ? glance : subtitle;
    final title = task.title.trim().isEmpty ? glance : task.title.trim();
    return _ReminderCopy(
      title: title,
      glance: glance,
      detail: detail,
      extra: detail == glance ? null : detail,
    );
  }

  NotificationDetails _details(
    StoredTask task,
    _ReminderCopy copy, {
    required bool audible,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Напоминания',
        channelDescription: 'Когда подходит время задачи',
        icon: 'ic_stat_track',
        largeIcon: const DrawableResourceAndroidBitmap('ic_track_logo'),
        importance: Importance.max,
        priority: Priority.max,
        onlyAlertOnce: true,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        playSound: audible,
        silent: !audible,
        sound: const RawResourceAndroidNotificationSound('badumtss'),
        enableVibration: audible,
        vibrationPattern: audible ? _beat : null,
        audioAttributesUsage: AudioAttributesUsage.notification,
        color: const Color(0xFFE5E1E4),
        styleInformation: BigTextStyleInformation(
          copy.detail,
          contentTitle: copy.title,
        ),
        ticker: copy.title,
        actions: [
          AndroidNotificationAction(
            'dismiss',
            'Понятно',
            cancelNotification: true,
            showsUserInterface: true,
            semanticAction: SemanticAction.markAsRead,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: audible,
        interruptionLevel: audible
            ? InterruptionLevel.timeSensitive
            : InterruptionLevel.active,
        subtitle: copy.extra,
        categoryIdentifier: 'track_reminder',
        threadIdentifier: 'track_reminders',
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: audible,
        subtitle: copy.extra,
        categoryIdentifier: 'track_reminder',
        threadIdentifier: 'track_reminders',
      ),
      windows: WindowsNotificationDetails(
        header: const WindowsHeader(
          id: 'track',
          title: 'Track',
          arguments: 'reminder',
        ),
        subtitle: copy.extra,
        duration: WindowsNotificationDuration.long,
        audio: audible
            ? WindowsNotificationAudio.asset(
                'assets/notification/badumtss.mp3',
                fallback: WindowsNotificationSound.reminder,
              )
            : WindowsNotificationAudio.silent(),
        actions: [
          WindowsAction(content: 'Понятно', arguments: 'dismiss:${task.id}'),
        ],
        images: [
          WindowsImage(
            WindowsImage.getAssetUri('assets/images/track_logo.png'),
            altText: 'Track',
            placement: WindowsImagePlacement.appLogoOverride,
            crop: WindowsImageCrop.circle,
          ),
        ],
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

class _ReminderCopy {
  const _ReminderCopy({
    required this.title,
    required this.glance,
    required this.detail,
    required this.extra,
  });

  final String title;
  final String glance;
  final String detail;
  final String? extra;
}
