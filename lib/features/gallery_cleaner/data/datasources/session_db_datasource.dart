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
}
