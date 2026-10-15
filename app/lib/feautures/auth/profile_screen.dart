import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import '../home/widgets/chat_widgets.dart';
import '../home/widgets/tab_header.dart';
import 'data/account_tasks.dart';
import 'data/auth_gateway.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.account,
    required this.auth,
    this.tasks,
    this.visible = true,
  });

  final AuthAccount account;
  final AuthGateway auth;
  final AccountTasks? tasks;
  final bool visible;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final AccountTasks _tasks = widget.tasks ?? const SupabaseAccountTasks();
  int? _openCount;
  var _counting = true;
  var _countFailed = false;
  var _leaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.visible) {
      _loadCount(silent: true);
    } else {
      _counting = false;
    }
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _loadCount(silent: _openCount != null);
    }
  }

  Future<void> _loadCount({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _counting = true;
        _countFailed = false;
      });
    }
    try {
      final count = await _tasks.openCount();
      if (!mounted) return;
      setState(() {
        _openCount = count;
        _counting = false;
        _countFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _counting = false;
        _countFailed = _openCount == null;
      });
    }
  }

  Future<void> _signOut() async {
    if (_leaving) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceContainer,
          title: Text('Выйти из аккаунта?', style: AppText.headlineSm(Colors.white)),
          content: Text(
            'Задачи останутся в базе. Они снова появятся, когда войдёшь с этой почтой.',
            style: AppText.bodyMd(AppColors.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Остаться', style: AppText.bodyMd(AppColors.onSurface)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Выйти', style: AppText.bodyMd(Colors.white, weight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
    if (leave != true || !mounted) return;

    setState(() => _leaving = true);
    try {
      await widget.auth.signOut();
    } on AuthProblem catch (error) {
      if (!mounted) return;
      setState(() => _leaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _leaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не получилось выйти. Проверь интернет и попробуй ещё раз.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final email = account.email.isEmpty ? 'Без почты' : account.email;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Stack(
          children: [
            const ChatBackdrop(),
            Column(
              children: [
                const TabHeader(title: 'Профиль'),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                    children: [
                      Center(child: _AvatarMark(letter: _letter(email))),
                      const SizedBox(height: 16),
                      Text(
                        email,
                        textAlign: TextAlign.center,
                        style: AppText.headlineSm(Colors.white),
                      ),
                      const SizedBox(height: 10),
                      Center(child: _SincePill(label: _since(account.createdAt))),
                      const SizedBox(height: 28),
                      _TasksCard(
                        counting: _counting,
                        failed: _countFailed,
                        count: _openCount ?? 0,
                        onRetry: _loadCount,
                      ),
                      const SizedBox(height: 20),
                      _SignOutButton(busy: _leaving, onPressed: _signOut),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarMark extends StatelessWidget {
  const _AvatarMark({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceHigh.withValues(alpha: 0.85),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Text(
          letter,
          style: const TextStyle(
            fontFamily: AppText.family,
            fontSize: 28,
            height: 1,
            fontWeight: FontWeight.w600,
            color: AppColors.onPrimary,
          ),
        ),
      ),
    );
  }
}

class _SincePill extends StatelessWidget {
  const _SincePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Text(label, style: AppText.bodySm(AppColors.onSurfaceVariant)),
    );
  }
}

class _TasksCard extends StatelessWidget {
  const _TasksCard({
    required this.counting,
    required this.failed,
    required this.count,
    required this.onRetry,
  });

  final bool counting;
  final bool failed;
  final int count;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ChatGlass(
      radius: 24,
      color: AppColors.surfaceContainer.withValues(alpha: 0.82),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.checklist_rounded, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text(
                'ЗАДАЧИ АККАУНТА',
                style: AppText.labelSm(AppColors.onSurfaceVariant, weight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (counting)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          else if (failed)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(48, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Не удалось посчитать. Повторить',
                style: AppText.bodyMd(Colors.white),
              ),
            )
          else
            Text(
              _openLabel(count),
              style: const TextStyle(
                fontFamily: AppText.family,
                fontSize: 26,
                height: 1.2,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
                color: Colors.white,
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Список живёт на сервере и привязан к этой почте. Очистка чата его не удаляет.',
            style: AppText.bodyMd(AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Выйти',
      enabled: !busy,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: busy ? null : onPressed,
          child: SizedBox(
            height: 52,
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                    )
                  : Text(
                      'Выйти',
                      style: AppText.bodyMd(AppColors.onPrimary, weight: FontWeight.w600),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

String _letter(String email) {
  final trimmed = email.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.characters.first.toUpperCase();
}

String _since(DateTime? time) {
  if (time == null) return 'Дата регистрации неизвестна';
  final local = time.toLocal();
  const months = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];
  return 'В аккаунте с ${local.day} ${months[local.month - 1]} ${local.year}';
}

String _openLabel(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  final word = mod10 == 1 && mod100 != 11
      ? 'открытая задача'
      : (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14))
      ? 'открытые задачи'
      : 'открытых задач';
  return '$count $word';
}
