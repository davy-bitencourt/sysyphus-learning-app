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

  Future<void> insert(String title, String? timeLimit, int? totalQ) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawInsert(
      '''
        INSERT INTO session (title, time_limit, total_q)
        VALUES (?, ?, ?)
      ''', [title, timeLimit, totalQ]
    );
  }

  Future<void> update(int id, String title, String? timeLimit, int? totalQ) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawUpdate(
      '''
        UPDATE session
        SET title = ?, time_limit = ?, total_q = ?
        WHERE id = ?
      ''', [title, timeLimit, totalQ, id]
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