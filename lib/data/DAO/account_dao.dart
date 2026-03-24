import '../../data/database_helper.dart';
import '../../data/DTO/account_dto.dart';

class AccountDao {

  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    return db.rawQuery(
      '''
        SELECT id, email, senha
        FROM account
      '''
    );
  }

  Future<void> insert(AccountDto dto) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawInsert(
      '''
        INSERT INTO account (email, senha)
        VALUES (?, ?)
      ''', [dto.email, dto.senha]
    );
  }

  Future<void> update(int id, AccountDto dto) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawUpdate(
      '''
        UPDATE account
        SET email = ?, senha = ?
        WHERE id = ?
      ''', [dto.email, dto.senha, id]
    );
  }

  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawDelete(
      '''
        DELETE FROM account
        WHERE id = ?
      ''', [id]
    );
  }
}