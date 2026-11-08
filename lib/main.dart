import 'package:flutter/material.dart';

import 'data/platform/database_setup.dart';

import 'data/services/sync_service.dart';
import 'screens/home.dart';
import 'styles/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  initializeDatabase();

  await AppSettings.instance.load();
  await SyncService.instance.init();

  runApp(const StudyApp());
}

class StudyApp extends StatelessWidget {
  const StudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final settings = AppSettings.instance;
        return MaterialApp(
          title: 'Study App',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(settings, Brightness.light),
          darkTheme: AppTheme.build(settings, Brightness.dark),
          themeMode: settings.themeMode,
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(
                  mq.textScaler.scale(1.0) * settings.fontScale,
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const Home(),
        );
      },
    );
  }
}
