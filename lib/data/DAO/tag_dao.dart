import '../../data/database_helper.dart';
import '../../models/tag.dart';

class TagDao {
  Future<List<Tag>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('tag');
    return result.map(Tag.fromMap).toList();
  }

  Future<void> insert(Tag tag) async {
    final db = await DatabaseHelper.instance.database;

    await db.insert(
      'tag', 
      tag.toMap()
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