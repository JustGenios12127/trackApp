import 'package:app/app/app_theme.dart';
import 'package:app/feautures/home/chat_screen.dart';
import 'package:app/feautures/home/data/chat_gateway.dart';
import 'package:app/feautures/home/models/chat_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('пустой чат не показывает шаблонные задачи', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const ChatScreen(),
      ),
    );

    expect(find.text('Ai Assistant'), findsOneWidget);
    expect(find.text('AI Hub'), findsOneWidget);
    expect(
      find.text('Напиши задачу, например: «Встреча в 18:00»...'),
      findsOneWidget,
    );
    expect(find.text('3 задачи на сегодня'), findsNothing);
    expect(find.text('99.4% точность'), findsNothing);
    expect(find.text('Купить зерновой кофе'), findsNothing);
    expect(find.text('Созвон с командой по дизайну'), findsNothing);
    expect(find.text('БЫСТРЫЕ ПОДСКАЗКИ AI'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('чат рисует только переданные сообщения', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const ChatScreen(
          items: [
            UserMessage(text: 'Купить молоко', meta: '14:10 • Доставлено'),
          ],
        ),
      ),
    );

    expect(find.text('Купить молоко'), findsOneWidget);
    expect(find.text('Купить зерновой кофе'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('отправка показывает ответ ассистента', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ChatScreen(
          gateway: _ScriptedGateway((messages, now) async {
            return ChatResult(reply: 'Принял: ${messages.last.content}');
          }),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Купить молоко');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump();

    expect(find.text('Купить молоко'), findsOneWidget);
    expect(find.text('Принял: Купить молоко'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ошибка ассистента остаётся в чате', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ChatScreen(
          gateway: _ScriptedGateway((messages, now) async {
            throw const ChatException('Ассистент сейчас недоступен.');
          }),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Привет');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump();

    expect(find.text('Привет'), findsOneWidget);
    expect(find.text('Ассистент сейчас недоступен.'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('очистка чата не стирает задачи из базы', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final stored = <StoredTask>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ChatScreen(
          gateway: _ScriptedGateway((messages, now) async {
            final text = messages.last.content;
            if (text == '/task') {
              return ChatResult(
                reply: stored.isEmpty ? 'Пока задач нет.' : 'Все задачи',
                tasks: [...stored],
                kind: ChatKind.listed,
              );
            }
            final today = DateTime.now();
            stored.add(
              StoredTask(
                id: '1',
                title: 'Сделать уборку',
                subtitle: 'Сегодня',
                remind: false,
                dueOn: DateTime(today.year, today.month, today.day),
              ),
            );
            return ChatResult(
              reply: 'Записал «Сделать уборку» на сегодня.',
              tasks: [...stored],
              kind: ChatKind.created,
            );
          }),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'запиши задачу сделать уборку');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump();
    expect(find.text('Сделать уборку'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pump();
    expect(find.text('Сделать уборку'), findsNothing);

    await tester.enterText(find.byType(TextField), '/task');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Все задачи'), findsWidgets);
    expect(find.text('Сделать уборку'), findsOneWidget);
    expect(find.text('Сегодня'), findsOneWidget);
    expect(find.text('Пн'), findsWidgets);
    expect(find.text('Вс'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('напоминание показывается карточкой и закрывается', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final due = StoredTask(
      id: 'wash',
      title: 'Постирать вещи',
      subtitle: 'Пт, 16 окт · 14:00',
      remind: true,
      remindAt: DateTime.now().subtract(const Duration(minutes: 1)),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ChatScreen(
          gateway: _ScriptedGateway(
            (_, _) async => const ChatResult(reply: 'ок'),
            pending: [due],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Постирать вещи'), findsOneWidget);
    expect(find.text('• Напоминание'), findsOneWidget);
    expect(find.text('Пт, 16 окт · 14:00'), findsOneWidget);

    await tester.tap(find.text('Понятно'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('• Напоминание'), findsNothing);
    expect(find.text('Постирать вещи'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _ScriptedGateway implements ChatGateway {
  const _ScriptedGateway(this._reply, {this.pending = const []});

  final Future<ChatResult> Function(List<ChatTurn> messages, DateTime now) _reply;
  final List<StoredTask> pending;

  @override
  Future<ChatResult> reply({
    required List<ChatTurn> messages,
    required DateTime now,
  }) {
    return _reply(messages, now);
  }

  @override
  Future<List<StoredTask>> reminders({required DateTime now}) async => pending;
}
