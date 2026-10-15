import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import 'data/chat_gateway.dart';
import 'data/reminder_controller.dart';
import 'data/system_reminder.dart';
import 'models/chat_item.dart';
import 'widgets/chat_widgets.dart';
import 'widgets/reminder_banner.dart';
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
  late final ChatGateway _gateway = widget.gateway ?? const SupabaseChatGateway();
  late final ReminderController _reminders = ReminderController(onDue: _announce);
  var _sending = false;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadReminders();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reminders.dispose();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reminders.tick();
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final now = DateTime.now();
    final generation = _generation;
    setState(() {
      _sending = true;
      _items.add(
        UserMessage(
          text: text,
          meta: '${_clock(now)} • Отправлено',
        ),
      );
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
          await showTaskBoard(context, tasks: item.tasks);
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
            text: 'Не получилось получить ответ. Проверь интернет и попробуй ещё раз.',
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
      final tasks = await _gateway.reminders(now: DateTime.now());
      if (!mounted) return;
      await _reminders.replace(tasks);
      await SystemReminder.instance.schedule(_reminders.tasks);
    } catch (_) {}
  }

  Future<void> _keepReminders(ChatResult result) async {
    try {
      if (result.kind == ChatKind.listed) {
        await _reminders.replace(result.tasks);
      } else if (result.tasks.isNotEmpty) {
        await _reminders.sync(result.tasks);
      }
      await SystemReminder.instance.schedule(_reminders.tasks);
    } catch (_) {}
  }

  void _announce(StoredTask task) {
    final at = task.remindAt;
    final late = at != null &&
        DateTime.now().toUtc().difference(at.toUtc()) > const Duration(seconds: 2);
    if (!SystemReminder.instance.isReady) {
      _chime();
      return;
    }
    if (late) {
      SystemReminder.instance.showNow(task);
    }
  }

  void _chime() {
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
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

  TaskDraft _draft(StoredTask task) {
    return TaskDraft(
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
                      ? const SizedBox(key: ValueKey('none'), width: double.infinity)
                      : Padding(
                          key: ValueKey(task.id),
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          child: ReminderBanner(
                            task: task,
                            onDismiss: () => _reminders.dismiss(task.id),
                          ),
                        ),
                );
              },
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                physics: const BouncingScrollPhysics(),
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
                      child: Text(
                        'Напиши, например: «запиши задачу сделать уборку». Команда /task покажет все задачи из базы.',
                        style: AppText.bodyMd(AppColors.outline),
                      ),
                    ),
                  for (final item in _items) ...[
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ChatItemView(item: item),
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
            if (!widget.embedded) ChatBottomNav(onProfile: widget.onOpenProfile),
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
