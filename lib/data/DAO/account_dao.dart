import 'package:sysyphus_learning_app/data/database_helper.dart';
import 'package:sysyphus_learning_app/data/DTO/account_dto.dart';

class AccountDao {
  Future<List<AccountDto>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query("account");
    return result.map(AccountDto.fromMap).toList();
  }

  Future<void> insert(AccountDto dto) async {
    final db = await DatabaseHelper.instance.database;

    await db.insert(
      "account", 
      dto.toMap() 
    );
  }
}