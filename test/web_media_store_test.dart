import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:Sysyphus/data/services/web_media_store.dart';

void main() {
  sqfliteFfiInit();

  test('media bytes survive closing and reopening the database', () async {
    final dir = await Directory.systemTemp.createTemp('sysyphus_media_test_');
    final path = '${dir.path}/media.db';
    var db = await databaseFactoryFfi.openDatabase(path);
    try {
      final ref = await WebMediaStore(db).save([0, 1, 127, 255], '.png');
      expect(ref.endsWith('.png'), isTrue);
      await db.close();
      db = await databaseFactoryFfi.openDatabase(path);
      expect(await WebMediaStore(db).read(ref), [0, 1, 127, 255]);
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });

  test(
    'deleting one attachment preserves another with identical bytes',
    () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      try {
        final store = WebMediaStore(db);
        final first = await store.save([1, 2, 3], '.wav');
        final second = await store.save([1, 2, 3], '.wav');
        expect(first, isNot(second));
        await store.delete(first);
        expect(await store.read(first), isNull);
        expect(await store.read(second), [1, 2, 3]);
        expect(await store.read('missing.png'), isNull);
      } finally {
        await db.close();
      }
    },
  );
}
