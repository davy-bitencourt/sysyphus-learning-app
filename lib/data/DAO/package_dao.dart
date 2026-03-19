import '../../data/database_helper.dart';
import '../../models/package.dart';

class PackageDao {
  Future<List<Package>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('package');
    return result.map(Package.fromMap).toList();
  }

  Future<void> insert(Package package) async {
    final db = await DatabaseHelper.instance.database;
    
    await db.insert(
      'package', 
      package.toMap()
    );
  }

  Future<void> update(Package package) async {
    final db = await DatabaseHelper.instance.database;
    
    await db.update(
      'package', 
      package.toMap(),
      where: 'id = ?', 
      whereArgs: [package.id]
    );
  }

  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;

    await db.delete(
      'package', 
      where: 'id = ?', 
      whereArgs: [id]
    );
  }
}