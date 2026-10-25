import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../transfer/pack_models.dart';
import 'sync_models.dart';
import 'sync_schema.dart';

const Set<String> _imageExts = {'.png', '.jpg', '.jpeg', '.webp', '.gif'};

int? _asInt(Object? v) => v is num ? v.toInt() : null;

Map<String, dynamic> _decodeMap(String? s) {
  try {
    final d = jsonDecode((s == null || s.isEmpty) ? '{}' : s);
    if (d is Map) return Map<String, dynamic>.from(d);
  } catch (_) {
    // JSON inválido: trata como vazio
  }
  return <String, dynamic>{};
}

List<dynamic> _decodeList(String? s) {
  try {
    final d = jsonDecode((s == null || s.isEmpty) ? '[]' : s);
    if (d is List) return d;
  } catch (_) {
    // JSON inválido: trata como vazio
  }
  return const <dynamic>[];
}

String _extOf(String path) {
  final i = path.lastIndexOf('.');
  return i >= 0 ? path.substring(i).toLowerCase() : '';
}

class _Pending {
  final String op;
  final int ts;
  const _Pending(this.op, this.ts);
}

Future<void> syncEnable(Database db) async {
  await db.transaction((txn) async {
    await setSyncMeta(txn, 'enabled', '1');
    await txn.rawDelete('DELETE FROM sync_log');
    for (final t in kSyncUuidTables) {
      await txn.rawInsert(
        "INSERT INTO sync_log (entity, uuid, op, ts) SELECT '$t', uuid, 'upsert', updated_at FROM $t",
      );
    }
    await txn.rawInsert(
      "INSERT INTO sync_log (entity, uuid, op, ts) "
      "SELECT 'state', q.uuid, 'upsert', s.updated_at FROM state s JOIN question q ON q.id = s.question_id",
    );
  });
}

Future<void> syncDisable(Database db) async {
  await db.transaction((txn) async {
    await setSyncMeta(txn, 'enabled', '0');
    await setSyncMeta(txn, 'cursor', '0');
    await txn.rawDelete('DELETE FROM sync_log');
  });
}

Future<SyncStatus> syncStatus(Database db) async {
  final pending = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM sync_log')) ?? 0;
  final last = int.tryParse(await getSyncMeta(db, 'last_sync'));
  return SyncStatus(
    enabled: (await getSyncMeta(db, 'enabled')) == '1',
    deviceId: await getSyncMeta(db, 'device_id'),
    pendingChanges: pending,
    lastSync: last == null ? null : DateTime.fromMillisecondsSinceEpoch(last),
  );
}

class SyncEngine {
  SyncEngine({
    required this.db,
    required this.transport,
    required this.saveMedia,
    Future<List<int>?> Function(String path)? readFile,
  }) : readFile = readFile ?? _defaultReadFile;

  final Database db;
  final SyncTransport transport;
  final Future<String> Function(List<int> bytes, String extension, bool isImage) saveMedia;
  final Future<List<int>?> Function(String path) readFile;

  bool _running = false;

  static Future<List<int>?> _defaultReadFile(String path) async {
    final f = File(path);
    return await f.exists() ? await f.readAsBytes() : null;
  }

  Future<SyncReport> sync() async {
    if (_running) throw StateError('Já existe uma sincronização em andamento.');
    _running = true;
    try {
      final report = SyncReport();
      final deviceId = await getSyncMeta(db, 'device_id');
      final cursor = int.tryParse(await getSyncMeta(db, 'cursor')) ?? 0;

      final pull = await transport.pull(cursor);
      final remote = pull.changes.where((c) => c.device != deviceId && kSyncEntities.contains(c.entity)).toList();

      final media = await _prefetchMedia(remote);

      await db.transaction((txn) async {
        await setSyncMeta(txn, 'applying', '1'); 
        final ups = remote.where((c) => c.op == 'upsert').toList()
          ..sort((a, b) => syncEntityIndex(a.entity).compareTo(syncEntityIndex(b.entity)));
        for (final c in ups) {
          await _applyUpsert(txn, c, media, report);
        }
        final dels = remote.where((c) => c.op == 'delete').toList()
          ..sort((a, b) => syncEntityIndex(b.entity).compareTo(syncEntityIndex(a.entity)));
        for (final c in dels) {
          await _applyDelete(txn, c, report);
        }
        await setSyncMeta(txn, 'cursor', '${pull.latestSeq}');
        await setSyncMeta(txn, 'applying', '0');
      });

      report.pushed = await _push(deviceId);
      await setSyncMeta(db, 'last_sync', '${DateTime.now().millisecondsSinceEpoch}');
      return report;
    } finally {
      _running = false;
    }
  }

