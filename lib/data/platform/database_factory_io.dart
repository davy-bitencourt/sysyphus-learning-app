import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void configureDatabaseFactory() {
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
