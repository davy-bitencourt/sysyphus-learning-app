import '../../data/database_helper.dart';

class TagDao {
  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await DatabaseHelper.instance.database;

    return db.rawQuery(
      '''
        SELECT id, title
        FROM tag
      ''',
    );
  }

  Future<int> insert(String title) async {
    final db = await DatabaseHelper.instance.database;

    return await db.rawInsert(
      '''
        INSERT INTO tag (title)
        VALUES (?)
      ''',
      [title],
    );
  }

  Future<void> update(int id, String title) async {
    final db = await DatabaseHelper.instance.database;

    await db.rawUpdate(
      '''
        UPDATE tag
        SET title = ?
        WHERE id = ?
      ''',
      [title, id],
    );
  }

  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;

    await db.rawDelete(
      '''
        DELETE FROM tag
        WHERE id = ?
      ''',
      [id],
    );
  }
}