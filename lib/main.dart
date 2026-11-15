import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/database_helper.dart';
import 'data/platform/database_factory_stub.dart'
    if (dart.library.io) 'data/platform/database_factory_io.dart'
    if (dart.library.js_interop) 'data/platform/database_factory_web.dart' as platform_database;
import 'data/services/sync_service.dart';
import 'screens/home.dart';
import 'styles/app_theme.dart';
import 'l10n/strings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure the platform factory before any database access.
  platform_database.configureDatabaseFactory();

  // Show a loading state immediately. A failed database initialization should
  // not leave the browser displaying a blank page without an explanation.
  runApp(const StudyApp());
}

class StudyApp extends StatefulWidget {
  const StudyApp({super.key});

  @override
  State<StudyApp> createState() => _StudyAppState();
}

class _StudyAppState extends State<StudyApp> {
  late Future<void> _startup;

  @override
  void initState() {
    super.initState();
    _startup = _initialize();
  }

  Future<void> _initialize() async {
    // Validate SQLite before building the home screen. AppSettings.load()
    // intentionally uses defaults on failure, but that alone is not enough:
    // Home and SyncService also need a functional database.
    await DatabaseHelper.instance.database;
    await AppSettings.instance.load();
    await loadStrings();
    await SyncService.instance.init();
  }

  void _retry() {
    setState(() {
      _startup = _initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _startup,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _startupScreen(error: snapshot.error);
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return _startupScreen();
        }
        return _app();
      },
    );
  }

  Widget _startupScreen({Object? error}) {
    final failed = error != null;
    return MaterialApp(
      title: 'Sysyphus Learning App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Arial', useMaterial3: true),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (!failed) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 24),
                      const Text('Carregando Sysyphus Learning App...'),
                    ] else ...[
                      const Icon(Icons.error_outline, size: 52),
                      const SizedBox(height: 16),
                      const Text(
                        'Não foi possível iniciar o aplicativo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        kIsWeb
                            ? 'O banco de dados do navegador não iniciou. '
                              'Na pasta do projeto, execute o comando abaixo '
                              'para gerar web/sqflite_sw.js e web/sqlite3.wasm:'
                            : 'Falha ao preparar os dados do aplicativo.',
                        textAlign: TextAlign.center,
                      ),
                      if (kIsWeb) ...[
                        const SizedBox(height: 12),
                        const SelectableText(
                          'dart run sqflite_common_ffi_web:setup',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SelectableText(
                        'Detalhes: $error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _retry,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _app() {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final settings = AppSettings.instance;
        return MaterialApp(
          title: 'Study App',
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(settings, Brightness.light),
          darkTheme: AppTheme.build(settings, Brightness.dark),
          themeMode: settings.themeMode,
          supportedLocales: kSupportedLocales,
          locale: appLocale(),
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
