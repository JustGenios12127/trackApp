import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../auth/data/account_tasks.dart';
import 'data/task_calendar.dart';
import 'models/chat_item.dart';
import 'widgets/chat_widgets.dart';
import 'widgets/tab_header.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    this.tasks,
    this.visible = true,
    DateTime? now,
  }) : _now = now;

  final AccountTasks? tasks;
  final bool visible;
  final DateTime? _now;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final AccountTasks _tasks = widget.tasks ?? const SupabaseAccountTasks();
  late final DateTime _today = TaskCalendar.dateOnly(
    widget._now ?? DateTime.now(),
  );
  late DateTime _month = DateTime(_today.year, _today.month);
  late DateTime _selected = _today;
  List<TaskDraft> _items = const [];
  var _loading = true;
  var _failed = false;
  var _anchored = false;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    if (widget.visible) {
      _load(silent: true);
    } else {
      _loading = false;
    }
  }

  @override
  void didUpdateWidget(CalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _load(silent: _items.isNotEmpty);
    }
  }

  Future<void> _load({bool silent = false}) async {
    final generation = ++_generation;
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }
    try {
      final rows = await _tasks.openList();
      if (!mounted || generation != _generation) return;
      final drafts = [for (final task in rows) _draft(task)];
      setState(() {
        _items = drafts;
        _loading = false;
        _failed = false;
        if (!_anchored) {
          _selected = TaskCalendar.initialDay(drafts, _today);
          _month = DateTime(_selected.year, _selected.month);
          _anchored = true;
        }
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _failed = _items.isEmpty;
      });
    }
  }

  TaskDraft _draft(AccountTask task) {
    return TaskDraft(
      title: task.title,
      subtitle: TaskCalendar.whenLabel(task.dueOn, task.remindAt, _today),
      icon: task.remindAt != null
          ? Icons.notifications_active_outlined
          : Icons.task_alt,
      dueOn: task.dueOn,
      remindAt: task.remindAt,
    );
  }

  void _shift(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  void _pick(DateTime day) {
    final date = TaskCalendar.dateOnly(day);
    setState(() {
      _selected = date;
      _month = DateTime(date.year, date.month);
      _anchored = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final days = TaskCalendar.monthGrid(_month);
    final byDay = TaskCalendar.groupByDay(_items);
    final selectedTasks =
        byDay[TaskCalendar.dateOnly(_selected)] ?? const <TaskDraft>[];
    final undated = TaskCalendar.undated(_items);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          const ChatBackdrop(),
          Column(
            children: [
              const TabHeader(title: 'Календарь'),
              Expanded(
                child: RefreshIndicator(
                  color: Colors.white,
                  backgroundColor: AppColors.surfaceContainer,
                  onRefresh: () => _load(silent: true),
                  child: ListView(
                    primary: false,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    children: [
                      ChatGlass(
                        radius: 24,
                        color: AppColors.surfaceContainer.withValues(
                          alpha: 0.82,
                        ),
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
                                    style: AppText.bodyMd(
                                      Colors.white,
                                      weight: FontWeight.w600,
                                    ),
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
                                        selected: TaskCalendar.sameDay(
                                          days[row * 7 + column],
                                          _selected,
                                        ),
                                        count:
                                            byDay[TaskCalendar.dateOnly(
                                                  days[row * 7 + column],
                                                )]
                                                ?.length ??
                                            0,
                                        muted:
                                            days[row * 7 + column].month !=
                                            _month.month,
                                        onTap: () =>
                                            _pick(days[row * 7 + column]),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
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
                      if (_loading && _items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      else if (_failed)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _load,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(48, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Не удалось загрузить задачи. Повторить',
                              style: AppText.bodyMd(Colors.white),
                            ),
                          ),
                        )
                      else ...[
                        if (selectedTasks.isEmpty)
                          _EmptyDay(
                            message: _items.isEmpty
                                ? 'Пока задач нет'
                                : 'В этот день свободно',
                          )
                        else
                          for (var i = 0; i < selectedTasks.length; i++) ...[
                            if (i > 0) const SizedBox(height: 8),
                            _TaskRow(task: selectedTasks[i]),
                          ],
                        if (undated.isNotEmpty) ...[
                          const SizedBox(height: 22),
                          Text(
                            'Без даты',
                            style: AppText.labelSm(AppColors.outline),
                          ),
                          const SizedBox(height: 10),
                          for (var i = 0; i < undated.length; i++) ...[
                            if (i > 0) const SizedBox(height: 8),
                            _TaskRow(task: undated[i], showSubtitle: true),
                          ],
                        ],
                      ],
                    ],
                  ),
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
    required this.count,
    required this.muted,
    required this.onTap,
  });

  final DateTime day;
  final DateTime today;
  final bool selected;
  final int count;
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
    final label = count > 0
        ? '${TaskCalendar.weekdayFull[day.weekday - 1]}, ${TaskCalendar.dayTitle(day)}, задач: $count'
        : '${TaskCalendar.weekdayFull[day.weekday - 1]}, ${TaskCalendar.dayTitle(day)}';

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          key: ValueKey('day-${day.year}-${day.month}-${day.day}'),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
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
  const _EmptyDay({required this.message});

  final String message;

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
          const Icon(
            Icons.event_available_outlined,
            color: AppColors.outline,
            size: 22,
          ),
          const SizedBox(height: 8),
          Text(message, style: AppText.bodyMd(AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
