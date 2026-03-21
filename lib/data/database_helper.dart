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

    return await openDatabase(
      dir, 
      version: 1, 
      onConfigure: (db) async { await db.execute('PRAGMA foreign_keys = ON'); }, 
      onCreate: _createDB
    );
  }

  Future<void> _createDB(Database db, int version) async {
    /* batch() é um agrupador  de operações SQLite que, facilitando o debug, 
     * serão todos enviados e executados através do commit() */
    final batch = db.batch(); 

    batch.execute(
      """
        CREATE TABLE IF NOT EXISTS account (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          email TEXT UNIQUE,
          senha TEXT
        )
      """
    );

    batch.execute(
      """
        CREATE TABLE IF NOT EXISTS profile (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          account_id INTEGER NOT NULL,
          package_id INTEGER,
          name TEXT,
          FOREIGN KEY (account_id) REFERENCES account(id),
          FOREIGN KEY (package_id) REFERENCES package(id)
        )
      """
    );

    batch.execute(
      """
        CREATE TABLE IF NOT EXISTS session (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT,
          time_limit TEXT,
          total_q INTEGER
        )
      """
    );

    batch.execute(
      """
        CREATE TABLE IF NOT EXISTS templates (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          template JSON
        )
      """
    );

    batch.execute(
      """
        CREATE TABLE IF NOT EXISTS tag (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT
        )
      """
    );

    batch.execute(
      """
        CREATE TABLE IF NOT EXISTS package (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id INTEGER,
          title TEXT,
          FOREIGN KEY (session_id) REFERENCES session(id)
        )
      """
    );

    batch.execute(
      """
        CREATE TABLE IF NOT EXISTS question (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          package_id INTEGER,
          tag_id INTEGER,
          template_id INTEGER,
          enunciado TEXT,
          questions JSON,
          extra JSON,
          description TEXT,
          FOREIGN KEY (package_id) REFERENCES package(id),
          FOREIGN KEY (tag_id) REFERENCES tag(id),
          FOREIGN KEY (template_id) REFERENCES templates(id)
        )
      """
    );

    batch.execute(
      """
        CREATE TABLE IF NOT EXISTS revlog (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          question_id INTEGER NOT NULL,
          data TEXT,
          time TEXT,
          FOREIGN KEY (question_id) REFERENCES question(id)
        )
      """
    );

    batch.execute(
      """
        CREATE TABLE IF NOT EXISTS state (
          question_id INTEGER NOT NULL,
          state TEXT DEFAULT 'new',
          interval_days INTEGER DEFAULT 0,
          ease_factor REAL DEFAULT 2.4,
          due_date TEXT DEFAULT CURRENT_DATE,
          FOREIGN KEY (question_id) REFERENCES question(id)
        )
      """
    );

    await batch.commit();
  }
}