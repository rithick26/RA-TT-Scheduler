import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  factory DbHelper() => _instance;
  DbHelper._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    sqfliteFfiInit();
    var databaseFactory = databaseFactoryFfi;

    final dbPath = await getDbPath();

    return await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _onCreate,
      ),
    );
  }

  Future<String> getDbPath() async {
    final appData = Platform.environment['APPDATA']!;

    final dbFolder = Directory(
      p.join(appData, 'TimetableScheduler', 'Database'),
    );

    await dbFolder.create(recursive: true);

    return p.join(dbFolder.path, 'timetable.db');
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Teachers table
    await db.execute('''
      CREATE TABLE teachers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        designation TEXT NOT NULL
      )
    ''');

    // 2. Subjects table
    await db.execute('''
      CREATE TABLE subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        course_code TEXT NOT NULL UNIQUE,
        course_title TEXT NOT NULL,
        year INTEGER NOT NULL,
        semester INTEGER NOT NULL,
        subject_type TEXT NOT NULL,
        faculty1_id INTEGER NOT NULL,
        faculty2_id INTEGER,
        faculty3_id INTEGER,
        FOREIGN KEY (faculty1_id) REFERENCES teachers(id) ON DELETE RESTRICT,
        FOREIGN KEY (faculty2_id) REFERENCES teachers(id) ON DELETE SET NULL,
        FOREIGN KEY (faculty3_id) REFERENCES teachers(id) ON DELETE SET NULL
      )
    ''');

    // 3. History records table
    await db.execute('''
      CREATE TABLE history_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        date_generated TEXT NOT NULL,
        time_generated TEXT NOT NULL,
        created_timestamp TEXT NOT NULL,
        pdf_path TEXT NOT NULL,
        excel_path TEXT NOT NULL
      )
    ''');

    // 4. Timetable inputs table (associated with history_records)
    await db.execute('''
      CREATE TABLE timetable_inputs (
        history_id INTEGER NOT NULL,
        subject_id INTEGER NOT NULL,
        hours_per_week INTEGER NOT NULL,
        PRIMARY KEY (history_id, subject_id),
        FOREIGN KEY (history_id) REFERENCES history_records(id) ON DELETE CASCADE,
        FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE CASCADE
      )
    ''');

    // 5. Timetable slots table (associated with history_records)
    await db.execute('''
      CREATE TABLE timetable_slots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        history_id INTEGER NOT NULL,
        year INTEGER NOT NULL,
        day INTEGER NOT NULL,
        period INTEGER NOT NULL,
        subject_id INTEGER,
        FOREIGN KEY (history_id) REFERENCES history_records(id) ON DELETE CASCADE,
        FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE CASCADE
      )
    ''');
  }

  // Backup the database to a user-selected path
  Future<void> backupDatabase(String targetPath) async {
    final dbPath = await getDbPath();

    // Close the current DB connection first to ensure consistency
    if (_db != null) {
      await _db!.close();
      _db = null;
    }

    final originalFile = File(dbPath);
    if (await originalFile.exists()) {
      // Create directories on target path if not exists
      final targetFile = File(targetPath);
      final parentDir = targetFile.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }
      await originalFile.copy(targetPath);
    }

    // Reopen database
    _db = await _initDb();
  }

  // Restore the database from a file path
  Future<void> restoreDatabase(String sourcePath) async {
    final dbPath = await getDbPath();

    // Close the current DB connection
    if (_db != null) {
      await _db!.close();
      _db = null;
    }

    final sourceFile = File(sourcePath);
    if (await sourceFile.exists()) {
      final destFile = File(dbPath);
      // Ensure folder exists
      final parentDir = destFile.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }
      // Copy backup file over current db file
      await sourceFile.copy(dbPath);
    }

    // Reopen database
    _db = await _initDb();
  }

  // Closes the database helper connection (useful for testing)
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
