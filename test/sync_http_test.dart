// Coloque em test/sync_http_test.dart e rode: flutter test test/sync_http_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../lib/data/sync/sync_auth.dart';
import '../lib/data/sync/sync_engine.dart';
import '../lib/data/sync/sync_http_server.dart';
import '../lib/data/sync/sync_http_transport.dart';
import '../lib/data/sync/sync_memory_transport.dart';
import '../lib/data/sync/sync_models.dart';
import '../lib/data/sync/sync_schema.dart';

const String _id = 'K7QF2-MZP9X-HD4TR-AWB3E-6YNCLH';

SyncChange _change(String uuid, int ts, String title) => SyncChange(
      entity: 'tag', uuid: uuid, op: 'upsert', ts: ts, data: {'title': title}, device: 'x');

void main() {
  sqfliteFfiInit();

  test('ID gerado é válido e a normalização aceita minúsculas, espaços e traços', () {
    final id = generateAccountId();
    expect(isValidAccountId(id), isTrue);
    expect(normalizeAccountId(id).length, 26);
    expect(RegExp(r'^[A-Z2-9]{5}-[A-Z2-9]{5}-[A-Z2-9]{5}-[A-Z2-9]{5}-[A-Z2-9]{6}$').hasMatch(id), isTrue);
    expect(normalizeAccountId('k7qf2-mzp9x hd4tr_awb3e-6ynclh'), normalizeAccountId(_id));
    expect(isValidAccountId('curto'), isFalse);
    expect(isValidAccountId('0000000000000000000000000O'), isFalse); // 0 e O não existem no alfabeto
  });

  test('assinatura e dica de descoberta batem com os valores calculados em outra implementação (Python)', () {
    expect(
      signRequest(_id, 'POST', '/v1/pull', 1700000000000, utf8.encode('{"since":0}')),
      'a178ee8ac9c6415ce1c2e2d02d335b1ccf1cbb12ac6e223579cf32c86486db7a',
    );
    // expect(discoveryHint(_id), 'c85b8a66025dc607');
    expect(constantTimeEquals('abc', 'abc'), isTrue);
    expect(constantTimeEquals('abc', 'abd'), isFalse);
  });

  group('servidor HTTP local', () {
    late MemorySyncTransport store;
    late SyncHttpServer server;
    late HttpSyncTransport client;

    setUp(() async {
      store = MemorySyncTransport();
      server = SyncHttpServer(transport: store, accountId: _id, port: 0, enableDiscovery: false);
      await server.start();
      client = HttpSyncTransport(host: '127.0.0.1', port: server.boundPort, accountId: _id);
    });

    tearDown(() async {
      client.close();
      await server.stop();
    });

    test('ID certo conecta; ID errado é recusado', () async {
      await client.ping();
      final wrong = HttpSyncTransport(host: '127.0.0.1', port: server.boundPort, accountId: 'AAAAA-BBBBB-CCCCC-DDDDD-EEEEEE');
      await expectLater(wrong.ping(), throwsA(isA<SyncAuthException>()));
      wrong.close();
    });

    test('push e pull passam pelo HTTP e respeitam o registro mais recente', () async {
      await client.push('dev1', [_change('u1', 100, 'velha')]);
      await client.push('dev2', [_change('u1', 200, 'nova'), _change('u2', 50, 'outra')]);
      await client.push('dev1', [_change('u1', 150, 'ignorada')]); // mais antiga que a do servidor

      final r = await client.pull(0);
      final byUuid = {for (final c in r.changes) c.uuid: c};
      expect(byUuid['u1']!.data!['title'], 'nova');
      expect(byUuid.length, 2);
      expect((await client.pull(r.latestSeq)).changes, isEmpty);
    });

    test('mídia por hash: envia, consulta e baixa; hash errado é recusado', () async {
      final bytes = utf8.encode('conteudo da imagem');
      final hash = sha256Hex(bytes);
      expect(await client.hasBlob(hash), isFalse);
      await client.putBlob(hash, bytes);
      expect(await client.hasBlob(hash), isTrue);
      expect(await client.getBlob(hash), bytes);
      await expectLater(client.putBlob('0' * 64, bytes), throwsA(isA<HttpException>()));
    });
  });

  test('dois aparelhos sincronizam pelo HTTP (conteúdo + imagem)', () async {
    final store = MemorySyncTransport();
    final server = SyncHttpServer(transport: store, accountId: _id, port: 0, enableDiscovery: false);
    await server.start();
    final root = Directory.systemTemp.createTempSync('sync_http_');
    try {
      HttpSyncTransport conn() => HttpSyncTransport(host: '127.0.0.1', port: server.boundPort, accountId: _id);
      final a = await _openDevice('A', root);
      final b = await _openDevice('B', root);

      final img = File('${root.path}/A/foto.png')..writeAsBytesSync([9, 8, 7]);
      final tpl = await a.rawInsert('INSERT INTO templates (template) VALUES (?)', [_tpl]);
      final pkg = await a.rawInsert("INSERT INTO package (title) VALUES ('Japonês')");
      final q = await a.rawInsert(
        'INSERT INTO question (package_id, template_id, questions) VALUES (?, ?, ?)',
        [pkg, tpl, jsonEncode({'statement': 'Que cor?', 'field_img': img.path})],
      );
      await a.rawInsert('INSERT INTO state (question_id) VALUES (?)', [q]);

      await syncEnable(a);
      await syncEnable(b);
      var n = 0;
      SyncEngine engine(dynamic db, String name) => SyncEngine(
            db: db,
            transport: conn(),
            saveMedia: (bytes, ext, isImage) async {
              final f = File('${root.path}/$name/${n++}$ext');
              await f.writeAsBytes(bytes);
              return f.path;
            },
          );
      await engine(a, 'A').sync();
      await engine(b, 'B').sync();

      final row = (await b.rawQuery('SELECT questions FROM question')).first;
      final path = (jsonDecode(row['questions'] as String) as Map<String, dynamic>)['field_img'] as String;
      expect(path.startsWith('${root.path}/B'), isTrue);
      expect(File(path).readAsBytesSync(), [9, 8, 7]);
      expect((await b.rawQuery('SELECT title FROM package')).first['title'], 'Japonês');
    } finally {
      await server.stop();
      root.deleteSync(recursive: true);
    }
  });
}

