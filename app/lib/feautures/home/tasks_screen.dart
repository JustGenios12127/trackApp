import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../auth/data/account_tasks.dart';
import 'data/task_calendar.dart';
import 'widgets/chat_widgets.dart';
import 'widgets/tab_header.dart';
import 'widgets/task_actions.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({
    super.key,
    this.tasks,
    this.onOpenChat,
    this.visible = true,
    DateTime? now,
  }) : _now = now;

  final AccountTasks? tasks;
  final VoidCallback? onOpenChat;
  final bool visible;
  final DateTime? _now;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  late final AccountTasks _tasks = widget.tasks ?? const SupabaseAccountTasks();
  late final DateTime _today = TaskCalendar.dateOnly(widget._now ?? DateTime.now());
  List<AccountTask> _items = const [];
  var _counting = true;
  var _countFailed = false;
  String? _removing;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    if (widget.visible) {
      _load(silent: true);
    } else {
      _counting = false;
    }
  }

  @override
  void didUpdateWidget(TasksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _load(silent: _items.isNotEmpty);
    }
  }

  Future<void> _load({bool silent = false}) async {
    final generation = ++_generation;
    if (!silent) {
      setState(() {
        _counting = true;
        _countFailed = false;
      });
    }
    try {
      final rows = await _tasks.openList();
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = rows;
        _counting = false;
        _countFailed = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _counting = false;
        _countFailed = _items.isEmpty;
      });
    }
  }

  Future<void> _delete(AccountTask task) async {
    if (_removing != null) return;
    final ok = await confirmDeleteTask(context, task.title);
    if (!ok || !mounted) return;
    setState(() => _removing = task.id);
    try {
      await _tasks.remove(task.id);
      await forgetReminder(task.id);
      if (!mounted) return;
      setState(() {
        _items = [for (final item in _items) if (item.id != task.id) item];
        _removing = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _removing = null);
      showDeleteError(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          const ChatBackdrop(),
          Column(
            children: [
              const TabHeader(title: 'Задачи'),
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
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    children: [
                      ChatGlass(
                        radius: 24,
                        color: AppColors.surfaceContainer.withValues(alpha: 0.82),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ОТКРЫТО',
                              style: AppText.labelSm(
                                AppColors.onSurfaceVariant,
                                weight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_counting && _items.isEmpty)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            else if (_countFailed)
                              TextButton(
                                onPressed: _load,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(48, 36),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Не удалось посчитать. Повторить',
                                  style: AppText.bodyMd(Colors.white),
                                ),
                              )
                            else
                              Text(
                                '${_items.length}',
                                style: const TextStyle(
                                  fontFamily: AppText.family,
                                  fontSize: 40,
                                  height: 1.1,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.8,
                                  color: Colors.white,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              'Удалить можно кнопкой справа или фразой в чате: «удали задачи 15, 16 и 17 октября».',
                              style: AppText.bodyMd(AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!_counting && !_countFailed && _items.isEmpty)
                        const _EmptyTasks()
                      else
                        for (var i = 0; i < _items.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          _OpenTask(
                            task: _items[i],
                            today: _today,
                            onDelete: _delete,
                          ),
                        ],
                      if (widget.onOpenChat != null) ...[
                        const SizedBox(height: 16),
                        _ChatLink(onTap: widget.onOpenChat!),
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

class _OpenTask extends StatelessWidget {
  const _OpenTask({
    required this.task,
    required this.today,
    required this.onDelete,
  });

  final AccountTask task;
  final DateTime today;
  final Future<void> Function(AccountTask task) onDelete;

  @override
  Widget build(BuildContext context) {
    final subtitle = TaskCalendar.whenLabel(task.dueOn, task.remindAt, today);
    return Container(
      padding: const EdgeInsets.only(left: 14),
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
            child: Icon(
              task.remindAt != null
                  ? Icons.notifications_active_outlined
                  : Icons.task_alt,
              size: 16,
              color: AppColors.onPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyMd(Colors.white, weight: FontWeight.w500),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodySm(AppColors.outline),
                    ),
                  ],
                ],
              ),
            ),
          ),
          TaskDeleteButton(title: task.title, onPressed: () => onDelete(task)),
        ],
      ),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

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
          const Icon(Icons.task_alt, color: AppColors.outline, size: 22),
          const SizedBox(height: 8),
          Text('Пока задач нет', style: AppText.bodyMd(AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ChatLink extends StatelessWidget {
  const _ChatLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Открыть чат',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: SizedBox(
            height: 52,
            child: Center(
              child: Text(
                'Открыть чат',
                style: AppText.bodyMd(AppColors.onPrimary, weight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
