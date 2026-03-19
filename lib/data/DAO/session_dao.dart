import '../../data/database_helper.dart';
import '../../models/session.dart';

class SessionDao {
  Future<List<Session>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('session');
    return result.map(Session.fromMap).toList();
  }

  Future<void> insert(Session session) async {
    final db = await DatabaseHelper.instance.database;

    await db.insert(
      'session', 
      session.toMap()
    );
  }

  Future<void> update(Session session) async {
    final db = await DatabaseHelper.instance.database;

    await db.update(
      'session', 
      session.toMap(),
      where: 'id = ?', 
      whereArgs: [session.id]
    );
  }

  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;

    await db.delete(
      'session', 
      where: 'id = ?', 
      whereArgs: [id]
    );
  }
}