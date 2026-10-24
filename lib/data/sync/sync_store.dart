import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import 'sync_models.dart';

/// Cópia central dos registros (o lado "servidor"), guardada em tabelas
/// próprias do mesmo banco e em arquivos para a mídia. Mesma regra do
/// servidor em memória que foi testado: por entidade+uuid vale o registro de
/// maior `ts` (empate: o último a chegar).
class SqliteSyncStore implements SyncTransport {
  SqliteSyncStore({required this.db, required this.blobDir});

  final Database db;
  final Directory blobDir;

  static final RegExp _hashRe = RegExp(r'^[0-9a-f]{64}$');

  Future<void> open() async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS sync_srv_records ('
      'entity TEXT NOT NULL, uuid TEXT NOT NULL, op TEXT NOT NULL, ts INTEGER NOT NULL, '
      'data TEXT, device TEXT NOT NULL, seq INTEGER NOT NULL, PRIMARY KEY (entity, uuid))',
    );
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_srv_seq ON sync_srv_records (seq)');
    if (!await blobDir.exists()) await blobDir.create(recursive: true);
  }

  /// Apaga a cópia central (ao sair da conta ou criar uma nova).
  Future<void> wipe() async {
    await db.execute('CREATE TABLE IF NOT EXISTS sync_srv_records ('
        'entity TEXT NOT NULL, uuid TEXT NOT NULL, op TEXT NOT NULL, ts INTEGER NOT NULL, '
        'data TEXT, device TEXT NOT NULL, seq INTEGER NOT NULL, PRIMARY KEY (entity, uuid))');
    await db.rawDelete('DELETE FROM sync_srv_records');
    if (await blobDir.exists()) await blobDir.delete(recursive: true);
  }

  @override
  Future<PullResult> pull(int sinceSeq) async {
    final rows = await db.rawQuery(
      'SELECT entity, uuid, op, ts, data, device, seq FROM sync_srv_records WHERE seq > ? ORDER BY seq',
      [sinceSeq],
    );
    final latest = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COALESCE(MAX(seq), 0) FROM sync_srv_records'),
        ) ??
        0;
    return PullResult(
      changes: [
        for (final r in rows)
          SyncChange(
            entity: r['entity'] as String,
            uuid: r['uuid'] as String,
            op: r['op'] as String,
            ts: (r['ts'] as num).toInt(),
            data: r['data'] == null
                ? null
                : Map<String, dynamic>.from(jsonDecode(r['data'] as String) as Map),
            device: r['device'] as String,
          ),
      ],
      latestSeq: latest,
    );
  }

  @override
  Future<void> push(String deviceId, List<SyncChange> changes) async {
    await db.transaction((txn) async {
      var seq = Sqflite.firstIntValue(
            await txn.rawQuery('SELECT COALESCE(MAX(seq), 0) FROM sync_srv_records'),
          ) ??
          0;
      for (final c in changes) {
        if (!kSyncEntities.contains(c.entity)) continue;
        final cur = await txn.rawQuery(
          'SELECT ts FROM sync_srv_records WHERE entity = ? AND uuid = ?',
          [c.entity, c.uuid],
        );
        if (cur.isNotEmpty && (cur.first['ts'] as num).toInt() > c.ts) continue; // mais antigo: ignora
        seq++;
        await txn.rawInsert(
          'INSERT OR REPLACE INTO sync_srv_records (entity, uuid, op, ts, data, device, seq) '
          'VALUES (?, ?, ?, ?, ?, ?, ?)',
          [c.entity, c.uuid, c.op, c.ts, c.data == null ? null : jsonEncode(c.data), deviceId, seq],
        );
      }
    });
  }

  File? _blobFile(String hash) => _hashRe.hasMatch(hash) ? File('${blobDir.path}/$hash') : null;

  @override
  Future<bool> hasBlob(String hash) async {
    final f = _blobFile(hash);
    return f != null && await f.exists();
  }

  @override
  Future<void> putBlob(String hash, List<int> bytes) async {
    final f = _blobFile(hash);
    if (f == null) throw ArgumentError('hash inválido');
    if (sha256.convert(bytes).toString() != hash) {
      throw ArgumentError('o conteúdo não confere com o hash informado');
    }
    if (!await blobDir.exists()) await blobDir.create(recursive: true);
    await f.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<List<int>?> getBlob(String hash) async {
    final f = _blobFile(hash);
    return (f != null && await f.exists()) ? await f.readAsBytes() : null;
  }
}
