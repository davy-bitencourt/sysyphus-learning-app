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

  /* lista todos os templates, usada nas telas de gerenciamento/seleção */
  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    return db.rawQuery(
      """
        SELECT id, template
        FROM templates
      """
    );
  }

  Future<int> insert(String template) async {
    final db = await DatabaseHelper.instance.database;

    return db.rawInsert(
      '''
        INSERT INTO templates (template)
        VALUES (?)
      ''', [template]
    );
  }

  Future<void> update(int id, String template) async {
    final db = await DatabaseHelper.instance.database;

    await db.rawUpdate(
      '''
        UPDATE templates
        SET template = ?
        WHERE id = ?
      ''', [template, id]
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

    await db.rawDelete(
      '''
        DELETE FROM templates
        WHERE id = ?
      ''', [id]
    );
  }
}
