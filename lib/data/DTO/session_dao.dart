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
    await db.rawDelete(
      '''
        DELETE FROM session
        WHERE id = ?
      ''', [id]
    );
  }
}
