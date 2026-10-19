// GERADO a partir do SQL testado em dois aparelhos simulados. Não edite à mão:
// qualquer mudança aqui precisa ser refeita e retestada nos cenários de sincronização.
import 'package:sqflite/sqflite.dart';

/// Tabelas que ganham `uuid` (a `state` usa o uuid da questão).
const List<String> kSyncUuidTables = ['tag', 'templates', 'session', 'package', 'question', 'revlog'];

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

// tabela, coluna, tipo (só é adicionada se ainda não existir)
const List<List<String>> _newColumns = [
  ['tag', 'uuid', 'TEXT'],
  ['templates', 'uuid', 'TEXT'],
  ['session', 'uuid', 'TEXT'],
  ['package', 'uuid', 'TEXT'],
  ['question', 'uuid', 'TEXT'],
  ['revlog', 'uuid', 'TEXT'],
  ['tag', 'updated_at', 'INTEGER'],
  ['templates', 'updated_at', 'INTEGER'],
  ['session', 'updated_at', 'INTEGER'],
  ['package', 'updated_at', 'INTEGER'],
  ['question', 'updated_at', 'INTEGER'],
  ['revlog', 'updated_at', 'INTEGER'],
  ['state', 'updated_at', 'INTEGER'],
  ['revlog', 'question_uuid', 'TEXT'],
];

