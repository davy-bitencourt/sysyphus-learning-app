// Coloque em test/sync_engine_test.dart e rode: flutter test test/sync_engine_test.dart
//
// Mesmos cenários que foram validados no motor de referência, agora contra o
// código Dart: dois "aparelhos" (bancos SQLite em memória) e um servidor falso.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:Sysyphus/data/sync/sync_engine.dart';
import 'package:Sysyphus/data/sync/sync_memory_transport.dart';
import 'package:Sysyphus/data/sync/sync_models.dart';
import 'package:Sysyphus/data/sync/sync_schema.dart';

const List<String> _baseSchema = [
  'CREATE TABLE account (id INTEGER PRIMARY KEY AUTOINCREMENT, email TEXT UNIQUE, senha TEXT)',
  'CREATE TABLE session (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, time_limit TEXT, total_q INTEGER, tag_filters TEXT)',
  'CREATE TABLE templates (id INTEGER PRIMARY KEY AUTOINCREMENT, template JSON)',
  'CREATE TABLE tag (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT)',
  'CREATE TABLE package (id INTEGER PRIMARY KEY AUTOINCREMENT, session_id INTEGER, title TEXT, '
      'FOREIGN KEY (session_id) REFERENCES session(id))',
  'CREATE TABLE question (id INTEGER PRIMARY KEY AUTOINCREMENT, package_id INTEGER, tag_id INTEGER, '
      'template_id INTEGER, enunciado TEXT, questions JSON, extra JSON, description TEXT, '
      'FOREIGN KEY (package_id) REFERENCES package(id), FOREIGN KEY (tag_id) REFERENCES tag(id), '
      'FOREIGN KEY (template_id) REFERENCES templates(id))',
  'CREATE TABLE revlog (id INTEGER PRIMARY KEY AUTOINCREMENT, question_id INTEGER NOT NULL, data TEXT, time TEXT)',
  "CREATE TABLE state (question_id INTEGER PRIMARY KEY, state TEXT DEFAULT 'new', interval_days INTEGER DEFAULT 0, "
      "ease_factor REAL DEFAULT 2.4, due_date TEXT DEFAULT CURRENT_DATE, "
      "FOREIGN KEY (question_id) REFERENCES question(id) ON DELETE CASCADE)",
];

String _templateJson(String name) => jsonEncode({
      'name': name,
      'fields': [
        {'id': 'statement', 'type': 'text', 'label': 'Enunciado', 'section': 'question', 'optionCount': 4},
        {'id': 'field_img', 'type': 'image', 'label': 'Imagem', 'section': 'question', 'optionCount': 4},
        {'id': 'field_ans', 'type': 'text', 'label': 'Resposta', 'section': 'answer', 'optionCount': 4},
      ],
    });

Future<Database> _openRaw() async {
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      singleInstance: false, // cada "aparelho" tem o seu banco
      onConfigure: (d) async => d.execute('PRAGMA foreign_keys = ON'),
    ),
  );
  for (final s in _baseSchema) {
    await db.execute(s);
  }
  return db;
}

int _fileCounter = 0;

class _Device {
  _Device(this.name, this.db, this.mediaDir);
  final String name;
  final Database db;
  final Directory mediaDir;

  static Future<_Device> create(String name, Directory root) async {
    final db = await _openRaw();
    await applySyncSchema(db);
    final dir = Directory('${root.path}/$name')..createSync(recursive: true);
    return _Device(name, db, dir);
  }

  SyncEngine engine(SyncTransport transport) => SyncEngine(
        db: db,
        transport: transport,
        saveMedia: (bytes, ext, isImage) async {
          final f = File('${mediaDir.path}/${_fileCounter++}$ext');
          await f.writeAsBytes(bytes);
          return f.path;
        },
      );

  Future<void> sync(SyncTransport t) => engine(t).sync();
}

Future<int> _count(Database db, String table) async =>
    Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $table'))!;

Future<int> _addQuestion(Database db, int pkg, int tpl, int? tag, Map<String, Object?> vals) async {
  final id = await db.rawInsert(
    'INSERT INTO question (package_id, tag_id, template_id, questions) VALUES (?, ?, ?, ?)',
    [pkg, tag, tpl, jsonEncode(vals)],
  );
  await db.rawInsert('INSERT INTO state (question_id) VALUES (?)', [id]); // como o QuestionDao.insert
  return id;
}

/// Fixa o updated_at (e o da fila) para os testes de conflito serem determinísticos.
Future<void> _forceTs(Database db, String table, String where, List<Object?> args, int ts) async {
  await db.rawUpdate("UPDATE sync_meta SET value = '1' WHERE key = 'applying'");
  await db.rawUpdate('UPDATE $table SET updated_at = ? WHERE $where', [ts, ...args]);
  await db.rawUpdate("UPDATE sync_meta SET value = '0' WHERE key = 'applying'");
  final u = (await db.rawQuery('SELECT uuid FROM $table WHERE $where', args)).first['uuid'];
  await db.rawUpdate('UPDATE sync_log SET ts = ? WHERE entity = ? AND uuid = ?', [ts, table, u]);
}

