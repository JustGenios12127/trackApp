import 'package:flutter/material.dart';

class DailyOverview {
  const DailyOverview({
    required this.dateLabel,
    required this.title,
    this.subtitle,
    required this.focus,
  });

  final String dateLabel;
  final String title;
  final String? subtitle;
  final double focus;
}

class ChatTag {
  const ChatTag({
    required this.label,
    this.icon,
    this.dot = false,
    this.strong = false,
  });

  final String label;
  final IconData? icon;
  final bool dot;
  final bool strong;
}

class EventDraft {
  const EventDraft({
    required this.title,
    required this.subtitle,
    this.trailingIcon = Icons.event_available_outlined,
    this.tags = const [],
    this.primaryLabel = 'Подтвердить',
    this.secondaryLabel = 'Изменить',
  });

  final String title;
  final String subtitle;
  final IconData trailingIcon;
  final List<ChatTag> tags;
  final String primaryLabel;
  final String secondaryLabel;
}

class TaskDraft {
  const TaskDraft({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.dueOn,
    this.remindAt,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final DateTime? dueOn;
  final DateTime? remindAt;
}

class SuggestionChipData {
  const SuggestionChipData({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

sealed class ChatItem {
  const ChatItem();
}

class TimeMark extends ChatItem {
  const TimeMark(this.label);

  final String label;
}

class UserMessage extends ChatItem {
  const UserMessage({required this.text, required this.meta});

  final String text;
  final String meta;
}

class AiReplyMessage extends ChatItem {
  const AiReplyMessage({
    required this.text,
    this.status = '• Готово',
  });

  final String text;
  final String status;
}

class AiEventMessage extends ChatItem {
  const AiEventMessage({
    required this.status,
    required this.text,
    required this.event,
  });

  final String status;
  final String text;
  final EventDraft event;
}

class AiTaskListMessage extends ChatItem {
  const AiTaskListMessage({
    required this.status,
    required this.text,
    this.badge,
    required this.tasks,
    required this.saveLabel,
    this.saved = false,
    this.board = false,
  });

  final String status;
  final String text;
  final String? badge;
  final List<TaskDraft> tasks;
  final String saveLabel;
  final bool saved;
  final bool board;
}
