import 'chat_gateway.dart';

abstract final class ReminderPlanner {
  static const lookback = Duration(hours: 12);

  static List<StoredTask> due(
    List<StoredTask> tasks,
    DateTime now,
    Set<String> dismissed,
  ) {
    final moment = now.toUtc();
    final items = [
      for (final task in tasks)
        if (_isDue(task, moment, dismissed)) task,
    ]..sort((a, b) => a.remindAt!.compareTo(b.remindAt!));
    return items;
  }

  static StoredTask? current(
    List<StoredTask> tasks,
    DateTime now,
    Set<String> dismissed,
  ) {
    final items = due(tasks, now, dismissed);
    if (items.isEmpty) return null;
    return items.last;
  }

  static Duration? untilNext(
    List<StoredTask> tasks,
    DateTime now,
    Set<String> dismissed,
  ) {
    final moment = now.toUtc();
    DateTime? next;
    for (final task in tasks) {
      final at = task.remindAt?.toUtc();
      if (at == null || dismissed.contains(task.id) || !at.isAfter(moment)) {
        continue;
      }
      if (next == null || at.isBefore(next)) next = at;
    }
    if (next == null) return null;
    final wait = next.difference(moment);
    if (wait < const Duration(seconds: 1)) return const Duration(seconds: 1);
    if (wait > const Duration(hours: 1)) return const Duration(hours: 1);
    return wait;
  }

  static bool _isDue(StoredTask task, DateTime moment, Set<String> dismissed) {
    final at = task.remindAt?.toUtc();
    if (at == null || dismissed.contains(task.id)) return false;
    final delta = moment.difference(at);
    return !delta.isNegative && delta <= lookback;
  }
}
