import '../../data/database_helper.dart';

class TagDao {
  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    return db.query('tag');
  }

  Future<void> insert(Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;

    await db.insert(
      'tag', 
      data
    );
  }

  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;

    await db.delete(
      'tag', 
      where: 'id = ?', 
      whereArgs: [id]
    );
  }
}