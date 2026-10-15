import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../data/task_calendar.dart';
import '../models/chat_item.dart';

Future<void> showTaskBoard(
  BuildContext context, {
  required List<TaskDraft> tasks,
  DateTime? now,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xC0000000),
    builder: (context) {
      final height = MediaQuery.sizeOf(context).height;
      return Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 480, maxHeight: height * 0.92),
          child: TaskBoardSheet(tasks: tasks, now: now),
        ),
      );
    },
  );
}

class TaskBoardSheet extends StatefulWidget {
  const TaskBoardSheet({super.key, required this.tasks, this.now});

  final List<TaskDraft> tasks;
  final DateTime? now;

  @override
  State<TaskBoardSheet> createState() => _TaskBoardSheetState();
}

class _TaskBoardSheetState extends State<TaskBoardSheet> {
  late DateTime _selected;
  late DateTime _visibleMonth;
  late final DateTime _today;

  @override
  void initState() {
    super.initState();
    final now = widget.now ?? DateTime.now();
    _today = TaskCalendar.dateOnly(now);
    _selected = TaskCalendar.initialDay(widget.tasks, now);
    _visibleMonth = DateTime(_selected.year, _selected.month);
  }

  Map<DateTime, List<TaskDraft>> get _byDay {
    final grouped = <DateTime, List<TaskDraft>>{};
    for (final task in widget.tasks) {
      final due = task.dueOn;
      if (due == null) continue;
      final key = TaskCalendar.dateOnly(due);
      grouped.putIfAbsent(key, () => []).add(task);
    }
    for (final tasks in grouped.values) {
      tasks.sort((a, b) {
        final aTime = a.remindAt;
        final bTime = b.remindAt;
        if (aTime == null && bTime == null) return a.title.compareTo(b.title);
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return aTime.compareTo(bTime);
      });
    }
    return grouped;
  }

  List<TaskDraft> get _undated => [
    for (final task in widget.tasks)
      if (task.dueOn == null) task,
  ];

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  void _select(DateTime day) {
    setState(() {
      _selected = TaskCalendar.dateOnly(day);
      _visibleMonth = DateTime(_selected.year, _selected.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedTasks = _byDay[TaskCalendar.dateOnly(_selected)] ?? const <TaskDraft>[];
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.surfaceHighest,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              children: [
                Text('ЗАДАЧИ', style: AppText.labelSm(AppColors.outline)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHighest,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${widget.tasks.length}',
                    style: AppText.labelSm(AppColors.onSurface, weight: FontWeight.w500, letterSpacing: 0),
                  ),
                ),
                const Spacer(),
                _RoundButton(
                  icon: Icons.close,
                  label: 'Закрыть',
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          _MonthGrid(
            month: _visibleMonth,
            today: _today,
            selected: _selected,
            counts: _byDay,
            onSelect: _select,
            onPrevious: () => _shiftMonth(-1),
            onNext: () => _shiftMonth(1),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.hairline),
          Expanded(
            child: ListView(
              primary: false,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
              children: [
                Text(
                  TaskCalendar.weekdayFull[_selected.weekday - 1],
                  style: AppText.headlineSm(Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  TaskCalendar.dayTitle(_selected),
                  style: AppText.bodySm(AppColors.outline),
                ),
                const SizedBox(height: 14),
                if (selectedTasks.isEmpty)
                  const _EmptyDay()
                else
                  for (var i = 0; i < selectedTasks.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _TaskRow(task: selectedTasks[i]),
                  ],
                if (_undated.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text('Без даты', style: AppText.labelSm(AppColors.outline)),
                  const SizedBox(height: 10),
                  for (var i = 0; i < _undated.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _TaskRow(task: _undated[i], showSubtitle: true),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.selected,
    required this.counts,
    required this.onSelect,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final DateTime today;
  final DateTime selected;
  final Map<DateTime, List<TaskDraft>> counts;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final days = TaskCalendar.monthGrid(month);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Column(
        children: [
          Row(
            children: [
              _RoundButton(
                icon: Icons.chevron_left,
                label: 'Предыдущий месяц',
                onTap: onPrevious,
              ),
              Expanded(
                child: Text(
                  TaskCalendar.monthTitle(month),
                  textAlign: TextAlign.center,
                  style: AppText.bodyMd(Colors.white, weight: FontWeight.w500),
                ),
              ),
              _RoundButton(
                icon: Icons.chevron_right,
                label: 'Следующий месяц',
                onTap: onNext,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final label in TaskCalendar.weekdayShort)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppText.labelSm(AppColors.outline, weight: FontWeight.w500),
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
                      today: today,
                      selected: TaskCalendar.sameDay(days[row * 7 + column], selected),
                      count: counts[days[row * 7 + column]]?.length ?? 0,
                      muted: days[row * 7 + column].month != month.month,
                      compact: true,
                      onTap: () => onSelect(days[row * 7 + column]),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.today,
    required this.selected,
    required this.count,
    required this.onTap,
    this.muted = false,
    this.compact = false,
  });

  final DateTime day;
  final DateTime today;
  final bool selected;
  final int count;
  final VoidCallback onTap;
  final bool muted;
  final bool compact;

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
          key: ValueKey('${compact ? 'month' : 'week'}-${day.year}-${day.month}-${day.day}'),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              if (!compact) ...[
                Text(
                  TaskCalendar.weekdayShort[day.weekday - 1],
                  style: AppText.labelSm(
                    AppColors.outline,
                    weight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Container(
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
              const SizedBox(height: 4),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: count > 0
                      ? (muted ? AppColors.outline : Colors.white)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, this.showSubtitle = false});

  final TaskDraft task;
  final bool showSubtitle;

  @override
  Widget build(BuildContext context) {
    final time = TaskCalendar.clock(task.remindAt);
    final detail = showSubtitle ? task.subtitle : (time ?? task.subtitle);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(task.icon, size: 16, color: AppColors.onPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyMd(Colors.white, weight: FontWeight.w500),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodySm(AppColors.outline),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          const Icon(Icons.event_available_outlined, color: AppColors.outline, size: 22),
          const SizedBox(height: 8),
          Text('В этот день свободно', style: AppText.bodyMd(AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
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
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.surfaceHigh,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: AppColors.onSurface),
        ),
      ),
    );
  }
}
