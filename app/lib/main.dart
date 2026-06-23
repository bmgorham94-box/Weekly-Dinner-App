import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'services/notifications_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // Use the IndexedDB-backed sqflite factory in the browser.
    databaseFactory = databaseFactoryFfiWeb;
  } else {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await NotificationsService.init();
  }

  final appState = AppState();
  await appState.init();

  if (!kIsWeb) {
    // Fire-and-forget daily nudge scheduling (non-fatal; not supported on web).
    NotificationsService.requestPermissions();
    NotificationsService.scheduleDailyNudge();
  }

  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const TheLogApp(),
    ),
  );
}

class TheLogApp extends StatelessWidget {
  const TheLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Log',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const HomeShell(),
    );
  }
}
