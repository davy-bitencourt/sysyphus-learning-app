import 'dart:typed_data';

import '../database_helper.dart';
import '../services/web_media_store.dart';

Future<WebMediaStore> _store() async =>
    WebMediaStore(await DatabaseHelper.instance.database);

Future<String> saveMediaBytes(
  List<int> bytes,
  String extension, {
  required bool isImage,
}) async => (await _store()).save(bytes, extension);

Future<Uint8List?> readMediaBytes(String path) async =>
    (await _store()).read(path);

Future<void> deleteMedia(String path) async => (await _store()).delete(path);