const List<String> _postStatements = [
  r'''UPDATE tag SET uuid = lower(hex(randomblob(16))) WHERE uuid IS NULL''',
  r'''UPDATE tag SET updated_at = CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) WHERE updated_at IS NULL''',
  r'''UPDATE templates SET uuid = lower(hex(randomblob(16))) WHERE uuid IS NULL''',
  r'''UPDATE templates SET updated_at = CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) WHERE updated_at IS NULL''',
  r'''UPDATE session SET uuid = lower(hex(randomblob(16))) WHERE uuid IS NULL''',
  r'''UPDATE session SET updated_at = CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) WHERE updated_at IS NULL''',
  r'''UPDATE package SET uuid = lower(hex(randomblob(16))) WHERE uuid IS NULL''',
  r'''UPDATE package SET updated_at = CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) WHERE updated_at IS NULL''',
  r'''UPDATE question SET uuid = lower(hex(randomblob(16))) WHERE uuid IS NULL''',
  r'''UPDATE question SET updated_at = CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) WHERE updated_at IS NULL''',
  r'''UPDATE revlog SET uuid = lower(hex(randomblob(16))) WHERE uuid IS NULL''',
  r'''UPDATE revlog SET updated_at = CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) WHERE updated_at IS NULL''',
  r'''UPDATE state SET updated_at = CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) WHERE updated_at IS NULL''',
  r'''UPDATE revlog SET question_uuid = (SELECT uuid FROM question WHERE id = revlog.question_id) WHERE question_uuid IS NULL''',
  r'''CREATE UNIQUE INDEX IF NOT EXISTS idx_tag_uuid ON tag (uuid)''',
  r'''CREATE UNIQUE INDEX IF NOT EXISTS idx_templates_uuid ON templates (uuid)''',
  r'''CREATE UNIQUE INDEX IF NOT EXISTS idx_session_uuid ON session (uuid)''',
  r'''CREATE UNIQUE INDEX IF NOT EXISTS idx_package_uuid ON package (uuid)''',
  r'''CREATE UNIQUE INDEX IF NOT EXISTS idx_question_uuid ON question (uuid)''',
  r'''CREATE UNIQUE INDEX IF NOT EXISTS idx_revlog_uuid ON revlog (uuid)''',
  r'''CREATE TRIGGER IF NOT EXISTS sync_tag_ai AFTER INSERT ON tag
WHEN (SELECT value FROM sync_meta WHERE key = 'applying') = '0'
BEGIN
  UPDATE tag SET uuid = COALESCE(uuid, lower(hex(randomblob(16)))), updated_at = CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) WHERE id = NEW.id;
  INSERT INTO sync_log (entity, uuid, op, ts)
    SELECT 'tag', uuid, 'upsert', updated_at FROM tag WHERE id = NEW.id AND (SELECT value FROM sync_meta WHERE key = 'enabled') = '1';
END''',
  r'''CREATE TRIGGER IF NOT EXISTS sync_tag_au AFTER UPDATE ON tag
WHEN (SELECT value FROM sync_meta WHERE key = 'applying') = '0' AND NEW.updated_at IS OLD.updated_at
BEGIN
  UPDATE tag SET updated_at = CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) WHERE id = NEW.id;
  INSERT INTO sync_log (entity, uuid, op, ts)
    SELECT 'tag', uuid, 'upsert', updated_at FROM tag WHERE id = NEW.id AND (SELECT value FROM sync_meta WHERE key = 'enabled') = '1';
END''',
  r'''CREATE TRIGGER IF NOT EXISTS sync_tag_ad AFTER DELETE ON tag
WHEN (SELECT value FROM sync_meta WHERE key = 'applying') = '0'
BEGIN
  INSERT INTO sync_log (entity, uuid, op, ts)
    SELECT 'tag', OLD.uuid, 'delete', CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) WHERE OLD.uuid IS NOT NULL AND (SELECT value FROM sync_meta WHERE key = 'enabled') = '1';
END''',
  r'''CREATE TRIGGER IF NOT EXISTS sync_templates_ai AFTER INSERT ON templates
WHEN (SELECT value FROM sync_meta WHERE key = 'applying') = '0'
BEGIN
  UPDATE templates SET uuid = COALESCE(uuid, lower(hex(randomblob(16)))), updated_at = CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) WHERE id = NEW.id;
  INSERT INTO sync_log (entity, uuid, op, ts)
    SELECT 'templates', uuid, 'upsert', updated_at FROM templates WHERE id = NEW.id AND (SELECT value FROM sync_meta WHERE key = 'enabled') = '1';
END''',
  r'''CREATE TRIGGER IF NOT EXISTS sync_templates_au AFTER UPDATE ON templates
WHEN (SELECT value FROM sync_meta WHERE key = 'applying') = '0' AND NEW.updated_at IS OLD.updated_at
BEGIN
  UPDATE templates SET updated_at = CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) WHERE id = NEW.id;
  INSERT INTO sync_log (entity, uuid, op, ts)
    SELECT 'templates', uuid, 'upsert', updated_at FROM templates WHERE id = NEW.id AND (SELECT value FROM sync_meta WHERE key = 'enabled') = '1';
END''',
  r'''CREATE TRIGGER IF NOT EXISTS sync_templates_ad AFTER DELETE ON templates
WHEN (SELECT value FROM sync_meta WHERE key = 'applying') = '0'
BEGIN
  INSERT INTO sync_log (entity, uuid, op, ts)
    SELECT 'templates', OLD.uuid, 'delete', CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) WHERE OLD.uuid IS NOT NULL AND (SELECT value FROM sync_meta WHERE key = 'enabled') = '1';
END''',
  r'''CREATE TRIGGER IF NOT EXISTS sync_session_ai AFTER INSERT ON session
WHEN (SELECT value FROM sync_meta WHERE key = 'applying') = '0'
BEGIN
  UPDATE session SET uuid = COALESCE(uuid, lower(hex(randomblob(16)))), updated_at = CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) WHERE id = NEW.id;
  INSERT INTO sync_log (entity, uuid, op, ts)
    SELECT 'session', uuid, 'upsert', updated_at FROM session WHERE id = NEW.id AND (SELECT value FROM sync_meta WHERE key = 'enabled') = '1';
END''',
  r'''CREATE TRIGGER IF NOT EXISTS sync_session_au AFTER UPDATE ON session
WHEN (SELECT value FROM sync_meta WHERE key = 'applying') = '0' AND NEW.updated_at IS OLD.updated_at
BEGIN
  UPDATE session SET updated_at = CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) WHERE id = NEW.id;
  INSERT INTO sync_log (entity, uuid, op, ts)
    SELECT 'session', uuid, 'upsert', updated_at FROM session WHERE id = NEW.id AND (SELECT value FROM sync_meta WHERE key = 'enabled') = '1';
END''',
  r'''CREATE TRIGGER IF NOT EXISTS sync_session_ad AFTER DELETE ON session
WHEN (SELECT value FROM sync_meta WHERE key = 'applying') = '0'
BEGIN
  INSERT INTO sync_log (entity, uuid, op, ts)
    SELECT 'session', OLD.uuid, 'delete', CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) WHERE OLD.uuid IS NOT NULL AND (SELECT value FROM sync_meta WHERE key = 'enabled') = '1';
END''',
  r'''CREATE TRIGGER IF NOT EXISTS sync_package_ai AFTER INSERT ON package
WHEN (SELECT value FROM sync_meta WHERE key = 'applying') = '0'
BEGIN
  UPDATE package SET uuid = COALESCE(uuid, lower(hex(randomblob(16)))), updated_at = CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) WHERE id = NEW.id;
  INSERT INTO sync_log (entity, uuid, op, ts)
    SELECT 'package', uuid, 'upsert', updated_at FROM package WHERE id = NEW.id AND (SELECT value FROM sync_meta WHERE key = 'enabled') = '1';
END''',
  r'''CREATE TRIGGER IF NOT EXISTS sync_package_au AFTER UPDATE ON package
WHEN (SELECT value FROM sync_meta WHERE key = 'applying') = '0' AND NEW.updated_at IS OLD.updated_at
BEGIN
  UPDATE package SET updated_at = CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) WHERE id = NEW.id;
  INSERT INTO sync_log (entity, uuid, op, ts)
    SELECT 'package', uuid, 'upsert', updated_at FROM package WHERE id = NEW.id AND (SELECT value FROM sync_meta WHERE key = 'enabled') = '1';
END''',
  r'''CREATE TRIGGER IF NOT EXISTS sync_package_ad AFTER DELETE ON package
WHEN (SELECT value FROM sync_meta WHERE key = 'applying') = '0'
BEGIN
  INSERT INTO sync_log (entity, uuid, op, ts)
    SELECT 'package', OLD.uuid, 'delete', CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) WHERE OLD.uuid IS NOT NULL AND (SELECT value FROM sync_meta WHERE key = 'enabled') = '1';
END''',
  r'''CREATE TRIGGER IF NOT EXISTS sync_question_ai AFTER INSERT ON question
WHEN (SELECT value FROM sync_meta WHERE key = 'applying') = '0'
BEGIN
  UPDATE question SET uuid = COALESCE(uuid, lower(hex(randomblob(16)))), updated_at = CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) WHERE id = NEW.id;
  INSERT INTO sync_log (entity, uuid, op, ts)
    SELECT 'question', uuid, 'upsert', updated_at FROM question WHERE id = NEW.id AND (SELECT value FROM sync_meta WHERE key = 'enabled') = '1';
END''',
  r'''CREATE TRIGGER IF NOT EXISTS sync_question_au AFTER UPDATE ON question
WHEN (SELECT value FROM sync_meta WHERE key = 'applying') = '0' AND NEW.updated_at IS OLD.updated_at
BEGIN
  UPDATE question SET updated_at = CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) WHERE id = NEW.id;
  INSERT INTO sync_log (entity, uuid, op, ts)
    SELECT 'question', uuid, 'upsert', updated_at FROM question WHERE id = NEW.id AND (SELECT value FROM sync_meta WHERE key = 'enabled') = '1';
END''',
  r'''CREATE TRIGGER IF NOT EXISTS sync_question_ad AFTER DELETE ON question
WHEN (SELECT value FROM sync_meta WHERE key = 'applying') = '0'
BEGIN
  INSERT INTO sync_log (entity, uuid, op, ts)
    SELECT 'question', OLD.uuid, 'delete', CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) WHERE OLD.uuid IS NOT NULL AND (SELECT value FROM sync_meta WHERE key = 'enabled') = '1';
END''',
  r'''CREATE TRIGGER IF NOT EXISTS sync_revlog_ai AFTER INSERT ON revlog
WHEN (SELECT value FROM sync_meta WHERE key = 'applying') = '0'
BEGIN
  UPDATE revlog SET uuid = COALESCE(uuid, lower(hex(randomblob(16)))), updated_at = CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER), question_uuid = COALESCE(question_uuid, (SELECT uuid FROM question WHERE id = NEW.question_id)) WHERE id = NEW.id;
  INSERT INTO sync_log (entity, uuid, op, ts)
    SELECT 'revlog', uuid, 'upsert', updated_at FROM revlog WHERE id = NEW.id AND (SELECT value FROM sync_meta WHERE key = 'enabled') = '1';
END''',
  r'''CREATE TRIGGER IF NOT EXISTS sync_revlog_ad AFTER DELETE ON revlog
WHEN (SELECT value FROM sync_meta WHERE key = 'applying') = '0'
BEGIN
  INSERT INTO sync_log (entity, uuid, op, ts)
    SELECT 'revlog', OLD.uuid, 'delete', CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) WHERE OLD.uuid IS NOT NULL AND (SELECT value FROM sync_meta WHERE key = 'enabled') = '1';
END''',
  r'''CREATE TRIGGER IF NOT EXISTS sync_state_ai AFTER INSERT ON state
WHEN (SELECT value FROM sync_meta WHERE key = 'applying') = '0'
BEGIN
  UPDATE state SET updated_at = CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) WHERE question_id = NEW.question_id;
  INSERT INTO sync_log (entity, uuid, op, ts)
    SELECT 'state', q.uuid, 'upsert', CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) FROM question q WHERE q.id = NEW.question_id AND (SELECT value FROM sync_meta WHERE key = 'enabled') = '1';
END''',
  r'''CREATE TRIGGER IF NOT EXISTS sync_state_au AFTER UPDATE ON state
WHEN (SELECT value FROM sync_meta WHERE key = 'applying') = '0' AND NEW.updated_at IS OLD.updated_at
BEGIN
  UPDATE state SET updated_at = CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) WHERE question_id = NEW.question_id;
  INSERT INTO sync_log (entity, uuid, op, ts)
    SELECT 'state', q.uuid, 'upsert', CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER) FROM question q WHERE q.id = NEW.question_id AND (SELECT value FROM sync_meta WHERE key = 'enabled') = '1';
END''',
];

/// Migração v4: uuid + updated_at nas tabelas, fila de mudanças (`sync_log`) e
/// gatilhos que a alimentam. Idempotente: pode rodar mais de uma vez.
Future<void> applySyncSchema(DatabaseExecutor db) async {
  for (final sql in _preStatements) {
    await db.execute(sql);
  }
  for (final c in _newColumns) {
    final info = await db.rawQuery('PRAGMA table_info(${c[0]})');
    final has = info.any((r) => r['name'] == c[1]);
    if (!has) {
      await db.execute('ALTER TABLE ${c[0]} ADD COLUMN ${c[1]} ${c[2]}');
    }
  }
  for (final sql in _postStatements) {
    await db.execute(sql);
  }
}
