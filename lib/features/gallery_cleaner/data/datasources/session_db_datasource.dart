import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';

abstract class SessionDbDatasource {
  Future<void> saveSwipeStatus({
    required String mediaId,
    required String? albumId,
    required String status, // 'KEPT', 'PENDING_DELETION'
    required int fileSize,
    required int mediaType,
    required int createdAt,
  });
  Future<void> removeSwipeStatus(String mediaId);
  Future<List<String>> getPendingDeletionIds();
  Future<void> clearPendingDeletions();

  // --- Session Progress ---
  Future<void> saveSessionProgress(String albumId, int offset, int currentIndex);
  Future<({int offset, int currentIndex})> getSessionProgress(String albumId);
  Future<void> clearSessionProgress(String albumId);

  // --- ID Cache helpers ---
  Future<Set<String>> getAllSwipedIds();
  Future<void> clearKeptEntries();
}

class SessionDbDatasourceImpl implements SessionDbDatasource {
  final AppDatabase _db = AppDatabase.instance;

  @override
  Future<void> saveSwipeStatus({
    required String mediaId,
    required String? albumId,
    required String status,
    required int fileSize,
    required int mediaType,
    required int createdAt,
  }) async {
    final db = await _db.database;
    await db.insert(
      'media_items',
      {
        'id': mediaId,
        'album_id': albumId,
        'status': status,
        'file_size': fileSize,
        'media_type': mediaType,
        'created_at': createdAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> removeSwipeStatus(String mediaId) async {
    final db = await _db.database;
    await db.delete(
      'media_items',
      where: 'id = ?',
      whereArgs: [mediaId],
    );
  }

  @override
  Future<List<String>> getPendingDeletionIds() async {
    final db = await _db.database;
    final maps = await db.query(
      'media_items',
      columns: ['id'],
      where: 'status = ?',
      whereArgs: ['PENDING_DELETION'],
    );
    return List.generate(maps.length, (i) => maps[i]['id'] as String);
  }

  @override
  Future<void> clearPendingDeletions() async {
    final db = await _db.database;
    await db.delete(
      'media_items',
      where: 'status = ?',
      whereArgs: ['PENDING_DELETION'],
    );
  }

  // ── Session Progress ──────────────────────────────────────────────────────

  @override
  Future<void> saveSessionProgress(String albumId, int offset, int currentIndex) async {
    final db = await _db.database;
    await db.insert(
      'session_progress',
      {
        'album_id': albumId,
        'offset': offset,
        'current_index': currentIndex,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<({int offset, int currentIndex})> getSessionProgress(String albumId) async {
    final db = await _db.database;
    final result = await db.query(
      'session_progress',
      where: 'album_id = ?',
      whereArgs: [albumId],
      limit: 1,
    );
    if (result.isEmpty) return (offset: 0, currentIndex: 0);
    return (
      offset: result.first['offset'] as int,
      currentIndex: result.first['current_index'] as int,
    );
  }

  @override
  Future<void> clearSessionProgress(String albumId) async {
    final db = await _db.database;
    await db.delete(
      'session_progress',
      where: 'album_id = ?',
      whereArgs: [albumId],
    );
  }

  // ── ID Cache helpers ──────────────────────────────────────────────────────

  @override
  Future<Set<String>> getAllSwipedIds() async {
    final db = await _db.database;
    final maps = await db.query('media_items', columns: ['id']);
    return {for (final row in maps) row['id'] as String};
  }

  @override
  Future<void> clearKeptEntries() async {
    final db = await _db.database;
    await db.delete(
      'media_items',
      where: 'status = ?',
      whereArgs: ['KEPT'],
    );
  }
}
