import 'dart:convert';

import '../DTO/session_dto.dart';
import '../database_helper.dart';

class SessionDao {

  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    return db.rawQuery(
      '''
        SELECT id, title, time_limit, total_q, tag_filters
        FROM session
      '''
    );
  }

  /// Sessão vinculada ao pacote (package.session_id), ou null se não houver.
  Future<Map<String, dynamic>?> getByPackage(int packageId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      '''
        SELECT s.id, s.title, s.time_limit, s.total_q, s.tag_filters
        FROM package p
        JOIN session s ON s.id = p.session_id
        WHERE p.id = ?
        LIMIT 1
      ''', [packageId]
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Sessão atualmente ligada ao pacote (package.session_id), ou null.
  Future<int?> getSessionIdOfPackage(int packageId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      'SELECT session_id FROM package WHERE id = ?', [packageId],
    );
    return rows.isEmpty ? null : (rows.first['session_id'] as num?)?.toInt();
  }

  /// O `time_limit` é guardado como texto:
  ///  - "<n>s"      = n SEGUNDOS (formato atual, escolhido na tela de sessão);
  ///  - só dígitos  = n MINUTOS (sessões criadas antes das unidades);
  ///  - null/vazio  = sem limite.
  static int? parseTimeLimitSeconds(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty) return null;
    if (t.endsWith('s')) {
      final n = int.tryParse(t.substring(0, t.length - 1));
      return (n != null && n > 0) ? n : null;
    }
    final minutes = int.tryParse(t);
    return (minutes != null && minutes > 0) ? minutes * 60 : null;
  }

  /// Texto a gravar em `time_limit` (null = sem limite).
  static String? formatTimeLimit(int? seconds) =>
      (seconds == null || seconds <= 0) ? null : '${seconds}s';

  /// Descrição curta: "1 h 30 min", "45 min", "90 s".
  static String describeTimeLimit(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final parts = <String>[
      if (h > 0) '$h h',
      if (m > 0) '$m min',
      if (s > 0) '$s s',
    ];
    return parts.join(' ');
  }

  /// Converte o JSON de tag_filters em [{tag_id, quantity}]. Vazio/inválido = [].
  static List<Map<String, int>> parseTagFilters(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return [
        for (final item in decoded)
          {
            'tag_id': (item['tag_id'] as num).toInt(),
            'quantity': (item['quantity'] as num).toInt(),
          },
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> insert(SessionDto dto) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawInsert(
      '''
        INSERT INTO session (title, time_limit, total_q, tag_filters)
        VALUES (?, ?, ?, ?)
      ''', [dto.title, dto.time_limit, dto.total_q, dto.tagFilters]
    );
  }

  Future<void> update(SessionDto dto) async {
    assert(dto.id != null, 'SessionDto.id é obrigatório para update');
    final db = await DatabaseHelper.instance.database;
    await db.rawUpdate(
      '''
        UPDATE session
        SET title = ?, time_limit = ?, total_q = ?, tag_filters = ?
        WHERE id = ?
      ''', [dto.title, dto.time_limit, dto.total_q, dto.tagFilters, dto.id]
    );
  }

  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      // package.session_id tem FOREIGN KEY: os pacotes ligados a esta sessão
      // ficam sem sessão antes de ela ser removida.
      await txn.rawUpdate('UPDATE package SET session_id = NULL WHERE session_id = ?', [id]);
      await txn.rawDelete('DELETE FROM session WHERE id = ?', [id]);
    });
  }
}