Future<void> _editFirstQuestion(Database db, String text, int ts) async {
  final row = (await db.rawQuery('SELECT id, questions FROM question')).first;
  final vals = jsonDecode(row['questions'] as String) as Map<String, dynamic>;
  vals['statement'] = text;
  await db.rawUpdate('UPDATE question SET questions = ? WHERE id = ?', [jsonEncode(vals), row['id']]);
  await _forceTs(db, 'question', 'id = ?', [row['id']], ts);
}

Future<String> _statement(Database db, String uuid) async {
  final row = (await db.rawQuery('SELECT questions FROM question WHERE uuid = ?', [uuid])).first;
  return (jsonDecode(row['questions'] as String) as Map<String, dynamic>)['statement'] as String;
}

class _Pair {
  _Pair(this.server, this.a, this.b);
  final MemorySyncTransport server;
  final _Device a;
  final _Device b;
}

/// A cria pacote + questão, liga a sincronização nos dois e sincroniza A e depois B.
Future<_Pair> _seedPair(Directory root) async {
  final server = MemorySyncTransport();
  final a = await _Device.create('A', root);
  final b = await _Device.create('B', root);
  final tpl = await a.db.rawInsert('INSERT INTO templates (template) VALUES (?)', [_templateJson('T')]);
  final pkg = await a.db.rawInsert("INSERT INTO package (title) VALUES ('Direito')");
  await _addQuestion(a.db, pkg, tpl, null, {'statement': 'original', 'field_img': null, 'field_ans': ''});
  await syncEnable(a.db);
  await a.sync(server);
  await syncEnable(b.db);
  await b.sync(server);
  return _Pair(server, a, b);
}

