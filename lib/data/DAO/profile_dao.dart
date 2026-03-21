import 'package:sysyphus_learning_app/data/database_helper.dart';

class ProfileDao {
  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    return db.query("profile");
  }

  Future<void> insert(Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;

    await db.insert(
      "profile", 
      data
    );
  }
}