import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';

import 'screens/home.dart';
import 'styles/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Carrega tema, cores e idioma salvos (precisa vir depois do init do banco).
  await AppSettings.instance.load();

  runApp(const StudyApp());
}

class StudyApp extends StatelessWidget {
  const StudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Reconstrói o MaterialApp sempre que as configurações mudam
    // (modo claro/escuro, cor de destaque, paleta do heatmap).
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
          // Escala de fonte (Settings > Accessibility), somada à do sistema.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(mq.textScaler.scale(1.0) * settings.fontScale),
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
