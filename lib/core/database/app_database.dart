import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('picclaw_gallery.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Enable Foreign Key support
    await db.execute('PRAGMA foreign_keys = ON');

    // Create Albums table
    await db.execute('''
      CREATE TABLE albums (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        path TEXT
      )
    ''');

    // Create Media Items table
    await db.execute('''
      CREATE TABLE media_items (
        id TEXT PRIMARY KEY,
        album_id TEXT,
        status TEXT CHECK(status IN ('UNPROCESSED', 'KEPT', 'PENDING_DELETION')) DEFAULT 'UNPROCESSED',
        file_size INTEGER NOT NULL,
        media_type INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (album_id) REFERENCES albums(id) ON DELETE SET NULL
      )
    ''');

    // Create Indexes for faster swiping query performance
    await db.execute('CREATE INDEX idx_media_status ON media_items(status)');
    await db.execute('CREATE INDEX idx_media_album ON media_items(album_id)');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
    }
  }
}
