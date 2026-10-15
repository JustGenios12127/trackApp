import 'package:app/feautures/home/data/chat_gateway.dart';
import 'package:app/feautures/home/data/reminder_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 16, 9);

  StoredTask task(String id, DateTime at) {
    return StoredTask(
      id: id,
      title: id,
      subtitle: 'Пт, 16 окт · 14:00',
      remind: true,
      remindAt: at,
    );
  }

  test('будущее напоминание ещё не показывается', () {
    final future = task('later', now.add(const Duration(hours: 2)));
    expect(ReminderPlanner.current([future], now, {}), isNull);
    expect(
      ReminderPlanner.untilNext([future], now, {}),
      const Duration(hours: 1),
    );
  });

  test('ближайшее время ожидания не обрезается часом', () {
    final soon = task('soon', now.add(const Duration(minutes: 30)));
    expect(
      ReminderPlanner.untilNext([soon], now, {}),
      const Duration(minutes: 30),
    );
  });

  test('просроченное в пределах 12 часов показывается, старое нет', () {
    final fresh = task('fresh', now.subtract(const Duration(minutes: 1)));
    final stale = task('stale', now.subtract(const Duration(hours: 13)));
    expect(ReminderPlanner.current([fresh], now, {})?.id, 'fresh');
    expect(ReminderPlanner.current([stale], now, {}), isNull);
  });

  test('закрытое напоминание не возвращается, из двух берётся свежее', () {
    final older = task('old', now.subtract(const Duration(hours: 2)));
    final newer = task('new', now.subtract(const Duration(minutes: 5)));
    expect(ReminderPlanner.current([older, newer], now, {})?.id, 'new');
    expect(ReminderPlanner.current([newer], now, {'new'}), isNull);
  });
}
