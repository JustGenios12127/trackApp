import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import '../home/widgets/chat_widgets.dart';
import 'data/auth_gateway.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.auth});

  final AuthGateway auth;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _register = false;
  var _busy = false;
  var _hidden = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final emailError = _emailError(_email.text);
    final passwordError = _passwordError(_password.text);
    if (emailError != null || passwordError != null) {
      setState(() => _error = emailError ?? passwordError);
      return;
    }
    if (_busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_register) {
        await widget.auth.signUp(
          email: _email.text,
          password: _password.text,
        );
      } else {
        await widget.auth.signIn(
          email: _email.text,
          password: _password.text,
        );
      }
    } on AuthProblem catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Не получилось войти. Проверь интернет и попробуй ещё раз.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _switchMode() {
    if (_busy) return;
    setState(() {
      _register = !_register;
      _error = null;
      _password.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _register ? 'Регистрация' : 'Вход';
    final action = _register ? 'Создать аккаунт' : 'Войти';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            const ChatBackdrop(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight - 52),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Mark(),
                          const SizedBox(height: 28),
                          Text(title, style: AppText.headlineSm(Colors.white).copyWith(fontSize: 32, height: 1.15)),
                          const SizedBox(height: 8),
                          Text(
                            'Задачи сохраняются в аккаунте. Если переустановишь приложение, они останутся на месте.',
                            style: AppText.bodyMd(AppColors.onSurfaceVariant),
                          ),
                          const SizedBox(height: 28),
                          ChatGlass(
                            radius: 28,
                            color: AppColors.surfaceContainer.withValues(alpha: 0.82),
                            padding: const EdgeInsets.all(18),
                            child: AutofillGroup(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _AuthField(
                                    controller: _email,
                                    label: 'Email',
                                    hint: 'you@email.com',
                                    icon: Icons.alternate_email,
                                    keyboard: TextInputType.emailAddress,
                                    action: TextInputAction.next,
                                    autofill: const [AutofillHints.email],
                                    enabled: !_busy,
                                  ),
                                  const SizedBox(height: 12),
                                  _AuthField(
                                    controller: _password,
                                    label: 'Пароль',
                                    hint: 'Минимум 6 символов',
                                    icon: Icons.lock_outline,
                                    hidden: _hidden,
                                    action: TextInputAction.done,
                                    autofill: [
                                      _register ? AutofillHints.newPassword : AutofillHints.password,
                                    ],
                                    enabled: !_busy,
                                    onSubmit: _submit,
                                    onToggleHidden: () => setState(() => _hidden = !_hidden),
                                  ),
                                  if (_error != null) ...[
                                    const SizedBox(height: 14),
                                    _Banner(
                                      icon: Icons.error_outline,
                                      text: _error!,
                                    ),
                                  ],
                                  const SizedBox(height: 18),
                                  _PrimaryButton(
                                    label: action,
                                    busy: _busy,
                                    onPressed: _submit,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Center(
                            child: TextButton(
                              onPressed: _busy ? null : _switchMode,
                              child: Text(
                                _register ? 'Уже есть аккаунт? Войти' : 'Нет аккаунта? Регистрация',
                                style: AppText.bodyMd(Colors.white, weight: FontWeight.w500),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _emailError(String value) {
  final email = value.trim();
  if (email.isEmpty) return 'Впиши email.';
  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  if (!ok) return 'Похоже, это не email.';
  return null;
}

String? _passwordError(String value) {
  if (value.isEmpty) return 'Впиши пароль.';
  if (value.length < 6) return 'Пароль должен быть не короче 6 символов.';
  return null;
}

class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/images/track_logo.png',
            width: 44,
            height: 44,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TRACKAPP',
              style: AppText.labelSm(AppColors.onSurfaceVariant, weight: FontWeight.w500),
            ),
            Text('Аккаунт', style: AppText.headlineSm(Colors.white)),
          ],
        ),
      ],
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.action,
    required this.autofill,
    required this.enabled,
    this.keyboard = TextInputType.text,
    this.hidden,
    this.onSubmit,
    this.onToggleHidden,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputAction action;
  final List<String> autofill;
  final bool enabled;
  final TextInputType keyboard;
  final bool? hidden;
  final VoidCallback? onSubmit;
  final VoidCallback? onToggleHidden;

  @override
  Widget build(BuildContext context) {
    final obscure = hidden == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.labelMd(AppColors.onSurfaceVariant)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboard,
          textInputAction: action,
          obscureText: obscure,
          autocorrect: hidden == null,
          enableSuggestions: hidden == null,
          autofillHints: autofill,
          onSubmitted: onSubmit == null ? null : (_) => onSubmit!(),
          style: AppText.bodyMd(Colors.white),
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppText.bodyMd(AppColors.outline),
            prefixIcon: Icon(icon, size: 20, color: AppColors.onSurfaceVariant),
            suffixIcon: onToggleHidden == null
                ? null
                : IconButton(
                    tooltip: obscure ? 'Показать пароль' : 'Скрыть пароль',
                    onPressed: enabled ? onToggleHidden : null,
                    icon: Icon(
                      obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
            filled: true,
            fillColor: AppColors.surfaceHighest.withValues(alpha: 0.72),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: AppText.bodySm(AppColors.onSurface))),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
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
                  : Text(label, style: AppText.bodyMd(AppColors.onPrimary, weight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }
}
