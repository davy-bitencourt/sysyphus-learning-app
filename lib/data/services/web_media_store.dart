import 'dart:math';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

/// Media bytes live in the same persistent browser database as the questions.
/// References keep their extension so ZIP import/export preserves the format.
class WebMediaStore {
  WebMediaStore(this.db);

  final Database db;
  static int _counter = 0;
  static final _random = Random.secure();

  Future<void> _ensureTable() => db.execute('''
    CREATE TABLE IF NOT EXISTS web_media (
      ref TEXT PRIMARY KEY,
      bytes BLOB NOT NULL
    )
  ''');

  Future<String> save(List<int> bytes, String extension) async {
    await _ensureTable();
    final id =
        '${DateTime.now().microsecondsSinceEpoch}_${_counter++}_'
        '${_random.nextInt(0x100000000).toRadixString(16)}';
    final ref = 'sysyphus-media:$id$extension';
    await db.insert('web_media', {
      'ref': ref,
      'bytes': Uint8List.fromList(bytes),
    });
    return ref;
  }

  Future<Uint8List?> read(String ref) async {
    await _ensureTable();
    final rows = await db.query(
      'web_media',
      columns: ['bytes'],
      where: 'ref = ?',
      whereArgs: [ref],
    );
    if (rows.isEmpty) return null;
    return Uint8List.fromList((rows.single['bytes'] as List).cast<int>());
  }

  Future<void> delete(String ref) async {
    await _ensureTable();
    await db.delete('web_media', where: 'ref = ?', whereArgs: [ref]);
  }
}
