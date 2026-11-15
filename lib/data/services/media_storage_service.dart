import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../database_helper.dart';
import '../platform/local_file_io.dart'
    if (dart.library.js_interop) '../platform/local_file_web.dart' as local_files;

/// Stores media in ordinary files on mobile/desktop, and in the existing
/// SQLite database's IndexedDB-backed storage on the web.
/// Web paths are opaque tokens; they are never passed to File() or Image.file().
class MediaStorageService {
  static const _prefix = 'sysyphus-web-media:';
  static int _counter = 0;

  static Future<String?> pickImage({required bool fromCamera}) async {
    final picked = await ImagePicker().pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return null;
    if (kIsWeb) {
      return saveBytes(await picked.readAsBytes(), p.extension(picked.name), isImage: true);
    }
    return local_files.persistPicked(picked.path, 'images');
  }

  static Future<String?> pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes == null) throw StateError('O navegador não forneceu o áudio selecionado.');
      return saveBytes(bytes, p.extension(file.name), isImage: false);
    }
    final source = file.path;
    if (source == null) return null;
    return local_files.persistPicked(source, 'audio');
  }

  static Future<void> _ensureWebTable(Database db) => db.execute(
    'CREATE TABLE IF NOT EXISTS web_media (path TEXT PRIMARY KEY, bytes BLOB NOT NULL)',
  );

  static Future<String> saveBytes(
    List<int> bytes,
    String extension, {
    required bool isImage,
  }) async {
    if (!kIsWeb) {
      return local_files.saveBytes(bytes, extension, isImage ? 'images' : 'audio');
    }
    final token = '$_prefix${DateTime.now().microsecondsSinceEpoch}_${_counter++}$extension';
    final db = await DatabaseHelper.instance.database;
    await _ensureWebTable(db);
    await db.insert('web_media', {
      'path': token,
      'bytes': Uint8List.fromList(bytes),
    });
    return token;
  }

  static Future<List<int>?> readBytes(String? path) async {
    if (path == null || path.isEmpty) return null;
    if (!path.startsWith(_prefix)) return local_files.readBytes(path);
    if (!kIsWeb) return null;
    final db = await DatabaseHelper.instance.database;
    await _ensureWebTable(db);
    final rows = await db.query('web_media', columns: ['bytes'], where: 'path = ?', whereArgs: [path]);
    if (rows.isEmpty) return null;
    final bytes = rows.first['bytes'];
    return bytes is List<int> ? bytes : null;
  }

  static Future<bool> exists(String path) async {
    if (!path.startsWith(_prefix)) return local_files.exists(path);
    if (!kIsWeb) return false;
    final db = await DatabaseHelper.instance.database;
    await _ensureWebTable(db);
    return (await db.query('web_media', columns: ['path'], where: 'path = ?', whereArgs: [path], limit: 1)).isNotEmpty;
  }

  static Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    if (!path.startsWith(_prefix)) return local_files.delete(path);
    if (!kIsWeb) return;
    final db = await DatabaseHelper.instance.database;
    await _ensureWebTable(db);
    await db.delete('web_media', where: 'path = ?', whereArgs: [path]);
  }
}
