import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../models/chat_item.dart';
import 'task_board_sheet.dart';

class ChatBackdrop extends StatelessWidget {
  const ChatBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        children: [
          Positioned(top: -40, left: -70, child: _Glow(size: 280)),
          Positioned(top: 360, right: -90, child: _Glow(size: 320, alpha: 0.05)),
          Positioned(bottom: 180, left: 40, child: _Glow(size: 240, alpha: 0.03)),
        ],
      ),
    );
  }
}

class ChatHeader extends StatelessWidget {
  const ChatHeader({super.key, this.onClear});

  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.7),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(top: top),
            child: SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const _Logo(),
                    const SizedBox(width: 8),
                    const Expanded(child: _HeaderTitles()),
                    _RoundIcon(
                      icon: Icons.delete_sweep_outlined,
                      label: 'Очистить чат',
                      onTap: onClear,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChatStatusRow extends StatelessWidget {
  const ChatStatusRow({super.key, this.accuracyLabel});

  final String? accuracyLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _EnginePill(),
          ),
        ),
        if (accuracyLabel != null) ...[
          const SizedBox(width: 8),
          _AccuracyPill(label: accuracyLabel!),
        ],
      ],
    );
  }
}

class DailyOverviewCard extends StatelessWidget {
  const DailyOverviewCard({super.key, required this.overview});

  final DailyOverview overview;

  @override
  Widget build(BuildContext context) {
    final subtitle = overview.subtitle;

    return ChatGlass(
      radius: 24,
      color: AppColors.surfaceContainer.withValues(alpha: 0.7),
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  overview.dateLabel.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: AppText.family,
                    fontSize: 12,
                    height: 1.33,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.8,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  overview.title,
                  style: const TextStyle(
                    fontFamily: AppText.family,
                    fontSize: 26,
                    height: 1.23,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.65,
                    color: Colors.white,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: AppText.family,
                      fontSize: 12,
                      height: 1.33,
                      color: AppColors.outline,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          _FocusMeter(progress: overview.focus),
        ],
      ),
    );
  }
}

class ChatItemView extends StatelessWidget {
  const ChatItemView({super.key, required this.item});

  final ChatItem item;

  @override
  Widget build(BuildContext context) {
    return switch (item) {
      TimeMark(:final label) => TimeChip(label: label),
      UserMessage(:final text, :final meta) => UserMessageBubble(text: text, meta: meta),
      AiReplyMessage(:final text, :final status) => AiReplyCard(text: text, status: status),
      AiEventMessage(:final status, :final text, :final event) => AiEventCard(
          status: status,
          text: text,
          event: event,
        ),
      AiTaskListMessage(
        :final status,
        :final text,
        :final badge,
        :final tasks,
        :final saveLabel,
        :final saved,
        :final board,
        ) =>
        board
            ? TaskBoardEntry(text: text, count: badge, tasks: tasks)
            : AiTaskListCard(
                status: status,
                text: text,
                badge: badge,
                tasks: tasks,
                saveLabel: saveLabel,
                saved: saved,
              ),
    };
  }
}

class TimeChip extends StatelessWidget {
  const TimeChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceLowest.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label.toUpperCase(),
          style: AppText.labelSm(
            AppColors.outline,
            weight: FontWeight.w500,
            letterSpacing: 1.4,
          ),
        ),
      ),
    );
  }
}

class UserMessageBubble extends StatelessWidget {
  const UserMessageBubble({super.key, required this.text, required this.meta});

  final String text;
  final String meta;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.85),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(4),
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Text(text, style: AppText.bodyMd(Colors.white)),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    meta,
                    style: AppText.labelSm(
                      AppColors.outline,
                      weight: FontWeight.w400,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AiEventCard extends StatelessWidget {
  const AiEventCard({
    super.key,
    required this.status,
    required this.text,
    required this.event,
  });

  final String status;
  final String text;
  final EventDraft event;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AiMessageHeader(status: status),
        const SizedBox(height: 8),
        ChatGlass(
          radius: 24,
          topLeft: 4,
          color: AppColors.surfaceLow.withValues(alpha: 0.9),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(text, style: AppText.bodyMd(Colors.white)),
              const SizedBox(height: 16),
              EventPreviewCard(event: event),
            ],
          ),
        ),
      ],
    );
  }
}

class EventPreviewCard extends StatelessWidget {
  const EventPreviewCard({super.key, required this.event});