String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

const String _tpl = '{"name":"T","fields":[{"id":"statement","type":"text","label":"Enunciado","section":"question","optionCount":4},'
    '{"id":"field_img","type":"image","label":"Imagem","section":"question","optionCount":4}]}';

const List<String> _schema = [
  'CREATE TABLE session (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, time_limit TEXT, total_q INTEGER, tag_filters TEXT)',
  'CREATE TABLE templates (id INTEGER PRIMARY KEY AUTOINCREMENT, template JSON)',
  'CREATE TABLE tag (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT)',
  'CREATE TABLE package (id INTEGER PRIMARY KEY AUTOINCREMENT, session_id INTEGER, title TEXT)',
  'CREATE TABLE question (id INTEGER PRIMARY KEY AUTOINCREMENT, package_id INTEGER, tag_id INTEGER, template_id INTEGER, '
      'enunciado TEXT, questions JSON, extra JSON, description TEXT)',
  'CREATE TABLE revlog (id INTEGER PRIMARY KEY AUTOINCREMENT, question_id INTEGER NOT NULL, data TEXT, time TEXT)',
  "CREATE TABLE state (question_id INTEGER PRIMARY KEY, state TEXT DEFAULT 'new', interval_days INTEGER DEFAULT 0, "
      "ease_factor REAL DEFAULT 2.4, due_date TEXT DEFAULT CURRENT_DATE)",
];

Future<Database> _openDevice(String name, Directory root) async {
  Directory('${root.path}/$name').createSync(recursive: true);
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(singleInstance: false),
  );
  for (final s in _schema) {
    await db.execute(s);
  }
  await applySyncSchema(db);
  return db;
}
