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

    if (limit > 60) {
      limit = 60;
    }

    return db.rawQuery(
      '''
        SELECT q.id, q.template_id, q.tag_id, q.questions, s.state, s.interval_days, s.ease_factor, s.due_date
        FROM question q
        LEFT JOIN state s ON s.question_id = q.id
        WHERE q.package_id = ?
        ORDER BY RANDOM()
        LIMIT ?
      ''', [packageId, limit]
    );
  }

  /* lista completa do pacote, ordenada, para a tela de gerenciamento */
  Future<List<Map<String, dynamic>>> getAllByPackage(int packageId) async {
    final db = await DatabaseHelper.instance.database;
    return db.rawQuery(
      '''
        SELECT q.id, q.template_id, q.tag_id, q.questions, s.state, s.interval_days, s.ease_factor, s.due_date
        FROM question q
        LEFT JOIN state s ON s.question_id = q.id
        WHERE q.package_id = ?
        ORDER BY q.id
      ''', [packageId]
    );
  }

  /* contagens do card da Home:
   *  'new' = questões novas, nunca vistas (state 'new' ou sem linha de state)
   *  'due' = questões para revisar: 'review' vencidas (due_date <= hoje) e as
   *          'neutral' (esquecidas, voltam para revisão na hora) */
  Future<Map<String, int>> getStudyCounts(String today) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      '''
        SELECT
          COALESCE(SUM(CASE WHEN s.state IS NULL OR s.state = 'new' THEN 1 ELSE 0 END), 0) AS new_count,
          COALESCE(SUM(CASE WHEN (s.state = 'review' AND s.due_date <= ?) OR s.state = 'neutral' THEN 1 ELSE 0 END), 0) AS due_count
        FROM question q
        LEFT JOIN state s ON s.question_id = q.id
      ''', [today]
    );
    final row = rows.first;
    return {
      'new': (row['new_count'] as num?)?.toInt() ?? 0,
      'due': (row['due_count'] as num?)?.toInt() ?? 0,
    };
  }

  Future<int> insert(QuestionDto dto) async {
    final db = await DatabaseHelper.instance.database;

    final id = await db.rawInsert(
      '''
        INSERT INTO question (package_id, tag_id, template_id, questions)
        VALUES (?, ?, ?, ?)
      ''', [dto.packageId, dto.tagId, dto.templateId, dto.questions]
    );

    /* garante que toda questão nova já tenha uma linha de estado,
     * evitando que o LEFT JOIN em getByPackage volte tudo nulo */
    await db.rawInsert(
      '''
        INSERT INTO state (question_id)
        VALUES (?)
      ''', [id]
    );

    return id;
  }

  Future<void> updateQuestion(int id, QuestionDto dto) async {
    final db = await DatabaseHelper.instance.database;

    await db.rawUpdate(
      '''
        UPDATE question
        SET package_id = ?, tag_id = ?, template_id = ?, questions = ?
        WHERE id = ?
      ''', [dto.packageId, dto.tagId, dto.templateId, dto.questions, id]
    );
  }

  /* alterações de estado */
  Future<void> updateStateReview(int questionId, int intervalDays, double easeFactor, String dueDate) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawUpdate(
      '''
        UPDATE state
        SET state = 'review', interval_days = ?, ease_factor = ?, due_date = ?
        WHERE question_id = ?
      ''', [intervalDays, easeFactor, dueDate, questionId]
    );
  }

  Future<void> updateStateNeutral(int questionId) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawUpdate(
      '''
        UPDATE state
        SET state = 'neutral', interval_days = 0, ease_factor = 2.4, due_date = CURRENT_DATE
        WHERE question_id = ?
      ''', [questionId]
    );
  }

  /* apaga a questão e o estado dela. O histórico (revlog) é mantido de
   * propósito: ele alimenta o heatmap e não depende mais da questão. */
  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;

    await db.transaction((txn) async {
      await txn.rawDelete('DELETE FROM state WHERE question_id = ?', [id]);
      await txn.rawDelete('DELETE FROM question WHERE id = ?', [id]);
    });
  }

  /* apaga o pacote inteiro: estado e questões dele (o histórico fica), solta
   * qualquer profile que apontava pra ele e por fim remove o pacote.
   * Tudo numa transação: ou apaga tudo, ou não apaga nada. */
  Future<void> deletePackageCascade(int packageId) async {
    final db = await DatabaseHelper.instance.database;

    await db.transaction((txn) async {
      final ids = 'SELECT id FROM question WHERE package_id = ?';
      await txn.rawDelete('DELETE FROM state WHERE question_id IN ($ids)', [packageId]);
      await txn.rawDelete('DELETE FROM question WHERE package_id = ?', [packageId]);
      await txn.rawUpdate('UPDATE profile SET package_id = NULL WHERE package_id = ?', [packageId]);
      await txn.rawDelete('DELETE FROM package WHERE id = ?', [packageId]);
    });
  }
}