  final EventDraft event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(top: 2),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceHighest,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title, style: AppText.headlineSm(Colors.white)),
                    const SizedBox(height: 2),
                    Text(
                      event.subtitle,
                      style: AppText.bodySm(AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(event.trailingIcon, size: 20, color: AppColors.outline),
            ],
          ),
          if (event.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in event.tags)
                  ChatTagChip(
                    label: tag.label,
                    icon: tag.icon,
                    dot: tag.dot,
                    strong: tag.strong,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ChatPillButton(
                  icon: Icons.check_circle,
                  label: event.primaryLabel,
                  filled: true,
                  flexible: true,
                ),
              ),
              const SizedBox(width: 8),
              ChatPillButton(
                icon: Icons.edit_outlined,
                label: event.secondaryLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AiTaskListCard extends StatelessWidget {
  const AiTaskListCard({
    super.key,
    required this.status,
    required this.text,
    required this.tasks,
    required this.saveLabel,
    this.badge,
    this.saved = false,
  });

  final String status;
  final String text;
  final String? badge;
  final List<TaskDraft> tasks;
  final String saveLabel;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AiMessageHeader(status: status),
        const SizedBox(height: 8),
        ChatGlass(
          radius: 24,
          topLeft: 4,
          color: AppColors.surfaceLow.withValues(alpha: 0.9),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(text, style: AppText.bodyMd(Colors.white))),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    ChatMiniChip(label: badge!),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < tasks.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                TaskPreviewRow(task: tasks[i], showAdd: !saved),
              ],
              if (!saved && saveLabel.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ChatPillButton(
                    icon: Icons.done_all,
                    label: saveLabel,
                    filled: true,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class TaskBoardEntry extends StatelessWidget {
  const TaskBoardEntry({
    super.key,
    required this.text,
    required this.tasks,
    this.count,
  });

  final String text;
  final String? count;
  final List<TaskDraft> tasks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AiMessageHeader(status: '• Список'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => showTaskBoard(context, tasks: tasks),
          child: ChatGlass(
            radius: 24,
            topLeft: 4,
            color: AppColors.surfaceLow.withValues(alpha: 0.9),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_month_outlined,
                    size: 18,
                    color: AppColors.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(text, style: AppText.bodyMd(Colors.white, weight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text('Неделя и календарь', style: AppText.bodySm(AppColors.outline)),
                    ],
                  ),
                ),
                if (count != null) ChatMiniChip(label: count!),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class TaskPreviewRow extends StatelessWidget {
  const TaskPreviewRow({super.key, required this.task, this.showAdd = true});

  final TaskDraft task;
  final bool showAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.surfaceHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(task.icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyMd(Colors.white, weight: FontWeight.w500),
                ),
                Text(
                  task.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySm(AppColors.outline),
                ),
              ],
            ),
          ),
          if (showAdd) ...[
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'Добавить задачу',
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceHighest,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_task,
                  size: 18,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SuggestionStrip extends StatelessWidget {
  const SuggestionStrip({super.key, required this.items});

  final List<SuggestionChipData> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Row(
            children: [
              Text(
                'БЫСТРЫЕ ПОДСКАЗКИ AI',
                style: AppText.labelSm(AppColors.outline, weight: FontWeight.w500),
              ),
              const Spacer(),
              const Icon(Icons.touch_app_outlined, size: 16, color: AppColors.outline),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final item = items[index];
              return SuggestionChip(icon: item.icon, label: item.label);
            },
          ),
        ),
      ],
    );
  }
}

class AiReplyCard extends StatelessWidget {
  const AiReplyCard({
    super.key,
    required this.text,
    required this.status,
  });

