import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

bool _initialized = false;

void initializeDatabase() {
  if (_initialized) return;
  databaseFactory = databaseFactoryFfiWeb;
  _initialized = true;
}

Future<String> databasePath(String name) async => name;
