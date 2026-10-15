import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import 'data/task_calendar.dart';
import 'widgets/chat_widgets.dart';
import 'widgets/tab_header.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, DateTime? now}) : _now = now;

  final DateTime? _now;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final DateTime _today = TaskCalendar.dateOnly(widget._now ?? DateTime.now());
  late DateTime _month = DateTime(_today.year, _today.month);
  late DateTime _selected = _today;

  void _shift(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  void _pick(DateTime day) {
    final date = TaskCalendar.dateOnly(day);
    setState(() {
      _selected = date;
      _month = DateTime(date.year, date.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final days = TaskCalendar.monthGrid(_month);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          const ChatBackdrop(),
          Column(
            children: [
              const TabHeader(title: 'Календарь'),
              Expanded(
                child: ListView(
                  primary: false,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  children: [
                    ChatGlass(
                      radius: 24,
                      color: AppColors.surfaceContainer.withValues(alpha: 0.82),
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _MonthButton(
                                icon: Icons.chevron_left,
                                label: 'Предыдущий месяц',
                                onTap: () => _shift(-1),
                              ),
                              Expanded(
                                child: Text(
                                  TaskCalendar.monthTitle(_month),
                                  textAlign: TextAlign.center,
                                  style: AppText.bodyMd(Colors.white, weight: FontWeight.w600),
                                ),
                              ),
                              _MonthButton(
                                icon: Icons.chevron_right,
                                label: 'Следующий месяц',
                                onTap: () => _shift(1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              for (final label in TaskCalendar.weekdayShort)
                                Expanded(
                                  child: Text(
                                    label,
                                    textAlign: TextAlign.center,
                                    style: AppText.labelSm(
                                      AppColors.outline,
                                      weight: FontWeight.w500,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          for (var row = 0; row < 6; row++)
                            Row(
                              children: [
                                for (var column = 0; column < 7; column++)
                                  Expanded(
                                    child: _DayCell(
                                      day: days[row * 7 + column],
                                      today: _today,
                                      selected: TaskCalendar.sameDay(days[row * 7 + column], _selected),
                                      muted: days[row * 7 + column].month != _month.month,
                                      onTap: () => _pick(days[row * 7 + column]),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      TaskCalendar.dayTitle(_selected),
                      style: AppText.headlineSm(Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Дни с задачами смотри в чате: напиши /task, и откроется доска по датам.',
                      style: AppText.bodyMd(AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: AppColors.onSurface),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.today,
    required this.selected,
    required this.muted,
    required this.onTap,
  });

  final DateTime day;
  final DateTime today;
  final bool selected;
  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = TaskCalendar.sameDay(day, today);
    final weekend = day.weekday >= 6;
    final numberColor = selected
        ? AppColors.onPrimary
        : muted
        ? AppColors.outline.withValues(alpha: 0.45)
        : weekend
        ? AppColors.outline
        : AppColors.onSurface;

    return Semantics(
      button: true,
      selected: selected,
      label: '${TaskCalendar.weekdayFull[day.weekday - 1]}, ${TaskCalendar.dayTitle(day)}',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                shape: BoxShape.circle,
                border: isToday && !selected
                    ? Border.all(color: Colors.white.withValues(alpha: 0.85))
                    : null,
              ),
              child: Text(
                '${day.day}',
                style: AppText.bodyMd(numberColor, weight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
