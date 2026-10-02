import 'package:sqflite/sqflite.dart';
import 'dart:io';

class DatabaseHelper{
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    print('DB GETTER 1');

    if (_database != null) {
      print('DB GETTER 2 - database existe');
      return _database!;
    }

    print('DB GETTER 3 - chamando _initDB');
    _database = await _initDB('sysy_app.db');

    print('DB GETTER 4 - _initDB terminou');
    return _database!;
  }

  Future<Database> _initDB(String file_nane) async {
    final dir_db = await getDatabasesPath();
    print('DB: $dir_db');    

    final String dir;
    if(Platform.isWindows){
      dir = '$dir_db\\$file_nane';
    } else {
      dir = '$dir_db/$file_nane';
    }

    return await openDatabase(
      dir, 
      version: 3, 
      onConfigure: (db) async { await db.execute('PRAGMA foreign_keys = ON'); }, 
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  /* v2: o histórico de revisões deixou de ser preso às questões.
   * O revlog perdeu a FOREIGN KEY para question, então apagar uma questão
   * (ou um pacote) não apaga mais o histórico e o heatmap se mantém.
   * SQLite não altera constraints, por isso a tabela é recriada.
   * Obs.: o sqflite já roda o onUpgrade dentro de uma transação. */
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE revlog_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          question_id INTEGER NOT NULL,
          data TEXT,
          time TEXT
        )
      ''');
      await db.execute('''
        INSERT INTO revlog_new (id, question_id, data, time)
        SELECT id, question_id, data, time FROM revlog
      ''');
      await db.execute('DROP TABLE revlog');
      await db.execute('ALTER TABLE revlog_new RENAME TO revlog');
    }
    // v3: sessão guarda o filtro por tag (JSON: [{"tag_id": 1, "quantity": 10}]).
    // time_limit: minutos (texto) ou NULL = sem limite. total_q: total de questões.
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE session ADD COLUMN tag_filters TEXT');
    }
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
          total_q INTEGER,
          tag_filters TEXT
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
          time TEXT
        )
      """
    );

    batch.execute(
      """
        CREATE TABLE IF NOT EXISTS state (
          question_id INTEGER PRIMARY KEY,
          state TEXT DEFAULT 'new',
          interval_days INTEGER DEFAULT 0,
          ease_factor REAL DEFAULT 2.4,
          due_date TEXT DEFAULT CURRENT_DATE,
          FOREIGN KEY (question_id) REFERENCES question(id) ON DELETE CASCADE
        );
      """
    );

    await batch.commit();
  }
}