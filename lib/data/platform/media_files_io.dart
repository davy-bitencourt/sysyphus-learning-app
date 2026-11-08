import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

int _counter = 0;

Future<String> saveMediaBytes(
  List<int> bytes,
  String extension, {
  required bool isImage,
}) async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(
    p.join(docs.path, 'sysyphus_media', isImage ? 'images' : 'audio'),
  );
  await dir.create(recursive: true);
  final name =
      '${DateTime.now().microsecondsSinceEpoch}_${_counter++}$extension';
  final file = File(p.join(dir.path, name));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<Uint8List?> readMediaBytes(String path) async {
  final file = File(path);
  return await file.exists() ? file.readAsBytes() : null;
}

Future<void> deleteMedia(String path) async {
  final file = File(path);
  if (await file.exists()) await file.delete();
}
