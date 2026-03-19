import 'package:sysyphus_learning_app/data/database_helper.dart';
import 'package:sysyphus_learning_app/models/user.dart';

class UserDao {
  Future<List<User>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query("user");
    return result.map(User.fromMap).toList();
  }

  Future<void> insert(User user) async {
    final db = await DatabaseHelper.instance.database;

    await db.insert(
      "users", 
      user.toMap()
    );
  }
}