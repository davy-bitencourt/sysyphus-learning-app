import '../../data/database_helper.dart';
import '../../models/revlog.dart';

class RevlogDao {
  Future<List<Revlog>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('revlog');
    return result.map(Revlog.fromMap).toList();
  }

  Future<Map<String, int>> getCountPerDay() async {
    final db = await DatabaseHelper.instance.database;

    final result = await db.rawQuery(
      '''
        SELECT data, COUNT(*) as count
        FROM revlog
        GROUP BY data
        ORDER BY data DESC
      '''
    );

    return { for (var row in result) row['data'] as String: row['count'] as int };
  }

  Future<void> insert(Revlog revlog) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('revlog', revlog.toMap());
  }
}