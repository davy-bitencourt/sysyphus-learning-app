import '../../data/database_helper.dart';

class PackageDao {

  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    return db.rawQuery(
      '''
        SELECT id, session_id, title
        FROM package
      '''
    );
  }

  /* deve ser executada quando escolher o profile */
  Future<List<Map<String, dynamic>>> getProfilePackages(int profile_id) async {
    final db = await DatabaseHelper.instance.database;
    return db.rawQuery(
      '''
        SELECT package.title
        FROM profile
        INNER JOIN package
        ON profile.package_id = package.id
        WHERE profile.id = ?
      ''', [profile_id]
    );
  } 

  Future<void> insert(int? sessionId, String title) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawInsert(
      '''
        INSERT INTO package (session_id, title)
        VALUES (?, ?)
      ''', [sessionId, title]
    );
  }

  Future<void> update(int id, int? sessionId, String title) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawUpdate(
      '''
        UPDATE package
        SET session_id = ?, title = ?
        WHERE id = ?
      ''', [sessionId, title, id]
    );
  }

  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawDelete(
      '''
        DELETE FROM package
        WHERE id = ?
      ''', [id]
    );
  }
}