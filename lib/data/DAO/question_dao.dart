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

Future<void> insert(int packageId, int tagId, int templateId, String enunciado, String questions, String extra, String description) async {
  final db = await DatabaseHelper.instance.database;

  await db.rawInsert(
    '''
      INSERT INTO question (package_id, tag_id, template_id, enunciado, questions, extra, description)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    ''', [packageId, tagId, templateId, enunciado, questions, extra, description]
  );
}

Future<void> update(int id, int packageId, int tagId, int templateId, String enunciado, String questions, String extra, String description) async {
  final db = await DatabaseHelper.instance.database;

  await db.rawUpdate(
    '''
      UPDATE question
      SET package_id = ?, tag_id = ?, template_id = ?, enunciado = ?, questions = ?, extra = ?, description = ?
      WHERE id = ?
    ''', [packageId, tagId, templateId, enunciado, questions, extra, description, id]
  );
}

Future<void> delete(int id) async {
  final db = await DatabaseHelper.instance.database;

  await db.rawDelete(
    '''
      DELETE FROM question
      WHERE id = ?
    ''', [id]
  );
}
}