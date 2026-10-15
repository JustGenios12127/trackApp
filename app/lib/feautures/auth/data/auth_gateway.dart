import 'package:supabase_flutter/supabase_flutter.dart';

class AuthAccount {
  const AuthAccount({
    required this.id,
    required this.email,
    this.createdAt,
  });

  final String id;
  final String email;
  final DateTime? createdAt;
}

class AuthProblem implements Exception {
  const AuthProblem(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class AuthGateway {
  AuthAccount? get current;

  Stream<AuthAccount?> get changes;

  Future<void> signIn({required String email, required String password});

  Future<void> signUp({required String email, required String password});

  Future<void> signOut();
}

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  AuthAccount? get current => _account(_client.auth.currentUser);

  @override
  Stream<AuthAccount?> get changes {
    return _client.auth.onAuthStateChange.map(
      (state) => _account(state.session?.user),
    );
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (response.session == null) {
        throw const AuthProblem('Сессия не открылась. Попробуй ещё раз.');
      }
    } on AuthProblem {
      rethrow;
    } on AuthException catch (error) {
      throw AuthProblem(messageForAuthFailure(code: error.code, message: error.message));
    } catch (_) {
      throw const AuthProblem('Не получилось войти. Проверь интернет и попробуй ещё раз.');
    }
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      if (response.session != null) return;
      final identities = response.user?.identities;
      if (response.user != null && (identities == null || identities.isEmpty)) {
        throw const AuthProblem('Аккаунт с такой почтой уже есть. Войди.');
      }
      await signIn(email: email, password: password);
    } on AuthProblem {
      rethrow;
    } on AuthException catch (error) {
      throw AuthProblem(messageForAuthFailure(code: error.code, message: error.message));
    } catch (_) {
      throw const AuthProblem('Не получилось создать аккаунт. Проверь интернет и попробуй ещё раз.');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (error) {
      throw AuthProblem(messageForAuthFailure(code: error.code, message: error.message));
    } catch (_) {
      throw const AuthProblem('Не получилось выйти. Проверь интернет и попробуй ещё раз.');
    }
  }
}

AuthAccount? _account(User? user) {
  if (user == null) return null;
  return AuthAccount(
    id: user.id,
    email: user.email ?? '',
    createdAt: DateTime.tryParse(user.createdAt),
  );
}

String messageForAuthFailure({String? code, String? message}) {
  final known = _knownAuthMessage(code);
  if (known != null) return known;
  final text = (message ?? '').toLowerCase();
  if (text.contains('invalid login') || text.contains('invalid credentials')) {
    return _knownAuthMessage('invalid_credentials')!;
  }
  if (text.contains('email not confirmed')) {
    return _knownAuthMessage('email_not_confirmed')!;
  }
  if (text.contains('already registered') || text.contains('already exists')) {
    return _knownAuthMessage('user_already_exists')!;
  }
  if (text.contains('password')) {
    return _knownAuthMessage('weak_password')!;
  }
  return 'Не получилось войти. Проверь интернет и попробуй ещё раз.';
}

String? _knownAuthMessage(String? code) {
  return switch (code) {
    'invalid_credentials' => 'Неверный email или пароль.',
    'email_not_confirmed' => 'Сначала подтверди почту, затем войди.',
    'user_already_exists' || 'email_exists' => 'Аккаунт с такой почтой уже есть. Войди.',
    'weak_password' => 'Пароль слишком простой. Сделай его длиннее.',
    'over_request_rate_limit' ||
    'over_email_send_rate_limit' => 'Слишком много попыток. Подожди немного.',
    'signup_disabled' || 'email_provider_disabled' => 'Регистрация сейчас закрыта.',
    'validation_failed' => 'Проверь email и пароль.',
    'user_banned' => 'Этот аккаунт заблокирован.',
    _ => null,
  };
}
