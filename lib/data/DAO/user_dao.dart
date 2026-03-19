import 'package:sysyphus_learning_app/data/database_helper.dart';

class UserDao {
  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    return db.query("user");
  }

  Future<void> insert(Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;

    await db.insert(
      "users", 
      data
    );
  }
}