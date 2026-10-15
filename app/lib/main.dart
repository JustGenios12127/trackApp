import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'feautures/home/data/system_reminder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final url = dotenv.env['SUPABASE_URL'];
  final publishableKey = dotenv.env['SUPABASE_ANON_PUBLIC_KEY'];
  if (url == null ||
      url.isEmpty ||
      publishableKey == null ||
      publishableKey.isEmpty) {
    throw StateError(
      'В app/.env нужны SUPABASE_URL и SUPABASE_ANON_PUBLIC_KEY',
    );
  }

  await Supabase.initialize(
    url: url,
    publishableKey: publishableKey,
  );
  await SystemReminder.instance.initialize();

  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => const App(),
    ),
  );
}
