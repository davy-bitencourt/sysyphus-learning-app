import 'package:sqflite/sqflite.dart';
import 'dart:io';

class DatabaseHelper{
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if(_database != null) return _database!;
    _database = await _initDB('sysy_app.db');
    return _database!; 
  }

  Future<Database> _initDB(String file_nane) async {
    final dir_db = await getDatabasesPath();
    
    final String dir;
    if(Platform.isWindows){
      dir = '$dir_db\\$file_nane';
    } else {
      dir = '$dir_db/$file_nane';
    }

    return await openDatabase(dir, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute(
      """
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL,
          email TEXT UNIQUE,
          password TEXT
        )
      """
    );
  }
}