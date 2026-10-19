import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../data/reminder_controller.dart';
import '../data/system_reminder.dart';

Future<bool> confirmDeleteTask(BuildContext context, String title) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: Text('Удалить задачу?', style: AppText.headlineSm(Colors.white)),
        content: Text(
          '«$title» пропадёт из списка.',
          style: AppText.bodyMd(AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Отмена', style: AppText.bodyMd(Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Удалить',
              style: AppText.bodyMd(Colors.white, weight: FontWeight.w600),
            ),
          ),
        ],
      );
    },
  );
  return answer == true;
}

class TaskDeleteButton extends StatelessWidget {
  const TaskDeleteButton({
    super.key,
    required this.title,
    required this.onPressed,
  });

  final String title;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Удалить «$title»',
      onPressed: onPressed,
      icon: const Icon(Icons.delete_outline, color: AppColors.outline, size: 20),
    );
  }
}

Future<void> forgetReminder(String id) async {
  await ReminderController.noteDismissed(id);
  await SystemReminder.instance.cancel(id);
}

void showDeleteError(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Не получилось удалить задачу. Попробуй ещё раз.'),
    ),
  );
}
