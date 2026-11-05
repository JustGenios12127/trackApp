import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import '../auth/data/account_tasks.dart';
import 'data/chat_gateway.dart';
import 'data/reminder_chime.dart';
import 'data/reminder_controller.dart';
import 'data/system_reminder.dart';
import 'models/chat_item.dart';
import 'widgets/chat_widgets.dart';
import 'widgets/reminder_banner.dart';
import 'widgets/task_actions.dart';
import 'widgets/task_board_sheet.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    this.overview,
    this.accuracyLabel,
    this.items = const [],
    this.suggestions = const [],
    this.gateway,
    this.onOpenProfile,
    this.embedded = false,
  });

  final DailyOverview? overview;
  final String? accuracyLabel;
  final List<ChatItem> items;
  final List<SuggestionChipData> suggestions;
  final ChatGateway? gateway;
  final VoidCallback? onOpenProfile;
  final bool embedded;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  late final List<ChatItem> _items = [...widget.items];
  late final ChatGateway _gateway =
      widget.gateway ?? const SupabaseChatGateway();
  late final ReminderController _reminders = ReminderController(
    onDue: _announce,
  );
  late final void Function(String id) _externalDismiss = _reminders.dismiss;
  var _sending = false;
  var _generation = 0;
  Future<void>? _outside;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ReminderController.listen(_externalDismiss);
    _loadReminders();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ReminderController.unlisten(_externalDismiss);
    _reminders.dispose();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_reminders.reloadDismissed());
      unawaited(_armReminders());
      return;
    }
    if (state == AppLifecycleState.inactive) return;
    _outside ??= _publishOutside().whenComplete(() => _outside = null);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final now = DateTime.now();
    final generation = _generation;
    setState(() {
      _sending = true;
      _items.add(UserMessage(text: text, meta: '${_clock(now)} • Отправлено'));
      _controller.clear();
    });
    _scrollToEnd();

    try {
      final result = await _gateway.reply(messages: _history(), now: now);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.add(_resultItem(result));
        _sending = false;
      });
      await _keepReminders(result);
      if (mounted && result.kind == ChatKind.listed) {
        final item = _items.last;
        if (item is AiTaskListMessage) {
          await showTaskBoard(
            context,
            tasks: item.tasks,
            onDelete: _deleteTask,
          );
        }
      }
    } on ChatException catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.add(AiReplyMessage(text: error.message, status: '• Ошибка'));
        _sending = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.add(
          const AiReplyMessage(
            text:
                'Не получилось получить ответ. Проверь интернет и попробуй ещё раз.',
            status: '• Ошибка',
          ),
        );
        _sending = false;
      });
    }
    _scrollToEnd();
  }

  Future<void> _loadReminders() async {
    try {
      await SystemReminder.instance.requestPermissions();
      final tasks = await _gateway.reminders(now: DateTime.now());
      if (!mounted) return;
      await _reminders.replace(tasks);
      await SystemReminder.instance.schedule(_reminders.tasks);
    } catch (_) {}
  }

  Future<void> _armReminders() async {
    await SystemReminder.instance.requestPermissions();
    await SystemReminder.instance.schedule(_reminders.tasks);
  }

  Future<void> _publishOutside() async {
    final current = _reminders.current;
    if (current != null &&
        SystemReminder.instance.shouldPostOutside(current.id)) {
      await SystemReminder.instance.showNow(current);
    }
    await SystemReminder.instance.schedule(_reminders.tasks);
  }

  Future<void> _keepReminders(ChatResult result) async {
    try {
      if (result.kind == ChatKind.listed) {
        await _reminders.replace(result.tasks);
      } else if (result.kind == ChatKind.deleted) {
        await _reminders.drop(result.tasks.map((task) => task.id));
      } else if (result.tasks.isNotEmpty) {
        await _reminders.sync(result.tasks);
      }
      await SystemReminder.instance.schedule(_reminders.tasks);
    } catch (_) {}
  }

  void _announce(StoredTask task) {
    unawaited(_deliver(task));
  }

  Future<void> _deliver(StoredTask task) async {
    final system = SystemReminder.instance.isReady;
    final inside = reminderHandledInsideApp(
      WidgetsBinding.instance.lifecycleState,
    );
    if (!inside) {
      if (system && SystemReminder.instance.shouldPostOutside(task.id)) {
        await SystemReminder.instance.showNow(task);
      }
      return;
    }
    if (!system || SystemReminder.instance.shouldPostOutside(task.id)) {
      await ReminderChime.play();
    }
  }

  void _clear() {
    setState(() {
      _generation++;
      _sending = false;
      _items.clear();
      _controller.clear();
    });
  }

  ChatItem _resultItem(ChatResult result) {
    if (result.kind == ChatKind.deleted) {
      return AiReplyMessage(text: result.reply, status: '• Удалено');
    }
    if (result.kind == ChatKind.listed) {
      return AiTaskListMessage(
        status: '• Список',
        text: result.reply,
        badge: '${result.tasks.length}',
        saveLabel: '',
        saved: true,
        board: true,
        tasks: [for (final task in result.tasks) _draft(task)],
      );
    }
    if (result.tasks.isEmpty) {
      return AiReplyMessage(text: result.reply);
    }
    return AiTaskListMessage(
      status: '• Сохранено',
      text: result.reply,
      saveLabel: '',
      saved: true,
      tasks: [for (final task in result.tasks) _draft(task)],
    );
  }

  Future<void> _deleteTask(TaskDraft task) async {
    if (task.id.isEmpty) return;
    await const SupabaseAccountTasks().remove(task.id);
    await forgetReminder(task.id);
    await _reminders.drop([task.id]);
    if (!mounted) return;
    setState(() {
      for (var index = 0; index < _items.length; index++) {
        final item = _items[index];
        if (item is! AiTaskListMessage) continue;
        final next = [
          for (final row in item.tasks)
            if (row.id != task.id) row,
        ];
        if (next.length == item.tasks.length) continue;
        _items[index] = AiTaskListMessage(
          status: item.status,
          text: item.text,
          badge: item.board ? '${next.length}' : item.badge,
          tasks: next,
          saveLabel: item.saveLabel,
          saved: item.saved,
          board: item.board,
        );
      }
    });
  }

  TaskDraft _draft(StoredTask task) {
    return TaskDraft(
      id: task.id,
      title: task.title,
      subtitle: task.subtitle,
      icon: task.remind ? Icons.notifications_active_outlined : Icons.task_alt,
      dueOn: task.dueOn,
      remindAt: task.remindAt,
    );
  }

  List<ChatTurn> _history() {
    return [
      for (final item in _items)
        if (item is UserMessage)
          ChatTurn(role: 'user', content: item.text)
        else if (item is AiReplyMessage && item.status != '• Ошибка')
          ChatTurn(role: 'assistant', content: item.text)
        else if (item is AiTaskListMessage)
          ChatTurn(role: 'assistant', content: item.text),
    ];
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _clock(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final overview = widget.overview;
    final content = Stack(
      children: [
        const ChatBackdrop(),
        Column(
          children: [
            ChatHeader(onClear: _clear),
            ListenableBuilder(
              listenable: _reminders,
              builder: (context, _) {
                final task = _reminders.current;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: task == null
                      ? const SizedBox(
                          key: ValueKey('none'),
                          width: double.infinity,
                        )
                      : Padding(
                          key: ValueKey(task.id),
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          child: ReminderBanner(
                            task: task,
                            onDismiss: () {
                              unawaited(
                                SystemReminder.instance.cancel(task.id),
                              );
                              unawaited(_reminders.dismiss(task.id));
                            },
                          ),
                        ),
                );
              },
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                primary: false,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ChatStatusRow(accuracyLabel: widget.accuracyLabel),
                  ),
                  if (overview != null) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: DailyOverviewCard(overview: overview),
                    ),
                  ],
                  if (_items.isEmpty && !_sending)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                    ),
                  for (final item in _items) ...[
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ChatItemView(item: item, onDeleteTask: _deleteTask),
                    ),
                  ],
                  if (_sending) ...[
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: AiMessageHeader(status: '• Печатает'),
                    ),
                  ],
                  if (widget.suggestions.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    SuggestionStrip(items: widget.suggestions),
                  ],
                ],
              ),
            ),
            ChatComposer(
              controller: _controller,
              sending: _sending,
              onSend: _send,
            ),
            if (!widget.embedded)
              ChatBottomNav(onProfile: widget.onOpenProfile),
          ],
        ),
      ],
    );

    if (widget.embedded) return content;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        resizeToAvoidBottomInset: true,
        body: content,
      ),
    );
  }
}
