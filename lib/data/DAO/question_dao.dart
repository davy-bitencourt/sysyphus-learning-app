import '../../data/database_helper.dart';
import '../../data/DTO/question_dto.dart';

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
        SELECT q.id, q.template_id, q.enunciado, q.questions, q.extra, q.description, s.state, s.interval_days, s.ease_factor, s.due_date
        FROM question q
        LEFT JOIN state s ON s.question_id = q.id
        WHERE q.package_id = ?
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

  Future<void> updateQuestion(int id, QuestionDto dto) async {
    final db = await DatabaseHelper.instance.database;

    await db.rawUpdate(
      '''
        UPDATE question
        SET package_id = ?, tag_id = ?, template_id = ?, enunciado = ?, questions = ?, extra = ?, description = ?
        WHERE id = ?
      ''', [dto.packageId, dto.tagId, dto.templateId, dto.enunciado, dto.questions, dto.extra, dto.description, id]
    );
  }

  /* alterações de estado */
  Future<void> updateQuestionState(int id, String state) async {
  final db = await DatabaseHelper.instance.database;
  await db.rawUpdate('''
    UPDATE state
    SET state = ?
    WHERE question_id = ?
  ''', [state, id]);
  }

  Future<void> updateQuestionIntervalDays(int id, int interval_days) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawUpdate(
      '''
        UPDATE state
        SET interval_days = ?
        WHERE question_id = ?
      ''', [interval_days, id]
    );
  }

  Future<void> updateQuestionEaseFactor(int id, double ease_factor) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawUpdate(
      '''
        UPDATE state
        SET ease_factor = ?
        WHERE question_id = ?
      ''', [ease_factor, id]
    );
  }

  Future<void> updateQuestionDueDate(int id, String due_date) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawUpdate(
      '''
        UPDATE state
        SET due_date = ?
        WHERE question_id = ?
      ''', [due_date, id]
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