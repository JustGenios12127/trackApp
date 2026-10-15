import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_gateway.dart';
import 'reminder_planner.dart';

class ReminderController extends ChangeNotifier {
  ReminderController({
    DateTime Function()? clock,
    this.onDue,
  }) : _clock = clock ?? DateTime.now;

  static const _prefsKey = 'dismissed_reminder_ids';

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
    _dismissed.add(id);
    await _persist();
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
