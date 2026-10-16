import 'dart:async';

import 'package:app/app/app_theme.dart';
import 'package:app/app/auth_gate.dart';
import 'package:app/feautures/auth/auth_screen.dart';
import 'package:app/feautures/auth/data/account_tasks.dart';
import 'package:app/feautures/auth/data/auth_gateway.dart';
import 'package:app/feautures/auth/profile_screen.dart';
import 'package:app/feautures/home/data/chat_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('сообщения об ошибках входа понятны', () {
    expect(
      messageForAuthFailure(code: 'invalid_credentials'),
      'Неверный email или пароль.',
    );
    expect(
      messageForAuthFailure(message: 'Invalid login credentials'),
      'Неверный email или пароль.',
    );
    expect(
      messageForAuthFailure(code: 'email_not_confirmed'),
      'Сначала подтверди почту, затем войди.',
    );
    expect(
      messageForAuthFailure(code: 'user_already_exists'),
      'Аккаунт с такой почтой уже есть. Войди.',
    );
  });

  testWidgets('пустой вход просит email и пароль', (tester) async {
    await _pump(tester, AuthScreen(auth: _MemoryAuth()));

    await tester.tap(find.text('Войти'));
    await tester.pump();

    expect(find.text('Впиши email.'), findsOneWidget);
    expect(find.text('Регистрация'), findsNothing);
  });

  testWidgets('переключение на регистрацию и вход с аккаунтом', (tester) async {
    final auth = _MemoryAuth();
    await _pump(tester, AuthScreen(auth: auth));

    await tester.tap(find.text('Нет аккаунта? Регистрация'));
    await tester.pump();
    expect(find.text('Регистрация'), findsWidgets);
    expect(find.text('Создать аккаунт'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'ada@track.app');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.text('Создать аккаунт'));
    await tester.pump();

    expect(auth.signedUp, 'ada@track.app');
    expect(auth.current?.email, 'ada@track.app');
  });

  testWidgets('регистрация сразу открывает аккаунт', (tester) async {
    final auth = _MemoryAuth();
    await _pump(tester, AuthScreen(auth: auth));

    await tester.tap(find.text('Нет аккаунта? Регистрация'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(0), 'ada@track.app');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.text('Создать аккаунт'));
    await tester.pump();

    expect(
      find.text('Аккаунт создан. Подтверди почту и затем войди.'),
      findsNothing,
    );
    expect(auth.current?.email, 'ada@track.app');
  });

  testWidgets('неверный пароль остаётся на экране входа', (tester) async {
    final auth = _MemoryAuth()
      ..failure = const AuthProblem('Неверный email или пароль.');
    await _pump(tester, AuthScreen(auth: auth));

    await tester.enterText(find.byType(TextField).at(0), 'ada@track.app');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.text('Войти'));
    await tester.pump();

    expect(find.text('Неверный email или пароль.'), findsOneWidget);
    expect(auth.current, isNull);
  });

  testWidgets('после входа открывается чат и профиль', (tester) async {
    final auth = _MemoryAuth(
      current: const AuthAccount(
        id: 'user-1',
        email: 'ada@track.app',
        createdAt: null,
      ),
    );

    await _pump(
      tester,
      AuthGate(
        auth: auth,
        chat: const _QuietChat(),
        tasks: const _FixedTasks(2),
      ),
    );
    await tester.pump();

    expect(find.text('Ai Assistant'), findsOneWidget);
    expect(find.text('AI Hub'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pump();
    await tester.pump();

    expect(find.text('ada@track.app'), findsOneWidget);
    expect(find.text('2 открытые задачи'), findsOneWidget);
    expect(find.text('Выйти'), findsOneWidget);
    expect(find.text('Профиль'), findsOneWidget);
    expect(find.text('AI Hub'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);

    await tester.tap(find.text('Tasks'));
    await tester.pump();
    expect(find.text('Задачи'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.text('Calendar'));
    await tester.pump();
    expect(find.text('Календарь'), findsOneWidget);
    expect(find.text('AI Hub'), findsOneWidget);

    await tester.tap(find.text('AI Hub'));
    await tester.pump();
    expect(find.text('Ai Assistant'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pump();

    await tester.tap(find.text('Выйти'));
    await tester.pump();
    await tester.tap(find.text('Остаться'));
    await tester.pump();
    expect(find.text('ada@track.app'), findsOneWidget);

    await tester.tap(find.text('Выйти'));
    await tester.pump();
    await tester.tap(find.text('Выйти').last);
    await tester.pump();
    await tester.pump();

    expect(find.text('Вход'), findsOneWidget);
    expect(auth.current, isNull);
    expect(find.text('AI Hub'), findsNothing);
  });

  testWidgets('профиль без задач говорит, что список пуст', (tester) async {
    await _pump(
      tester,
      ProfileScreen(
        account: const AuthAccount(id: 'user-1', email: 'ada@track.app'),
        auth: _MemoryAuth(),
        tasks: const _FixedTasks(0),
      ),
    );
    await tester.pump();

    expect(find.text('0 открытых задач'), findsOneWidget);
    expect(find.text('Дата регистрации неизвестна'), findsOneWidget);
  });

  testWidgets('чат без аккаунта не открывается', (tester) async {
    await _pump(
      tester,
      AuthGate(auth: _MemoryAuth(), chat: const _QuietChat()),
    );
    await tester.pump();

    expect(find.text('Вход'), findsOneWidget);
    expect(find.text('Ai Assistant'), findsNothing);
  });
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: home));
}

class _MemoryAuth implements AuthGateway {
  _MemoryAuth({this.current});

  @override
  AuthAccount? current;
  AuthProblem? failure;
  String? signedUp;
  final _updates = StreamController<AuthAccount?>.broadcast();

  @override
  Stream<AuthAccount?> get changes {
    return Stream<AuthAccount?>.multi((controller) {
      controller.add(current);
      final subscription = _updates.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    final failure = this.failure;
    if (failure != null) throw failure;
    current = AuthAccount(
      id: 'user-1',
      email: email.trim(),
      createdAt: DateTime.utc(2026, 10, 14),
    );
    _updates.add(current);
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    signedUp = email.trim();
    current = AuthAccount(id: 'user-1', email: email.trim());
    _updates.add(current);
  }

  @override
  Future<void> signOut() async {
    current = null;
    _updates.add(null);
  }
}

class _FixedTasks implements AccountTasks {
  const _FixedTasks(this.count);

  final int count;

  @override
  Future<int> openCount() async => count;

  @override
  Future<List<AccountTask>> openList() async => const [];
}

class _QuietChat implements ChatGateway {
  const _QuietChat();

  @override
  Future<ChatResult> reply({
    required List<ChatTurn> messages,
    required DateTime now,
  }) async {
    return const ChatResult(reply: 'ок');
  }

  @override
  Future<List<StoredTask>> reminders({required DateTime now}) async => const [];
}