  Future<Map<String, Object?>?> _find(DatabaseExecutor x, String entity, String uuid) async {
    final rows = entity == 'state'
        ? await x.rawQuery(
            'SELECT s.* FROM state s JOIN question q ON q.id = s.question_id WHERE q.uuid = ?',
            [uuid],
          )
        : await x.rawQuery('SELECT * FROM $entity WHERE uuid = ?', [uuid]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<int?> _idOf(DatabaseExecutor x, String table, String? uuid) async {
    if (uuid == null || uuid.isEmpty) return null;
    final rows = await x.rawQuery('SELECT id FROM $table WHERE uuid = ?', [uuid]);
    return rows.isEmpty ? null : _asInt(rows.first['id']);
  }

  Future<String?> _uuidOf(DatabaseExecutor x, String table, int? id) async {
    if (id == null) return null;
    final rows = await x.rawQuery('SELECT uuid FROM $table WHERE id = ?', [id]);
    return rows.isEmpty ? null : rows.first['uuid'] as String?;
  }

  Future<_Pending?> _pending(DatabaseExecutor x, String entity, String uuid) async {
    final rows = await x.rawQuery(
      'SELECT op, ts FROM sync_log WHERE entity = ? AND uuid = ? ORDER BY seq DESC LIMIT 1',
      [entity, uuid],
    );
    if (rows.isEmpty) return null;
    return _Pending(rows.first['op'] as String, _asInt(rows.first['ts']) ?? 0);
  }

  Future<void> _clearPending(DatabaseExecutor x, String entity, String uuid, int upTo) async {
    await x.rawDelete(
      'DELETE FROM sync_log WHERE entity = ? AND uuid = ? AND ts <= ?',
      [entity, uuid, upTo],
    );
  }

  Future<int> _now(DatabaseExecutor x) async {
    final rows = await x.rawQuery('SELECT $kSyncNowSql AS t');
    return _asInt(rows.first['t']) ?? DateTime.now().millisecondsSinceEpoch;
  }

  Future<Map<String, String>> _prefetchMedia(List<SyncChange> changes) async {
    final out = <String, String>{};
    for (final c in changes) {
      if (c.entity != 'question' || c.op != 'upsert') continue;
      final q = c.data?['questions'];
      if (q is! Map) continue;
      for (final v in q.values) {
        if (v is String && v.startsWith('blob:') && !out.containsKey(v)) {
          final path = await _localPathForRef(v);
          if (path != null) out[v] = path;
        }
      }
    }
    return out;
  }

  Future<String?> _localPathForRef(String ref) async {
    final dot = ref.indexOf('.', 5);
    final hash = ref.substring(5, dot == -1 ? ref.length : dot);
    final ext = dot == -1 ? '' : ref.substring(dot);

    final rows = await db.rawQuery('SELECT path FROM sync_media WHERE hash = ?', [hash]);
    if (rows.isNotEmpty) {
      final p = rows.first['path'] as String;
      if (await File(p).exists()) return p;
    }
    final bytes = await transport.getBlob(hash);
    if (bytes == null) return null;
    final path = await saveMedia(bytes, ext, _imageExts.contains(ext.toLowerCase()));
    await db.rawInsert('INSERT OR REPLACE INTO sync_media (hash, path) VALUES (?, ?)', [hash, path]);
    return path;
  }

  Future<String?> _blobRef(String path, Map<String, List<int>> blobs) async {
    final bytes = await readFile(path);
    if (bytes == null) return null;
    final hash = sha256.convert(bytes).toString();
    await db.rawInsert('INSERT OR IGNORE INTO sync_media (hash, path) VALUES (?, ?)', [hash, path]);
    blobs[hash] = bytes;
    return 'blob:$hash${_extOf(path)}';
  }

  // ------------------------------------------------------ aplicar (baixar)

  Future<void> _applyUpsert(
    DatabaseExecutor x,
    SyncChange c,
    Map<String, String> media,
    SyncReport report,
  ) async {
    final local = await _find(x, c.entity, c.uuid);

    if (local == null) {
      final p = await _pending(x, c.entity, c.uuid);
      if (p != null && p.op == 'delete' && p.ts > c.ts) {
        report.skipped++; // exclusão local mais nova que esta versão
        return;
      }
      if (await _tryAdopt(x, c, media)) {
        report.adopted++;
        return;
      }
    } else if (c.ts < (_asInt(local['updated_at']) ?? 0)) {
      report.kept++; // a edição local é mais nova: vale a local (ela será enviada)
      return;
    }

    final data = c.data ?? const <String, dynamic>{};
    if (await _writeRow(x, c.entity, c.uuid, c.ts, data, media, exists: local != null)) {
      report.applied++;
      await _clearPending(x, c.entity, c.uuid, c.ts);
    } else if (local == null) {
      report.skipped++;
    }
  }

  Future<void> _saveRow(
    DatabaseExecutor x,
    String table,
    String uuid,
    int ts,
    Map<String, Object?> cols, {
    required bool exists,
  }) async {
    if (exists) {
      final sets = [for (final k in cols.keys) '$k = ?', 'updated_at = ?'].join(', ');
      await x.rawUpdate('UPDATE $table SET $sets WHERE uuid = ?', [...cols.values, ts, uuid]);
    } else {
      final names = [...cols.keys, 'uuid', 'updated_at'];
      final marks = List.filled(names.length, '?').join(', ');
      await x.rawInsert(
        'INSERT INTO $table (${names.join(', ')}) VALUES ($marks)',
        [...cols.values, uuid, ts],
      );
    }
  }

  Future<bool> _writeRow(
    DatabaseExecutor x,
    String entity,
    String uuid,
    int ts,
    Map<String, dynamic> d,
    Map<String, String> media, {
    required bool exists,
  }) async {
    Future<void> save(Map<String, Object?> cols) =>
        _saveRow(x, entity, uuid, ts, cols, exists: exists);

    switch (entity) {
      case 'tag':
        await save({'title': d['title']});
        return true;

      case 'templates':
        await save({'template': d['template']});
        return true;

      case 'session':
        {
          final filters = <Map<String, int>>[];
          final rawFilters = d['tag_filters'];
          if (rawFilters is List) {
            for (final f in rawFilters) {
              if (f is! Map) continue;
              final tagId = await _idOf(x, 'tag', f['tag_uuid'] as String?);
              final qty = _asInt(f['quantity']);
              if (tagId != null && qty != null) filters.add({'tag_id': tagId, 'quantity': qty});
            }
          }
          await save({
            'title': d['title'],
            'time_limit': d['time_limit'],
            'total_q': d['total_q'],
            'tag_filters': filters.isEmpty ? null : jsonEncode(filters),
          });
          return true;
        }

      case 'package':
        await save({
          'title': d['title'],
          'session_id': await _idOf(x, 'session', d['session_uuid'] as String?),
        });
        return true;

      case 'question':
        {
          final packageId = await _idOf(x, 'package', d['package_uuid'] as String?);
          final templateId = await _idOf(x, 'templates', d['template_uuid'] as String?);
          if (packageId == null || templateId == null) return false; // pai ainda não existe

          final values = <String, Object?>{};
          final raw = d['questions'];
          if (raw is Map) {
            raw.forEach((k, v) {
              values['$k'] = (v is String && v.startsWith('blob:')) ? media[v] : v;
            });
          }
          await save({
            'package_id': packageId,
            'tag_id': await _idOf(x, 'tag', d['tag_uuid'] as String?),
            'template_id': templateId,
            'questions': jsonEncode(values),
          });
          return true;
        }

      case 'state':
        {
          final questionId = await _idOf(x, 'question', uuid);
          if (questionId == null) return false;
          await x.rawInsert(
            'INSERT OR REPLACE INTO state (question_id, state, interval_days, ease_factor, due_date, updated_at) '
            'VALUES (?, ?, ?, ?, ?, ?)',
            [questionId, d['state'], d['interval_days'], d['ease_factor'], d['due_date'], ts],
          );
          return true;
        }

      case 'revlog':
        {
          if (exists) return true; // histórico só acrescenta
          final questionUuid = d['question_uuid'] as String?;
          await save({
            'question_id': await _idOf(x, 'question', questionUuid) ?? 0,
            'data': d['data'],
            'time': d['time'],
            'question_uuid': questionUuid,
          });
          return true;
        }
    }
    return false;
  }

  Future<bool> _tryAdopt(DatabaseExecutor x, SyncChange c, Map<String, String> media) async {
    if (c.entity != 'tag' && c.entity != 'package' && c.entity != 'session') return false;
    final title = c.data?['title'];
    if (title is! String) return false;
    final key = normalizeText(title);

    final rows = await x.rawQuery('SELECT * FROM ${c.entity}');
    for (final row in rows) {
      if (normalizeText((row['title'] as String?) ?? '') != key) continue;
      final oldUuid = row['uuid'] as String?;
      if (oldUuid == null) continue;
      final p = await _pending(x, c.entity, oldUuid);
      if (p == null || p.op != 'upsert') continue;

      await x.rawUpdate('UPDATE ${c.entity} SET uuid = ? WHERE uuid = ?', [c.uuid, oldUuid]);
      await x.rawDelete('DELETE FROM sync_log WHERE entity = ? AND uuid = ?', [c.entity, oldUuid]);

      final localTs = _asInt(row['updated_at']) ?? 0;
      if (c.ts >= localTs) {
        await _writeRow(x, c.entity, c.uuid, c.ts, c.data ?? const <String, dynamic>{}, media, exists: true);
      } else {
        // a versão local é mais nova: mantém e reenvia com o uuid do servidor
        await x.rawInsert(
          'INSERT INTO sync_log (entity, uuid, op, ts) VALUES (?, ?, ?, ?)',
          [c.entity, c.uuid, 'upsert', localTs],
        );
      }
      return true;
    }
    return false;
  }

  Future<void> _applyDelete(DatabaseExecutor x, SyncChange c, SyncReport report) async {
    final row = await _find(x, c.entity, c.uuid);
    if (row == null) {
      await _clearPending(x, c.entity, c.uuid, c.ts);
      return;
    }
    final localTs = _asInt(row['updated_at']) ?? 0;
    if (localTs > c.ts) {
      report.kept++; 
      return;
    }
    final id = _asInt(row['id']);
    if (id == null) return; 
    
    final childColumn = const {'package': 'package_id', 'templates': 'template_id'}[c.entity];
    if (childColumn != null) {
      final used = await x.rawQuery('SELECT 1 FROM question WHERE $childColumn = ? LIMIT 1', [id]);
      if (used.isNotEmpty) {
        await _resurrect(x, c.entity, id, c.uuid);
        report.kept++;
        return;
      }
    }
    if (c.entity == 'session') {
      await x.rawUpdate('UPDATE package SET session_id = NULL WHERE session_id = ?', [id]);
    }
    if (c.entity == 'tag') {
      await x.rawUpdate('UPDATE question SET tag_id = NULL WHERE tag_id = ?', [id]);
    }
    if (c.entity == 'question') {
      await x.rawDelete('DELETE FROM state WHERE question_id = ?', [id]);
    }
    await x.rawDelete('DELETE FROM ${c.entity} WHERE id = ?', [id]);
    report.applied++;
    await _clearPending(x, c.entity, c.uuid, c.ts);
  }

  Future<void> _resurrect(DatabaseExecutor x, String entity, int id, String uuid) async {
    final ts = await _now(x);
    await x.rawUpdate('UPDATE $entity SET updated_at = ? WHERE id = ?', [ts, id]);
    await x.rawInsert(
      'INSERT INTO sync_log (entity, uuid, op, ts) VALUES (?, ?, ?, ?)',
      [entity, uuid, 'upsert', ts],
    );
  }

  Future<int> _push(String deviceId) async {
    final rows = await db.rawQuery('SELECT seq, entity, uuid, op, ts FROM sync_log ORDER BY seq');
    if (rows.isEmpty) return 0;

    final maxSeq = _asInt(rows.last['seq']) ?? 0;
    final latest = <String, Map<String, Object?>>{};
    for (final r in rows) {
      latest['${r['entity']}|${r['uuid']}'] = r; 
    }
    final entries = latest.values.toList()
      ..sort((a, b) => syncEntityIndex(a['entity'] as String).compareTo(syncEntityIndex(b['entity'] as String)));

    final blobs = <String, List<int>>{};
    final out = <SyncChange>[];
    for (final r in entries) {
      final entity = r['entity'] as String;
      final uuid = r['uuid'] as String;
      if (!kSyncEntities.contains(entity)) continue;

      if (r['op'] == 'delete') {
        out.add(SyncChange(entity: entity, uuid: uuid, op: 'delete', ts: _asInt(r['ts']) ?? 0, data: null, device: deviceId));
        continue;
      }
      final row = await _find(db, entity, uuid);
      if (row == null) continue; 
      out.add(SyncChange(
        entity: entity,
        uuid: uuid,
        op: 'upsert',
        ts: _asInt(row['updated_at']) ?? 0,
        data: await _toWire(entity, row, blobs),
        device: deviceId,
      ));
    }

    for (final e in blobs.entries) {
      if (!await transport.hasBlob(e.key)) await transport.putBlob(e.key, e.value);
    }
    for (var i = 0; i < out.length; i += 200) {
      final end = i + 200 > out.length ? out.length : i + 200;
      await transport.push(deviceId, out.sublist(i, end));
    }
    await db.rawDelete('DELETE FROM sync_log WHERE seq <= ?', [maxSeq]);
    return out.length;
  }

  Future<Map<String, dynamic>> _toWire(
    String entity,
    Map<String, Object?> row,
    Map<String, List<int>> blobs,
  ) async {
    switch (entity) {
      case 'tag':
        return {'title': row['title']};

      case 'templates':
        return {'template': row['template']};

      case 'session':
        {
          final filters = <Map<String, Object?>>[];
          for (final f in _decodeList(row['tag_filters'] as String?)) {
            if (f is! Map) continue;
            final u = await _uuidOf(db, 'tag', _asInt(f['tag_id']));
            if (u != null) filters.add({'tag_uuid': u, 'quantity': f['quantity']});
          }
          return {
            'title': row['title'],
            'time_limit': row['time_limit'],
            'total_q': row['total_q'],
            'tag_filters': filters,
          };
        }

      case 'package':
        return {
          'title': row['title'],
          'session_uuid': await _uuidOf(db, 'session', _asInt(row['session_id'])),
        };

      case 'question':
        {
          final values = _decodeMap(row['questions'] as String?);
          final tplRows = await db.rawQuery('SELECT template FROM templates WHERE id = ?', [row['template_id']]);
          final tpl = tplRows.isEmpty ? <String, dynamic>{} : _decodeMap(tplRows.first['template'] as String?);
          final fields = tpl['fields'];
          if (fields is List) {
            for (final f in fields) {
              if (f is! Map) continue;
              final type = f['type'];
              final id = f['id'];
              if ((type != 'image' && type != 'audio') || id is! String) continue;
              final v = values[id];
              values[id] = (v is String && v.isNotEmpty) ? await _blobRef(v, blobs) : null;
            }
          }
          return {
            'package_uuid': await _uuidOf(db, 'package', _asInt(row['package_id'])),
            'tag_uuid': await _uuidOf(db, 'tag', _asInt(row['tag_id'])),
            'template_uuid': await _uuidOf(db, 'templates', _asInt(row['template_id'])),
            'questions': values,
          };
        }

      case 'state':
        return {
          'state': row['state'],
          'interval_days': row['interval_days'],
          'ease_factor': row['ease_factor'],
          'due_date': row['due_date'],
        };

      case 'revlog':
        return {
          'question_uuid': row['question_uuid'],
          'data': row['data'],
          'time': row['time'],
        };
    }
    return <String, dynamic>{};
  }
}
