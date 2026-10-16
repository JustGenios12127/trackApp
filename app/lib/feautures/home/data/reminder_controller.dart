import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_gateway.dart';
import 'reminder_planner.dart';

class ReminderController extends ChangeNotifier {
  ReminderController({DateTime Function()? clock, this.onDue})
    : _clock = clock ?? DateTime.now;

  static const _prefsKey = 'dismissed_reminder_ids';
  static final List<void Function(String id)> _listeners = [];

  static void listen(void Function(String id) onDismiss) {
    if (_listeners.contains(onDismiss)) return;
    _listeners.add(onDismiss);
  }

  static void unlisten(void Function(String id) onDismiss) {
    _listeners.remove(onDismiss);
  }

  static Future<void> noteDismissed(String id) async {
    if (id.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = List<String>.from(prefs.getStringList(_prefsKey) ?? const []);
      if (!ids.contains(id)) {
        ids.add(id);
        await prefs.setStringList(_prefsKey, ids);
      }
    } catch (_) {}
    for (final listener in List<void Function(String id)>.of(_listeners)) {
      listener(id);
    }
  }

  final DateTime Function() _clock;
  final void Function(StoredTask task)? onDue;
  final List<StoredTask> _tasks = [];
  final Set<String> _dismissed = {};

  StoredTask? current;
  Timer? _timer;
  Future<void>? _prefs;
  var _disposed = false;

  List<StoredTask> get tasks => List.unmodifiable(_tasks);

  Future<void> replace(List<StoredTask> tasks) async {
    await _ensurePrefs();
    _tasks
      ..clear()
      ..addAll(tasks);
    _publish();
  }

  Future<void> drop(Iterable<String> ids) async {
    await _ensurePrefs();
    final remove = ids.where((id) => id.isNotEmpty).toSet();
    if (remove.isEmpty) return;
    _tasks.removeWhere((task) => remove.contains(task.id));
    _publish();
  }

  Future<void> sync(List<StoredTask> tasks) async {
    await _ensurePrefs();
    final byId = {for (final task in _tasks) task.id: task};
    for (final task in tasks) {
      byId[task.id] = task;
    }
    _tasks
      ..clear()
      ..addAll(byId.values);
    _publish();
  }

  Future<void> dismiss(String id) async {
    if (_disposed || id.isEmpty) return;
    _dismissed.add(id);
    await _persist();
    _publish();
  }

  Future<void> reloadDismissed() async {
    await _ensurePrefs();
    if (_disposed) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _dismissed.addAll(prefs.getStringList(_prefsKey) ?? const []);
    } catch (_) {}
    _publish();
  }

  void tick() => _publish();

  Future<void> _ensurePrefs() {
    return _prefs ??= _readPrefs();
  }

  Future<void> _readPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dismissed.addAll(prefs.getStringList(_prefsKey) ?? const []);
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _dismissed.toList());
    } catch (_) {}
  }

  void _publish() {
    if (_disposed) return;
    final now = _clock();
    final next = ReminderPlanner.current(_tasks, now, _dismissed);
    final changed = next?.id != current?.id;
    current = next;
    _arm(now);
    if (!changed) return;
    if (next != null) onDue?.call(next);
    notifyListeners();
  }

  void _arm(DateTime now) {
    _timer?.cancel();
    final wait = ReminderPlanner.untilNext(_tasks, now, _dismissed);
    if (wait == null) return;
    _timer = Timer(wait, _publish);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
