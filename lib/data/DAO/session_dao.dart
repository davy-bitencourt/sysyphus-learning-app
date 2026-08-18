import 'package:sysyphus_learning_app/data/DTO/session_dto.dart';

import '../../data/database_helper.dart';

class SessionDao {

  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    return db.rawQuery(
      '''
        SELECT id, title, time_limit, total_q
        FROM session
      '''
    );
  }

  Future<void> insert(SessionDto dto) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawInsert(
      '''
        INSERT INTO session (title, time_limit, total_q)
        VALUES (?, ?, ?)
      ''', [dto.title, dto.time_limit, dto.total_q]
    );
  }

  Future<void> update(SessionDto dto) async {
    assert(dto.id != null, 'SessionDto.id é obrigatório para update');
    final db = await DatabaseHelper.instance.database;
    await db.rawUpdate(
      '''
        UPDATE session
        SET title = ?, time_limit = ?, total_q = ?
        WHERE id = ?
      ''', [dto.title, dto.time_limit, dto.total_q, dto.id]
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
