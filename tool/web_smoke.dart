import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';
import 'package:Sysyphus/data/database_helper.dart';
import 'package:Sysyphus/data/platform/database_setup.dart';
import 'package:Sysyphus/data/services/media_storage_service.dart';
import 'package:Sysyphus/data/services/web_media_store.dart';
import 'package:Sysyphus/data/transfer/pack_exporter.dart';
import 'package:Sysyphus/data/transfer/pack_importer.dart';
import 'package:Sysyphus/data/transfer/pack_parser.dart';
import 'package:Sysyphus/main.dart' as app;

/// Run with: flutter run -d chrome -t tool/web_smoke.dart --web-port=7357
/// Uses a separate database and then launches the normal app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDatabase();
  const name = 'sysyphus_web_smoke.db';
  var db = await databaseFactory.openDatabase(name);
  String? ref;
  try {
    ref = await WebMediaStore(db).save([0, 1, 127, 255], '.png');
    await db.close();
    db = await databaseFactory.openDatabase(name);
    final bytes = await WebMediaStore(db).read(ref);
    if (bytes == null || bytes.join(',') != '0,1,127,255') {
      throw StateError('Browser media did not survive database reopening.');
    }
    await WebMediaStore(db).delete(ref);
    if (await WebMediaStore(db).read(ref) != null) {
      throw StateError('Browser media deletion failed.');
    }
    debugPrint(
      'WEB_STORAGE_SMOKE_OK: SQLite/Wasm BLOB persistence and deletion',
    );
  } finally {
    if (ref != null && db.isOpen) await WebMediaStore(db).delete(ref);
    await db.close();
  }
  await _checkPackRoundTrip();
  await app.main();
  await WidgetsBinding.instance.endOfFrame;
  debugPrint('WEB_APP_FRAME_OK: application rendered its first frame');
}

Future<void> _checkPackRoundTrip() async {
  final db = await DatabaseHelper.instance.database;
  final name = '__web_smoke_${DateTime.now().microsecondsSinceEpoch}';
  final image = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aS1cAAAAASUVORK5CYII=',
  );
  int? templateId;
  int? packageId;
  final mediaRefs = <String>[];
  try {
    templateId = await db.insert('templates', {
      'template': jsonEncode({
        'name': name,
        'fields': [
          {
            'id': 'statement',
            'type': 'text',
            'label': 'Enunciado',
            'section': 'question',
          },
          {
            'id': 'field_img',
            'type': 'image',
            'label': 'Imagem',
            'section': 'question',
          },
          {
            'id': 'field_ans',
            'type': 'text',
            'label': 'Resposta',
            'section': 'answer',
          },
        ],
      }),
    });
    packageId = await db.insert('package', {'title': name});
    final ref = await MediaStorageService.saveBytes(
      image,
      '.png',
      isImage: true,
    );
    mediaRefs.add(ref);
    await db.insert('question', {
      'package_id': packageId,
      'template_id': templateId,
      'questions': jsonEncode({
        'statement': 'Browser smoke question',
        'field_img': ref,
        'field_ans': 'Browser smoke answer',
      }),
    });
    final exported = await buildExport(packageIds: {packageId});
    final files = unzipPack(exported.bytes);
    final parsed = parsePack(files);
    if (parsed.hasErrors ||
        parsed.questionCount != 1 ||
        exported.mediaFiles != 1) {
      throw StateError('ZIP export could not be parsed: ${parsed.issues}');
    }
    await db.delete(
      'question',
      where: 'package_id = ?',
      whereArgs: [packageId],
    );
    final plan = await buildImportPlan(parsed);
    final imported = await commitImport(plan, files);
    final rows = await db.query(
      'question',
      where: 'package_id = ?',
      whereArgs: [packageId],
    );
    if (imported.questionsAdded != 1 || rows.length != 1) {
      throw StateError('ZIP import did not restore the question.');
    }
    final values = jsonDecode(rows.single['questions'] as String) as Map;
    final restoredRef = values['field_img'] as String;
    mediaRefs.add(restoredRef);
    final restoredImage = await MediaStorageService.readBytes(restoredRef);
    if (restoredImage == null ||
        base64Encode(restoredImage) != base64Encode(image)) {
      throw StateError('ZIP round trip did not preserve image bytes.');
    }
    debugPrint('WEB_PACK_SMOKE_OK: question and image ZIP export/import');
  } finally {
    if (packageId != null) {
      await db.delete(
        'question',
        where: 'package_id = ?',
        whereArgs: [packageId],
      );
      await db.delete('package', where: 'id = ?', whereArgs: [packageId]);
    }
    if (templateId != null) {
      await db.delete('templates', where: 'id = ?', whereArgs: [templateId]);
    }
    for (final ref in mediaRefs) {
      await MediaStorageService.delete(ref);
    }
  }
}
