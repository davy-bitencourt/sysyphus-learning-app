import '../../data/database_helper.dart';
import '../../models/question.dart';

class QuestionDao {
  Future<List<Question>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('question');
    return result.map(Question.fromMap).toList();
  }

  Future<List<Question>> getByPackage(int packageId) async {
    final db = await DatabaseHelper.instance.database;

    final result = await db.query(
      'question', 
      where: 'package_id = ?', 
      whereArgs: [packageId]
    );

    return result.map(Question.fromMap).toList();
  }

  Future<void> insert(Question question) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('question', question.toMap());
  }

  Future<void> update(Question question) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('question', question.toMap(),
      where: 'id = ?', whereArgs: [question.id]);
  }

  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('question', where: 'id = ?', whereArgs: [id]);
  }
}