import '../../data/database_helper.dart';
import 'package:sysyphus_learning_app/data/DTO/question_dto.dart';

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

Future<void> insert(QuestionDto dto) async {
  final db = await DatabaseHelper.instance.database;

  await db.rawInsert(
    '''
      INSERT INTO question (package_id, tag_id, template_id, enunciado, questions, extra, description)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    ''', [dto.packageId, dto.tagId, dto.templateId, dto.enunciado, dto.questions, dto.extra, dto.description]
  );
}

Future<void> update(int id, QuestionDto dto) async {
  final db = await DatabaseHelper.instance.database;

  await db.rawUpdate(
    '''
      UPDATE question
      SET package_id = ?, tag_id = ?, template_id = ?, enunciado = ?, questions = ?, extra = ?, description = ?
      WHERE id = ?
    ''', [dto.packageId, dto.tagId, dto.templateId, dto.enunciado, dto.questions, dto.extra, dto.description, id]
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