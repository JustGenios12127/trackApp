import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import '../auth/data/account_tasks.dart';
import '../auth/data/auth_gateway.dart';
import '../auth/profile_screen.dart';
import 'calendar_screen.dart';
import 'chat_screen.dart';
import 'data/chat_gateway.dart';
import 'tasks_screen.dart';
import 'widgets/chat_widgets.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
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
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  var _index = 0;
  final _built = <int>{0};

  void _select(int index) {
    if (_index == index) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _index = index;
      _built.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_index != 0) {
          _select(0);
          return;
        }
        SystemNavigator.pop();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppColors.surface,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: AppColors.surface,
          resizeToAvoidBottomInset: true,
          body: Stack(
            fit: StackFit.expand,
            children: [
              _page(
                0,
                ChatScreen(
                  embedded: true,
                  gateway: widget.chat,
                ),
              ),
              _page(
                1,
                TasksScreen(
                  tasks: widget.tasks,
                  onOpenChat: () => _select(0),
                  visible: _index == 1,
                ),
              ),
              _page(2, const CalendarScreen()),
              _page(
                3,
                ProfileScreen(
                  account: widget.account,
                  auth: widget.auth,
                  tasks: widget.tasks,
                  visible: _index == 3,
                ),
              ),
            ],
          ),
          bottomNavigationBar: ChatBottomNav(
            selected: _index,
            onSelect: _select,
          ),
        ),
      ),
    );
  }

  Widget _page(int index, Widget child) {
    if (!_built.contains(index)) return const SizedBox.shrink();
    return Offstage(offstage: _index != index, child: child);
  }
}
