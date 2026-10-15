import '../models/chat_item.dart';

abstract final class TaskCalendar {
  static const weekdayShort = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  static const weekdayFull = [
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
    'Воскресенье',
  ];
  static const _monthGenitive = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];
  static const monthNominative = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  static DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

  static DateTime mondayOf(DateTime value) {
    final day = dateOnly(value);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  static List<DateTime> weekOf(DateTime value) {
    final start = mondayOf(value);
    return [for (var i = 0; i < 7; i++) start.add(Duration(days: i))];
  }

  static List<DateTime> monthGrid(DateTime month) {
    final first = DateTime(month.year, month.month);
    var cursor = mondayOf(first);
    return [for (var i = 0; i < 42; i++) cursor.add(Duration(days: i))];
  }

  static DateTime initialDay(List<TaskDraft> tasks, DateTime now) {
    final today = dateOnly(now);
    final days = {
      for (final task in tasks)
        if (task.dueOn != null) dateOnly(task.dueOn!),
    };
    if (days.isEmpty || days.contains(today)) return today;
    final future = days.where((day) => !day.isBefore(today)).toList()..sort();
    if (future.isNotEmpty) return future.first;
    final past = days.toList()..sort();
    return past.last;
  }

  static String dayTitle(DateTime day) => '${day.day} ${_monthGenitive[day.month - 1]}';

  static String monthTitle(DateTime month) =>
      '${monthNominative[month.month - 1]} ${month.year}';

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String? clock(DateTime? value) {
    if (value == null) return null;
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
