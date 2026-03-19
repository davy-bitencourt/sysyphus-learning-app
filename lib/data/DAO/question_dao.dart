import '../../data/database_helper.dart';

class QuestionDao {
  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    return db.query('question');
  }

  Future<List<Map<String, dynamic>>> getByPackage(int packageId) async {
    final db = await DatabaseHelper.instance.database;

    return db.query(
      'question',
      where: 'package_id = ?',
      whereArgs: [packageId],
    );
  }

  Future<void> insert(Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;

    await db.insert(
      'question', 
      data
    );
  }

  Future<void> update(Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;

    await db.update(
      'question', 
      data,
      where: 'id = ?', 
      whereArgs: [data['id']]
    );
  }

  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;

    await db.delete(
      'question', 
      where: 'id = ?', 
      whereArgs: [id]
    );
  }
}