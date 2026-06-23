import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'services/notifications_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await NotificationsService.init();

  final appState = AppState();
  await appState.init();
  // Fire-and-forget daily nudge scheduling (non-fatal if it fails).
  NotificationsService.requestPermissions();
  NotificationsService.scheduleDailyNudge();

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
