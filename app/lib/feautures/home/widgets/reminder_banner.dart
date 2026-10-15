import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../data/chat_gateway.dart';
import 'chat_widgets.dart';

class ReminderBanner extends StatelessWidget {
  const ReminderBanner({
    super.key,
    required this.task,
    required this.onDismiss,
  });

  final StoredTask task;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x73000000),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ChatGlass(
        radius: 24,
        color: AppColors.surfaceLow.withValues(alpha: 0.92),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_outlined,
                    size: 12,
                    color: AppColors.onPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Text('TRACKAPP', style: AppText.labelSm(AppColors.onSurface)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '• Напоминание',
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
            ),
            const SizedBox(height: 12),
            Text(task.title, style: AppText.headlineSm(Colors.white)),
            const SizedBox(height: 2),
            Text(
              task.subtitle,
              style: AppText.bodySm(AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: onDismiss,
                child: const ChatPillButton(
                  icon: Icons.check,
                  label: 'Понятно',
                  filled: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
