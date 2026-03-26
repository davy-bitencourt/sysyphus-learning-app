import 'package:sysyphus_learning_app/data/database_helper.dart';

class ProfileDao {

  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    return db.rawQuery(
      '''
        SELECT id, account_id, package_id, name
        FROM profile
      '''
    );
  }

  Future<List<Map<String, dynamic>>> getAllProfiles() async {
    final db = await DatabaseHelper.instance.database;
    return db.rawQuery(
      '''
        SELECT id, name
        FROM profile
      '''
    );
  }

  Future<void> insert(int accountId, int? packageId, String name) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawInsert(
      '''
        INSERT INTO profile (account_id, package_id, name)
        VALUES (?, ?, ?)
      ''', [accountId, packageId, name]
    );
  }

  Future<void> update(int id, int accountId, int? packageId, String name) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawUpdate(
      '''
        UPDATE profile
        SET account_id = ?, package_id = ?, name = ?
        WHERE id = ?
      ''', [accountId, packageId, name, id]
    );
  }

  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawDelete(
      '''
        DELETE FROM profile
        WHERE id = ?
      ''', [id]
    );
  }
}