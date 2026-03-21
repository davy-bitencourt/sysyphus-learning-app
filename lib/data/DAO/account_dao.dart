import 'package:sysyphus_learning_app/data/database_helper.dart';

class AccountDao {
  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    return db.query("account");
  }

  Future<void> insert(Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;

    await db.insert(
      "account", 
      data
    );
  }
}