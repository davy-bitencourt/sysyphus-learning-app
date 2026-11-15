import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<List<int>?> readBytes(String path) async {
  final file = File(path);
  return await file.exists() ? file.readAsBytes() : null;
}

Future<bool> exists(String path) => File(path).exists();

int _counter = 0;
Future<String> saveBytes(List<int> bytes, String extension, String subfolder) async {
  final docsDir = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docsDir.path, 'sysyphus_media', subfolder));
  if (!await dir.exists()) await dir.create(recursive: true);
  final name = '${DateTime.now().microsecondsSinceEpoch}_${_counter++}$extension';
  final path = p.join(dir.path, name);
  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}

Future<String> persistPicked(String sourcePath, String subfolder) async {
  final docsDir = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docsDir.path, 'sysyphus_media', subfolder));
  if (!await dir.exists()) await dir.create(recursive: true);
  final name = '${DateTime.now().microsecondsSinceEpoch}_${_counter++}${p.extension(sourcePath)}';
  final path = p.join(dir.path, name);
  await File(sourcePath).copy(path);
  return path;
}

Future<void> delete(String path) async {
  final file = File(path);
  if (await file.exists()) await file.delete();
}

Future<void> writeBytes(String path, List<int> bytes) async {
  await File(path).writeAsBytes(bytes);
}
