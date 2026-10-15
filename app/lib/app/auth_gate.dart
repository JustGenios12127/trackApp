import 'dart:async';

import 'package:flutter/material.dart';

import '../feautures/auth/auth_screen.dart';
import '../feautures/auth/data/account_tasks.dart';
import '../feautures/auth/data/auth_gateway.dart';
import '../feautures/home/data/chat_gateway.dart';
import '../feautures/home/home_shell.dart';
import 'app_theme.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.auth, this.chat, this.tasks});

  final AuthGateway? auth;
  final ChatGateway? chat;
  final AccountTasks? tasks;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthGateway _auth = widget.auth ?? SupabaseAuthGateway();
  StreamSubscription<AuthAccount?>? _subscription;
  Timer? _bootTimer;
  AuthAccount? _account;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _account = _auth.current;
    var opening = true;
    _subscription = _auth.changes.listen((account) {
      _account = account;
      _ready = true;
      if (opening || !mounted) return;
      setState(() {});
    });
    opening = false;
    _bootTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || _ready) return;
      setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _bootTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    if (!_ready && account == null) {
      return const _BootScreen();
    }
    if (account == null) {
      return AuthScreen(auth: _auth);
    }
    return _SignedInShell(
      account: account,
      auth: _auth,
      chat: widget.chat,
      tasks: widget.tasks,
    );
  }
}

class _SignedInShell extends StatelessWidget {
  const _SignedInShell({
    super.key,
    required this.account,
    required this.auth,
    this.chat,
    this.tasks,
  });

  final AuthAccount account;
  final AuthGateway auth;
  final ChatGateway? chat;
  final AccountTasks? tasks;

  @override
  Widget build(BuildContext context) {
    return HomeShell(
      key: ValueKey(account.id),
      account: account,
      auth: auth,
      chat: chat,
      tasks: tasks,
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      ),
    );
  }
}