void main() {
  sqfliteFfiInit();
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('sync_test_'));
  tearDown(() => root.deleteSync(recursive: true));

  test('a migração dá uuid e updated_at às linhas que já existiam (e pode rodar de novo)', () async {
    final db = await _openRaw();
    await db.rawInsert("INSERT INTO tag (title) VALUES ('historia')");
    await db.rawInsert("INSERT INTO package (title) VALUES ('Japonês')");

    await applySyncSchema(db);
    await applySyncSchema(db);

    for (final t in kSyncUuidTables.where((t) => t == 'tag' || t == 'package')) {
      final row = (await db.rawQuery('SELECT uuid, updated_at FROM $t')).first;
      expect((row['uuid'] as String).length, 32);
      expect((row['updated_at'] as int) > 1700000000000, isTrue);
    }
    expect(await _count(db, 'sync_log'), 0); // sync desligado: nada é registrado
  });

  test('o conteúdo de A chega em B com ids locais diferentes, FKs e mídia traduzidos', () async {
    final server = MemorySyncTransport();
    final a = await _Device.create('A', root);
    final b = await _Device.create('B', root);

    // desloca os ids de A para provar que nada depende de ids iguais
    final dummy = await a.db.rawInsert("INSERT INTO tag (title) VALUES ('lixo')");
    await a.db.rawDelete('DELETE FROM tag WHERE id = ?', [dummy]);

    final img = File('${a.mediaDir.path}/foto.png')..writeAsBytesSync([1, 2, 3, 4]);
    final tag = await a.db.rawInsert("INSERT INTO tag (title) VALUES ('historia')");
    final tpl = await a.db.rawInsert('INSERT INTO templates (template) VALUES (?)', [_templateJson('Aberta com imagem')]);
    final session = await a.db.rawInsert(
      'INSERT INTO session (title, time_limit, total_q, tag_filters) VALUES (?, ?, ?, ?)',
      ['Prova', '1800s', 20, jsonEncode([{'tag_id': tag, 'quantity': 3}])],
    );
    final pkg = await a.db.rawInsert('INSERT INTO package (session_id, title) VALUES (?, ?)', [session, 'Japonês']);
    final q1 = await _addQuestion(a.db, pkg, tpl, tag, {'statement': 'Que cor?', 'field_img': img.path, 'field_ans': 'vermelho'});
    await a.db.rawInsert("INSERT INTO revlog (question_id, data, time) VALUES (?, '2026-10-01', '10:00')", [q1]);
    await a.db.rawUpdate("UPDATE state SET state = 'review', interval_days = 4 WHERE question_id = ?", [q1]);

    await syncEnable(a.db);
    await a.sync(server);
    await syncEnable(b.db);
    await b.sync(server);

    for (final t in ['tag', 'templates', 'session', 'package', 'question', 'state', 'revlog']) {
      expect(await _count(b.db, t), 1, reason: t);
    }
    final bTag = (await b.db.rawQuery('SELECT id FROM tag')).first['id'] as int;
    expect(bTag, isNot(tag)); // ids diferentes entre os aparelhos

    final filters = jsonDecode((await b.db.rawQuery('SELECT tag_filters FROM session')).first['tag_filters'] as String);
    expect(filters, [{'tag_id': bTag, 'quantity': 3}]);

    final q = (await b.db.rawQuery('SELECT * FROM question')).first;
    expect(q['package_id'], (await b.db.rawQuery('SELECT id FROM package')).first['id']);
    expect(q['template_id'], (await b.db.rawQuery('SELECT id FROM templates')).first['id']);
    expect(q['tag_id'], bTag);

    final path = (jsonDecode(q['questions'] as String) as Map<String, dynamic>)['field_img'] as String;
    expect(path.startsWith(b.mediaDir.path), isTrue);
    expect(File(path).readAsBytesSync(), [1, 2, 3, 4]);
    expect(server.blobUploads, 1);

    final st = (await b.db.rawQuery('SELECT state, interval_days FROM state')).first;
    expect([st['state'], st['interval_days']], ['review', 4]);
    expect((await b.db.rawQuery('SELECT question_id FROM revlog')).first['question_id'], q['id']);
  });

  test('sincronizar de novo sem mudar nada não reenvia nada', () async {
    final p = await _seedPair(root);
    final seq = p.server.seq;
    final ra = await p.a.engine(p.server).sync();
    final rb = await p.b.engine(p.server).sync();
    expect(ra.pushed, 0);
    expect(rb.pushed, 0);
    expect(p.server.seq, seq);
    expect(await _count(p.a.db, 'sync_log'), 0);
    expect(await _count(p.b.db, 'sync_log'), 0);
  });

  test('conflito: vale a edição mais recente, em qualquer ordem de sincronização', () async {
    final p = await _seedPair(root);
    final uq = (await p.a.db.rawQuery('SELECT uuid FROM question')).first['uuid'] as String;
    final t = DateTime.now().millisecondsSinceEpoch + 100000;

    await _editFirstQuestion(p.a.db, 'versao A', t + 1000);
    await _editFirstQuestion(p.b.db, 'versao B', t + 2000);
    await p.a.sync(p.server);
    await p.b.sync(p.server);
    await p.a.sync(p.server);
    expect(await _statement(p.a.db, uq), 'versao B');
    expect(await _statement(p.b.db, uq), 'versao B');

    await _editFirstQuestion(p.a.db, 'A final', t + 5000);
    await _editFirstQuestion(p.b.db, 'B antes', t + 4000);
    await p.b.sync(p.server);
    await p.a.sync(p.server);
    await p.b.sync(p.server);
    expect(await _statement(p.a.db, uq), 'A final');
    expect(await _statement(p.b.db, uq), 'A final');
  });

  test('apagar uma questão propaga, e o histórico de revisões é mantido', () async {
    final p = await _seedPair(root);
    final qid = (await p.a.db.rawQuery('SELECT id FROM question')).first['id'] as int;
    await p.a.db.rawInsert("INSERT INTO revlog (question_id, data, time) VALUES (?, '2026-10-02', '09:00')", [qid]);
    await p.a.sync(p.server);
    await p.b.sync(p.server);
    expect(await _count(p.b.db, 'revlog'), 1);

    // igual ao QuestionDao.delete
    await p.a.db.rawDelete('DELETE FROM state WHERE question_id = ?', [qid]);
    await p.a.db.rawDelete('DELETE FROM question WHERE id = ?', [qid]);
    await p.a.sync(p.server);
    await p.b.sync(p.server);

    expect(await _count(p.b.db, 'question'), 0);
    expect(await _count(p.b.db, 'state'), 0);
    expect(await _count(p.b.db, 'package'), 1);
    expect(await _count(p.b.db, 'revlog'), 1);
  });

  test('primeira ligação: tag e pacote de mesmo nome criados offline viram um só', () async {
    final server = MemorySyncTransport();
    final a = await _Device.create('A', root);
    final b = await _Device.create('B', root);

    for (final d in [a, b]) {
      final tag = await d.db.rawInsert("INSERT INTO tag (title) VALUES ('historia')");
      final tpl = await d.db.rawInsert('INSERT INTO templates (template) VALUES (?)', [_templateJson('T')]);
      final pkg = await d.db.rawInsert("INSERT INTO package (title) VALUES ('Japonês')");
      await _addQuestion(d.db, pkg, tpl, tag, {'statement': 'questao de ${d.name}', 'field_img': null, 'field_ans': ''});
      await syncEnable(d.db);
    }
    await a.sync(server);
    await b.sync(server);
    await a.sync(server);

    for (final d in [a, b]) {
      expect(await _count(d.db, 'tag'), 1, reason: '${d.name} tag');
      expect(await _count(d.db, 'package'), 1, reason: '${d.name} package');
      expect(await _count(d.db, 'question'), 2, reason: '${d.name} question');
      expect(await _count(d.db, 'templates'), 2, reason: 'templates não são fundidos');
    }
    final ua = (await a.db.rawQuery('SELECT uuid FROM package')).first['uuid'];
    final ub = (await b.db.rawQuery('SELECT uuid FROM package')).first['uuid'];
    expect(ua, ub);
  });
}
