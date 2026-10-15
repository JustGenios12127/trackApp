import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../auth/data/account_tasks.dart';
import 'widgets/chat_widgets.dart';
import 'widgets/tab_header.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, this.tasks, this.onOpenChat, this.visible = true});

  final AccountTasks? tasks;
  final VoidCallback? onOpenChat;
  final bool visible;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  late final AccountTasks _tasks = widget.tasks ?? const SupabaseAccountTasks();
  int? _openCount;
  var _counting = true;
  var _countFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.visible) {
      _loadCount(silent: true);
    } else {
      _counting = false;
    }
  }

  @override
  void didUpdateWidget(TasksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _loadCount(silent: _openCount != null);
    }
  }

  Future<void> _loadCount({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _counting = true;
        _countFailed = false;
      });
    }
    try {
      final count = await _tasks.openCount();
      if (!mounted) return;
      setState(() {
        _openCount = count;
        _counting = false;
        _countFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _counting = false;
        _countFailed = _openCount == null;
      });
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
                child: ListView(
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
                          if (_counting)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          else if (_countFailed)
                            TextButton(
                              onPressed: _loadCount,
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
                              '${_openCount ?? 0}',
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
                            'Задачи этой почты лежат на сервере. Полный список — команда /task в чате.',
                            style: AppText.bodyMd(AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    if (widget.onOpenChat != null) ...[
                      const SizedBox(height: 16),
                      _ChatLink(onTap: widget.onOpenChat!),
                    ],
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