  final String text;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AiMessageHeader(status: status),
        const SizedBox(height: 8),
        ChatGlass(
          radius: 24,
          topLeft: 4,
          color: AppColors.surfaceLow.withValues(alpha: 0.9),
          padding: const EdgeInsets.all(24),
          child: SelectableText(text, style: AppText.bodyMd(Colors.white)),
        ),
      ],
    );
  }
}

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.sending = false,
    this.hint = 'Напиши задачу, например: «Встреча в 18:00»...',
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.surfaceHighest.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: 'Голосовой ввод',
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceHighest,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic_none,
                      size: 20,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !sending,
                    maxLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: sending ? null : (_) => onSend(),
                    style: AppText.bodyMd(Colors.white),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: hint,
                      hintMaxLines: 1,
                      hintStyle: AppText.bodyMd(AppColors.outline),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: 'Отправить',
                  enabled: !sending,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: sending ? null : onSend,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: sending
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.onPrimary,
                                ),
                              )
                            : const Icon(
                                Icons.send,
                                size: 20,
                                color: AppColors.onPrimary,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChatBottomNav extends StatelessWidget {
  const ChatBottomNav({
    super.key,
    this.selected = 0,
    this.onSelect,
    this.onProfile,
  });

  final int selected;
  final ValueChanged<int>? onSelect;
  final VoidCallback? onProfile;

  void _handle(int index) {
    final select = onSelect;
    if (select != null) {
      select(index);
      return;
    }
    if (index == 3) onProfile?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.75),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 24,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottom),
            child: SizedBox(
              height: 64,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: selected == 0 ? Icons.smart_toy : Icons.smart_toy_outlined,
                    label: 'AI Hub',
                    active: selected == 0,
                    onTap: () => _handle(0),
                  ),
                  _NavItem(
                    icon: selected == 1 ? Icons.check_circle : Icons.check_circle_outline,
                    label: 'Tasks',
                    active: selected == 1,
                    onTap: () => _handle(1),
                  ),
                  _NavItem(
                    icon: selected == 2 ? Icons.event : Icons.event_outlined,
                    label: 'Calendar',
                    active: selected == 2,
                    onTap: () => _handle(2),
                  ),
                  _NavItem(
                    icon: selected == 3 ? Icons.account_circle : Icons.account_circle_outlined,
                    label: 'Profile',
                    active: selected == 3,
                    onTap: () => _handle(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChatGlass extends StatelessWidget {
  const ChatGlass({
    super.key,
    required this.child,
    required this.radius,
    required this.color,
    required this.padding,
    this.topLeft,
  });

  final Widget child;
  final double radius;
  final double? topLeft;
  final Color color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(topLeft ?? radius),
      topRight: Radius.circular(radius),
      bottomLeft: Radius.circular(radius),
      bottomRight: Radius.circular(radius),
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: borderRadius,
            border: Border.all(color: AppColors.hairline),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class AiMessageHeader extends StatelessWidget {
  const AiMessageHeader({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.auto_awesome, size: 12, color: AppColors.onPrimary),
        ),
        const SizedBox(width: 6),
        Text('TRACKAPP AI', style: AppText.labelSm(AppColors.onSurface)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.labelSm(
              AppColors.outline,
              weight: FontWeight.w400,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class ChatTagChip extends StatelessWidget {
  const ChatTagChip({
    super.key,
    required this.label,
    this.icon,
    this.dot = false,
    this.strong = false,
  });

  final String label;
  final IconData? icon;
  final bool dot;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 4),
          ],
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppText.labelSm(
              strong ? Colors.white : AppColors.onSurface,
              weight: strong ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMiniChip extends StatelessWidget {
  const ChatMiniChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppText.labelSm(
          AppColors.outline,
          weight: FontWeight.w500,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class ChatPillButton extends StatelessWidget {
  const ChatPillButton({
    super.key,
    required this.icon,
    required this.label,
    this.filled = false,
    this.flexible = false,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final bool flexible;

  @override
  Widget build(BuildContext context) {
    final background = filled ? Colors.white : AppColors.surfaceHighest;
    final foreground = filled ? AppColors.onPrimary : AppColors.onSurface;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: foreground),
        const SizedBox(width: 6),
        Text(label, style: AppText.labelMd(foreground, weight: FontWeight.w600)),
      ],
    );

    return Semantics(
      button: true,
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: flexible ? FittedBox(fit: BoxFit.scaleDown, child: content) : content,
      ),
    );
  }
}

class SuggestionChip extends StatelessWidget {
  const SuggestionChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(label, style: AppText.labelMd(AppColors.onSurface)),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, this.alpha = 0.05});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: alpha),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/images/track_logo.png',
        width: 32,
        height: 32,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _HeaderTitles extends StatelessWidget {
  const _HeaderTitles();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'TRACKAPP',
              style: AppText.labelSm(
                AppColors.onSurfaceVariant,
                weight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        Text(
          'Ai Assistant',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.headlineSm(Colors.white),
        ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20, color: AppColors.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _EnginePill extends StatelessWidget {
  const _EnginePill();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text('AI TASK ENGINE', style: AppText.labelSm(Colors.white)),
              const SizedBox(width: 6),
              Text(
                '• Онлайн',
                style: AppText.labelSm(
                  AppColors.outline,
                  weight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccuracyPill extends StatelessWidget {
  const _AccuracyPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppText.labelSm(
              AppColors.onSurface,
              weight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusMeter extends StatelessWidget {
  const _FocusMeter({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.clamp(0, 1) * 100).round();

    return Column(
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: CustomPaint(
            painter: _FocusRingPainter(progress: progress.clamp(0, 1)),
            child: Center(
              child: Text(
                '$percent%',
                style: const TextStyle(
                  fontFamily: AppText.family,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Фокус',
          style: AppText.labelSm(
            AppColors.onSurfaceVariant,
            weight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.5;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final track = Paint()
      ..color = AppColors.surfaceHighest
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final value = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      value,
    );
  }

  @override
  bool shouldRepaint(covariant _FocusRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : AppColors.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minWidth: 56, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.surfaceHighest.withValues(alpha: 0.5) : null,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppText.labelSm(
                  color,
                  weight: active ? FontWeight.w500 : FontWeight.w400,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
