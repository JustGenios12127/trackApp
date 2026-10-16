import 'package:supabase_flutter/supabase_flutter.dart';

class AccountTask {
  const AccountTask({
    required this.id,
    required this.title,
    this.dueOn,
    this.remindAt,
  });

  final String id;
  final String title;
  final DateTime? dueOn;
  final DateTime? remindAt;
}

abstract interface class AccountTasks {
  Future<int> openCount();

  Future<List<AccountTask>> openList();
}

class SupabaseAccountTasks implements AccountTasks {
  const SupabaseAccountTasks();

  @override
  Future<int> openCount() async {
    final rows = await Supabase.instance.client
        .from('tasks')
        .select('id')
        .eq('status', 'open');
    return rows.length;
  }

  @override
  Future<List<AccountTask>> openList() async {
    final rows = await Supabase.instance.client
        .from('tasks')
        .select('id, title, due_on, remind_at')
        .eq('status', 'open')
        .order('due_on', ascending: true)
        .order('created_at', ascending: true);
    final tasks = <AccountTask>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final id = row['id'];
      final title = row['title'];
      if (id is! String || title is! String || title.trim().isEmpty) continue;
      tasks.add(
        AccountTask(
          id: id,
          title: title.trim(),
          dueOn: _calendarDate(row['due_on']),
          remindAt: _instant(row['remind_at']),
        ),
      );
    }
    return tasks;
  }
}

DateTime? _calendarDate(Object? value) {
  if (value is DateTime) return DateTime(value.year, value.month, value.day);
  if (value is! String) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
  if (match == null) return null;
  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final day = int.tryParse(match.group(3)!);
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(year, month, day);
}

DateTime? _instant(Object? value) {
  if (value is DateTime) return value;
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
