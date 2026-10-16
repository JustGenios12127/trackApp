import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../data/chat_gateway.dart';
import '../data/task_calendar.dart';

const _ink = Color(0xFF121214);
const _quiet = Color(0xFF3E4142);

class ReminderBanner extends StatefulWidget {
  const ReminderBanner({
    super.key,
    required this.task,
    required this.onDismiss,
  });

  final StoredTask task;
  final VoidCallback onDismiss;

  @override
  State<ReminderBanner> createState() => _ReminderBannerState();
}

class _ReminderBannerState extends State<ReminderBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stroke = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );
  late final CurvedAnimation _mark = CurvedAnimation(
    parent: _stroke,
    curve: Curves.easeOutCubic,
  );
  var _armed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_armed) return;
    _armed = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _stroke.value = 1;
      return;
    }
    _stroke.forward();
  }

  @override
  void dispose() {
    _mark.dispose();
    _stroke.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final time = TaskCalendar.clock(task.remindAt);
    final subtitle = task.subtitle.trim();
    final clock = time != null && time.isNotEmpty;
    final hero = clock ? time : task.title;
    final title = clock ? task.title : '';

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x73000000),
            blurRadius: 32,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hero,
                          maxLines: clock ? 1 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: _hero(clock),
                        ),
                        const SizedBox(height: 8),
                        _Stroke(animation: _mark),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/track_logo.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      semanticLabel: 'Track',
                    ),
                  ),
                ],
              ),
              if (title.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.headlineSm(_ink),
                ),
              ],
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySm(_quiet),
                ),
              ],
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: _DismissButton(onPressed: widget.onDismiss),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _hero(bool clock) {
    return TextStyle(
      fontFamily: AppText.family,
      fontSize: clock ? 40 : 26,
      height: 1,
      fontWeight: FontWeight.w600,
      letterSpacing: clock ? -1.2 : -0.5,
      color: _ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}

class _Stroke extends StatelessWidget {
  const _Stroke({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 72 * animation.value,
            height: 2,
            decoration: BoxDecoration(
              color: _ink,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      },
    );
  }
}

class _DismissButton extends StatelessWidget {
  const _DismissButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(_ink),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return const Color(0x24FFFFFF);
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return const Color(0x14FFFFFF);
          }
          return null;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return const BorderSide(color: Colors.white, width: 2);
          }
          return null;
        }),
        minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        textStyle: WidgetStatePropertyAll(
          AppText.labelMd(Colors.white, weight: FontWeight.w600),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 16),
          SizedBox(width: 6),
          Text('Понятно'),
        ],
      ),
    );
  }
}
