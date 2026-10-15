import 'package:supabase_flutter/supabase_flutter.dart';

class ChatTurn {
  const ChatTurn({required this.role, required this.content});

  final String role;
  final String content;
}

class StoredTask {
  const StoredTask({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.remind,
    this.remindAt,
    this.dueOn,
  });

  final String id;
  final String title;
  final String subtitle;
  final bool remind;
  final DateTime? remindAt;
  final DateTime? dueOn;
}

enum ChatKind { chat, created, listed }

class ChatResult {
  const ChatResult({
    required this.reply,
    this.tasks = const [],
    this.kind = ChatKind.chat,
  });

  final String reply;
  final List<StoredTask> tasks;
  final ChatKind kind;
}

class ChatException implements Exception {
  const ChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class ChatGateway {
  Future<ChatResult> reply({
    required List<ChatTurn> messages,
    required DateTime now,
  });

  Future<List<StoredTask>> reminders({required DateTime now});
}

class SupabaseChatGateway implements ChatGateway {
  const SupabaseChatGateway();

  @override
  Future<ChatResult> reply({
    required List<ChatTurn> messages,
    required DateTime now,
  }) async {
    final last = messages.isEmpty ? '' : messages.last.content.trim().toLowerCase();
    final list = last == '/task' || last == '/tasks';
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'chat',
        body: {
          'today': _isoDate(now),
          'timezone_offset_minutes': now.timeZoneOffset.inMinutes,
          if (list) 'command': 'list_tasks',
          if (!list)
            'messages': [
              for (final message in messages)
                {'role': message.role, 'content': message.content},
            ],
        },
      );
      return _read(response.data);
    } on ChatException {
      rethrow;
    } on FunctionException catch (error) {
      throw ChatException(_message(error));
    } catch (_) {
      throw const ChatException(
        'Не получилось получить ответ. Проверь интернет и попробуй ещё раз.',
      );
    }
  }

  ChatResult _read(dynamic data) {
    if (data is! Map) {
      throw const ChatException('Ассистент прислал пустой ответ.');
    }
    final reply = data['reply'];
    if (reply is! String || reply.trim().isEmpty) {
      throw const ChatException('Ассистент прислал пустой ответ.');
    }
    final tasks = <StoredTask>[];
    final rawTasks = data['tasks'];
    if (rawTasks is List) {
      for (final item in rawTasks) {
        if (item is! Map) continue;
        final title = item['title'];
        final subtitle = item['subtitle'];
        if (title is! String || subtitle is! String) continue;
        tasks.add(
          StoredTask(
            id: item['id'] is String ? item['id'] as String : '',
            title: title,
            subtitle: subtitle,
            remind: item['remind'] == true,
            remindAt: _instant(item['remind_at']),
            dueOn: _date(item['due_on']),
          ),
        );
      }
    }
    return ChatResult(
      reply: reply.trim(),
      tasks: tasks,
      kind: switch (data['kind']) {
        'created' => ChatKind.created,
        'listed' => ChatKind.listed,
        _ => ChatKind.chat,
      },
    );
  }

  @override
  Future<List<StoredTask>> reminders({required DateTime now}) async {
    final result = await reply(
      messages: const [ChatTurn(role: 'user', content: '/task')],
      now: now,
    );
    return result.tasks;
  }

  DateTime? _instant(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  DateTime? _date(Object? value) {
    if (value is! String || value.length < 10) return null;
    final parts = value.split('-');
    if (parts.length < 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  String _isoDate(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '${time.year}-$month-$day';
  }

  String _message(FunctionException error) {
    final details = error.details;
    if (details is Map) {
      final value = details['error'];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    if (error.status == 401 || error.status == 403) {
      return 'Сессия истекла. Войди снова.';
    }
    return 'Ассистент сейчас недоступен. Попробуй ещё раз.';
  }
}
