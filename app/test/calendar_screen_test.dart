import 'package:app/app/app_theme.dart';
import 'package:app/feautures/auth/data/account_tasks.dart';
import 'package:app/feautures/home/calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('экран календаря показывает задачи выбранного дня', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CalendarScreen(
          now: DateTime(2026, 10, 14),
          tasks: _MemoryTasks([
            AccountTask(
              id: 'wash',
              title: 'Постирать вещи',
              dueOn: DateTime(2026, 10, 16),
              remindAt: DateTime(2026, 10, 16, 21),
            ),
            AccountTask(
              id: 'coffee',
              title: 'Купить кофе',
              dueOn: DateTime(2026, 10, 20),
            ),
            const AccountTask(id: 'note', title: 'Без срока'),
          ]),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Календарь'), findsOneWidget);
    expect(find.text('Октябрь 2026'), findsOneWidget);
    expect(find.text('Пятница'), findsOneWidget);
    expect(find.text('Постирать вещи'), findsOneWidget);
    expect(find.text('21:00'), findsOneWidget);
    expect(find.text('Купить кофе'), findsNothing);
    expect(find.text('Без срока'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('day-2026-10-20')));
    await tester.pump();

    expect(find.text('Купить кофе'), findsOneWidget);
    expect(find.text('Вт, 20 окт'), findsOneWidget);
    expect(find.text('Постирать вещи'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('пустой календарь говорит, что задач нет', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CalendarScreen(
          now: DateTime(2026, 10, 14),
          tasks: _MemoryTasks(const []),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Пока задач нет'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ошибка загрузки предлагает повтор', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CalendarScreen(
          now: DateTime(2026, 10, 14),
          tasks: _MemoryTasks(const [], fail: true),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Не удалось загрузить задачи. Повторить'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MemoryTasks implements AccountTasks {
  const _MemoryTasks(this.items, {this.fail = false});

  final List<AccountTask> items;
  final bool fail;

  @override
  Future<int> openCount() async => items.length;

  @override
  Future<List<AccountTask>> openList() async {
    if (fail) throw Exception('network');
    return items;
  }
}
