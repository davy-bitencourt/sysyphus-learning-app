import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Copia arquivos escolhidos (imagem/áudio) para dentro do diretório de
/// documentos do app. O picker geralmente devolve um arquivo em cache
/// temporário, que o sistema operacional pode limpar a qualquer momento --
/// por isso persistimos uma cópia própria e guardamos esse caminho no banco.
class MediaStorageService {
  static Future<String?> pickImage({required bool fromCamera}) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return null;
    return _persist(File(picked.path), 'images');
  }

  static Future<String?> pickAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    final path = result?.files.single.path;
    if (path == null) return null;
    return _persist(File(path), 'audio');
  }

  static Future<String> _persist(File source, String subfolder) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(docsDir.path, 'sysyphus_media', subfolder));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final fileName = '${DateTime.now().microsecondsSinceEpoch}${p.extension(source.path)}';
    final targetPath = p.join(targetDir.path, fileName);
    await source.copy(targetPath);
    return targetPath;
  }

  /// Remove um arquivo persistido (ex: quando o campo é limpo/trocado).
  static Future<void> delete(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
