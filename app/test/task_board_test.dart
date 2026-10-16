import 'package:app/app/app_theme.dart';
import 'package:app/feautures/home/data/task_calendar.dart';
import 'package:app/feautures/home/models/chat_item.dart';
import 'package:app/feautures/home/widgets/task_board_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('неделя начинается с понедельника', () {
    final wednesday = DateTime(2026, 10, 14);
    final week = TaskCalendar.weekOf(wednesday);
    expect(week.first, DateTime(2026, 10, 12));
    expect(week.last, DateTime(2026, 10, 18));
    expect(week.map((day) => day.weekday).toList(), [1, 2, 3, 4, 5, 6, 7]);
    expect(TaskCalendar.monthGrid(DateTime(2026, 10)).first.weekday, 1);
  });

  test('задача со временем остаётся в своём дне', () {
    final grouped = TaskCalendar.groupByDay([
      TaskDraft(
        title: 'Вечер',
        subtitle: '',
        icon: Icons.task_alt,
        dueOn: DateTime(2026, 10, 16, 21),
      ),
    ]);
    expect(grouped[DateTime(2026, 10, 16)]!.single.title, 'Вечер');
    expect(
      TaskCalendar.whenLabel(
        DateTime(2026, 10, 16, 21),
        DateTime(2026, 10, 16, 21),
        DateTime(2026, 10, 14),
      ),
      'Пт, 16 окт · 21:00',
    );
  });

  test('открывается ближайший день с задачей', () {
    final tasks = [
      TaskDraft(
        title: 'Позже',
        subtitle: '',
        icon: Icons.task_alt,
        dueOn: DateTime(2026, 10, 20),
      ),
      TaskDraft(
        title: 'Пятница',
        subtitle: '',
        icon: Icons.task_alt,
        dueOn: DateTime(2026, 10, 16),
      ),
    ];
    expect(
      TaskCalendar.initialDay(tasks, DateTime(2026, 10, 14)),
      DateTime(2026, 10, 16),
    );
  });

  testWidgets('календарь показывает неделю и задачи другого дня', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: TaskBoardSheet(
            now: DateTime(2026, 10, 14),
            tasks: [
              TaskDraft(
                title: 'Постирать вещи',
                subtitle: 'Пт, 16 окт · 21:00',
                icon: Icons.notifications_active_outlined,
                dueOn: DateTime(2026, 10, 16),
                remindAt: DateTime(2026, 10, 16, 21),
              ),
              TaskDraft(
                title: 'Купить кофе',
                subtitle: 'Вт, 20 окт',
                icon: Icons.task_alt,
                dueOn: DateTime(2026, 10, 20),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Пн'), findsWidgets);
    expect(find.text('Вс'), findsWidgets);
    expect(find.text('Постирать вещи'), findsOneWidget);
    expect(find.text('21:00'), findsOneWidget);
    expect(find.text('Октябрь 2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('month-2026-10-20')));
    await tester.pump();

    expect(find.text('Купить кофе'), findsOneWidget);
    expect(find.text('Постирать вещи'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
