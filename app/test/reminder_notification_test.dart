import 'package:app/feautures/home/data/chat_gateway.dart';
import 'package:app/feautures/home/data/reminder_controller.dart';
import 'package:app/feautures/home/data/system_reminder.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('кнопка «Понятно» в уведомлении запоминает закрытие', () async {
    final id = reminderDismissedId(
      const NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        actionId: 'dismiss',
        payload: 'wash',
      ),
    );
    expect(id, 'wash');
    expect(
      reminderDismissedId(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: 'dismiss:fold',
          payload: 'dismiss:fold',
        ),
      ),
      'fold',
    );
    expect(
      reminderDismissedId(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: 'wash',
        ),
      ),
      isNull,
    );

    await ReminderController.noteDismissed(id!);
    final controller = ReminderController();
    addTearDown(controller.dispose);
    await controller.replace([
      StoredTask(
        id: 'wash',
        title: 'Постирать',
        subtitle: '14:00',
        remind: true,
        remindAt: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    ]);
    expect(controller.current, isNull);
  });
}
