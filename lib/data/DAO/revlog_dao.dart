import '../../data/database_helper.dart';

class RevlogDao {
  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    return db.query('revlog');
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
    
    return { 
      for (var row in result) row['data'] 
      as String: row['count'] 
      as int 
    };
  }

  Future<void> insert(Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;

    await db.insert(
      'revlog', 
      data
    );
  }
}