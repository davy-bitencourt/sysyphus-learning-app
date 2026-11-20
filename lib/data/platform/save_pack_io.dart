import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<bool> savePack(Uint8List bytes, String name) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Salvar exportação',
    fileName: name,
    type: FileType.custom,
    allowedExtensions: const ['zip'],
    bytes: Platform.isAndroid || Platform.isIOS ? bytes : null,
  );
  if (path == null) return false;
  if (!Platform.isAndroid && !Platform.isIOS) {
    await File(path).writeAsBytes(bytes);
  }
  return true;
}
