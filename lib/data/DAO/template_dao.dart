import '../../data/database_helper.dart';

class TemplateDao {
  Future<List<Map<String, dynamic>>> getRandomLimit(int limit) async {
    final db = await DatabaseHelper.instance.database;
    return db.rawQuery(
      """
        SELECT  id, template
        FROM templates
        ORDER BY RANDOM()
        LIMIT ?
      """, [limit]
    );
  }

  Future<void> insert(Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;

    await db.insert(
      'templates', 
      data
    );
  }

  Future<List<Map<String, dynamic>>> getTemplateById(int templateId) async {
    final db = await DatabaseHelper.instance.database;

    return db.rawQuery(
      '''
        SELECT template
        FROM templates
        WHERE id = ?
      ''', [templateId]
    );
  }

  
  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;

    await db.delete(
      'templates', 
      where: 'id = ?', 
      whereArgs: [id]
    );
  }
}