import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../platform/media_files.dart' as storage;

/// Stores native files on disk and browser media in the app's SQLite database.
class MediaStorageService {
  static Future<String?> pickImage({required bool fromCamera}) async {
    final picked = await ImagePicker().pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return null;
    return saveBytes(
      await picked.readAsBytes(),
      p.extension(picked.name),
      isImage: true,
    );
  }

  static Future<String?> pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true,
    );
    if (result == null) return null;
    final picked = result.files.single;
    final bytes = picked.bytes;
    if (bytes == null) throw StateError('Não foi possível ler o áudio.');
    return saveBytes(bytes, p.extension(picked.name), isImage: false);
  }

  static Future<String> saveBytes(
    List<int> bytes,
    String extension, {
    required bool isImage,
  }) => storage.saveMediaBytes(bytes, extension, isImage: isImage);

  static Future<Uint8List?> readBytes(String path) =>
      storage.readMediaBytes(path);

  static String? audioMimeType(String path) => const {
    '.mp3': 'audio/mpeg',
    '.m4a': 'audio/mp4',
    '.wav': 'audio/wav',
    '.ogg': 'audio/ogg',
    '.aac': 'audio/aac',
  }[p.extension(path).toLowerCase()];

  static Future<void> delete(String? path) async {
    if (path != null) await storage.deleteMedia(path);
  }
}
