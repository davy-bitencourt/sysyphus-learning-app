import '../../data/database_helper.dart';

class PackageDao {
  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    return db.query('package');
  }

  Future<void> insert(Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;

    await db.insert(
      'package', 
      data
    );
  }

  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;

    await db.delete(
      'package', 
      where: 'id = ?', 
      whereArgs: [id]
    );
  }
}