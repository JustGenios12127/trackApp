import 'package:app/app/app_theme.dart';
import 'package:app/feautures/auth/data/account_tasks.dart';
import 'package:app/feautures/home/tasks_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('в списке задач можно удалить вручную', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tasks = _MemoryTasks([
      const AccountTask(id: 'note', title: 'Без срока'),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: TasksScreen(now: DateTime(2026, 10, 14), tasks: tasks),
      ),
    );
    await tester.pump();

    expect(find.text('Без срока'), findsOneWidget);
    await tester.tap(find.byTooltip('Удалить «Без срока»'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Удалить'));
    await tester.pumpAndSettle();

    expect(find.text('Без срока'), findsNothing);
    expect(find.text('Пока задач нет'), findsOneWidget);
    expect(tasks.items, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

class _MemoryTasks implements AccountTasks {
  const _MemoryTasks(this.items);

  final List<AccountTask> items;

  @override
  Future<int> openCount() async => items.length;

  @override
  Future<List<AccountTask>> openList() async => items;

  @override
  Future<void> remove(String id) async {
    final before = items.length;
    items.removeWhere((task) => task.id == id);
    if (items.length == before) throw StateError('missing');
  }
}
