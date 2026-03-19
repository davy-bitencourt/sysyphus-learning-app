import '../../data/database_helper.dart';

class SessionDao {
  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    return db.query('session');
  }

  Future<void> insert(Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;

    await db.insert(
      'session', 
      data
    );
  }

  Future<void> update(Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;

    await db.update(
      'session', 
      data,
      where: 'id = ?', 
      whereArgs: [data['id']]
    );
  }

  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;

    await db.delete(
      'session', 
      where: 'id = ?', 
      whereArgs: [id]
    );
  }
}