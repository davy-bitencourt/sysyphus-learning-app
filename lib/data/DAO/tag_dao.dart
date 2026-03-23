import '../../data/database_helper.dart';

class TagDao {
  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await DatabaseHelper.instance.database;

    return db.rawQuery(
      '''
        SELECT id, title
        FROM tag
      '''
    );
  }

  Future<void> insert(String title) async {
    final db = await DatabaseHelper.instance.database;

    await db.rawInsert(
      '''
        INSERT INTO tag (title)
        VALUES (?)
      ''', [title]
    );
  }

  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;

    await db.rawDelete(
      '''
        DELETE FROM tag
        WHERE id = ?
      ''', [id]
    );
  }
}