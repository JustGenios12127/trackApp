import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'auth_gate.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      title: 'Track',
      theme: AppTheme.dark,
      home: const AuthGate(),
    );
  }
}