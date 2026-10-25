import 'package:sqflite/sqflite.dart';

import 'sync_models.dart';
const String kSyncNowSql = "CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER)";
final List<String> kSyncUuidTables = [
  for (final e in kSyncEntities)
    if (e != 'state') e,
];

Future<String> getSyncMeta(DatabaseExecutor x, String key) async {
  final rows = await x.rawQuery('SELECT value FROM sync_meta WHERE key = ?', [key]);
  return rows.isEmpty ? '' : ((rows.first['value'] as String?) ?? '');
}

Future<void> setSyncMeta(DatabaseExecutor x, String key, String value) async {
  await x.rawInsert('INSERT OR REPLACE INTO sync_meta (key, value) VALUES (?, ?)', [key, value]);
}

const String _notApplying = "(SELECT value FROM sync_meta WHERE key = 'applying') = '0'";
const String _enabled = "(SELECT value FROM sync_meta WHERE key = 'enabled') = '1'";
const String _unchanged = 'NEW.updated_at IS OLD.updated_at'; // edição local (não veio do sync)
const String _revlogQuestionUuid =
    ', question_uuid = COALESCE(question_uuid, (SELECT uuid FROM question WHERE id = NEW.question_id))';

String _logUpsert(String t) => '''INSERT INTO sync_log (entity, uuid, op, ts)
    SELECT '$t', uuid, 'upsert', updated_at FROM $t WHERE id = NEW.id AND $_enabled''';

String _triggerInsert(String t, String extraSet) => '''CREATE TRIGGER IF NOT EXISTS sync_${t}_ai AFTER INSERT ON $t
WHEN $_notApplying
BEGIN
  UPDATE $t SET uuid = COALESCE(uuid, lower(hex(randomblob(16)))), updated_at = $kSyncNowSql$extraSet WHERE id = NEW.id;
  ${_logUpsert(t)};
END''';

String _triggerUpdate(String t) => '''CREATE TRIGGER IF NOT EXISTS sync_${t}_au AFTER UPDATE ON $t
WHEN $_notApplying AND $_unchanged
BEGIN
  UPDATE $t SET updated_at = $kSyncNowSql WHERE id = NEW.id;
  ${_logUpsert(t)};
END''';

String _triggerDelete(String t) => '''CREATE TRIGGER IF NOT EXISTS sync_${t}_ad AFTER DELETE ON $t
WHEN $_notApplying
BEGIN
  INSERT INTO sync_log (entity, uuid, op, ts)
    SELECT '$t', OLD.uuid, 'delete', $kSyncNowSql WHERE OLD.uuid IS NOT NULL AND $_enabled;
END''';

String _triggerState(String suffix, String event, String condition) =>
    '''CREATE TRIGGER IF NOT EXISTS sync_state_$suffix AFTER $event ON state
WHEN $condition
BEGIN
  UPDATE state SET updated_at = $kSyncNowSql WHERE question_id = NEW.question_id;
  INSERT INTO sync_log (entity, uuid, op, ts)
    SELECT 'state', q.uuid, 'upsert', $kSyncNowSql FROM question q WHERE q.id = NEW.question_id AND $_enabled;
END''';

const List<String> _preStatements = [
  r'''CREATE TABLE IF NOT EXISTS sync_meta (key TEXT PRIMARY KEY, value TEXT)''',
  r'''INSERT OR IGNORE INTO sync_meta (key, value) VALUES ('applying', '0')''',
  r'''INSERT OR IGNORE INTO sync_meta (key, value) VALUES ('enabled', '0')''',
  r'''INSERT OR IGNORE INTO sync_meta (key, value) VALUES ('cursor', '0')''',
  r'''INSERT OR IGNORE INTO sync_meta (key, value) VALUES ('device_id', lower(hex(randomblob(8))))''',
  r'''CREATE TABLE IF NOT EXISTS sync_log (
  seq INTEGER PRIMARY KEY AUTOINCREMENT,
  entity TEXT NOT NULL,
  uuid TEXT NOT NULL,
  op TEXT NOT NULL,
  ts INTEGER NOT NULL
)''',
  r'''CREATE INDEX IF NOT EXISTS idx_sync_log_key ON sync_log (entity, uuid)''',
  r'''CREATE TABLE IF NOT EXISTS sync_media (hash TEXT PRIMARY KEY, path TEXT NOT NULL)''',
];

final List<List<String>> _newColumns = [
  for (final t in kSyncUuidTables) [t, 'uuid', 'TEXT'],
  for (final t in [...kSyncUuidTables, 'state']) [t, 'updated_at', 'INTEGER'],
  ['revlog', 'question_uuid', 'TEXT'],
];

final List<String> _postStatements = [
  for (final t in kSyncUuidTables) ...[
    'UPDATE $t SET uuid = lower(hex(randomblob(16))) WHERE uuid IS NULL',
    'UPDATE $t SET updated_at = $kSyncNowSql WHERE updated_at IS NULL',
  ],
  'UPDATE state SET updated_at = $kSyncNowSql WHERE updated_at IS NULL',
  'UPDATE revlog SET question_uuid = (SELECT uuid FROM question WHERE id = revlog.question_id) '
      'WHERE question_uuid IS NULL',
  for (final t in kSyncUuidTables) 'CREATE UNIQUE INDEX IF NOT EXISTS idx_${t}_uuid ON $t (uuid)',
  for (final t in kSyncUuidTables) ...[
    _triggerInsert(t, t == 'revlog' ? _revlogQuestionUuid : ''),
    if (t != 'revlog') _triggerUpdate(t), 
    _triggerDelete(t),
  ],
  _triggerState('ai', 'INSERT', _notApplying),
  _triggerState('au', 'UPDATE', '$_notApplying AND $_unchanged'),
];

Future<void> applySyncSchema(DatabaseExecutor db) async {
  for (final sql in _preStatements) {
    await db.execute(sql);
  }
  for (final c in _newColumns) {
    final info = await db.rawQuery('PRAGMA table_info(${c[0]})');
    if (!info.any((r) => r['name'] == c[1])) {
      await db.execute('ALTER TABLE ${c[0]} ADD COLUMN ${c[1]} ${c[2]}');
    }
  }
  for (final sql in _postStatements) {
    await db.execute(sql);
  }
}
