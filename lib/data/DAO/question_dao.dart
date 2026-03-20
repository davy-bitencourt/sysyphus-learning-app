import '../../data/database_helper.dart';

class QuestionDao {
  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    return db.query('question');
  }

  /* retorna um bloco de questões */
  Future<List<Map<String, dynamic>>> getByPackage(int packageId, int limit) async {
    final db = await DatabaseHelper.instance.database;

    if(limit > 60){
      limit = 60;
    }

    return db.rawQuery(
      '''
        SELECT template_id, enunciado, questions, extra, description 
        FROM question 
        WHERE package_id = ?
        ORDER BY RANDOM() 
        LIMIT ?
      ''', [packageId, limit]
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