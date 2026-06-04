import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/datasources/media_local_datasource.dart';
import '../../data/datasources/session_db_datasource.dart';
import 'gallery_swiper_state.dart';

// Riverpod Providers definition
final mediaLocalDatasourceProvider = Provider<MediaLocalDatasource>((ref) {
  return MediaLocalDatasourceImpl();
});

final sessionDbDatasourceProvider = Provider<SessionDbDatasource>((ref) {
  return SessionDbDatasourceImpl();
});

final swiperNotifierProvider = StateNotifierProvider<SwiperNotifier, SwiperState>((ref) {
  final mediaDatasource = ref.watch(mediaLocalDatasourceProvider);
  final sessionDbDatasource = ref.watch(sessionDbDatasourceProvider);
  return SwiperNotifier(mediaDatasource, sessionDbDatasource);
});

class SwiperNotifier extends StateNotifier<SwiperState> {
  final MediaLocalDatasource _mediaDatasource;
  final SessionDbDatasource _sessionDbDatasource;
  int _currentOffset = 0;
  static const int _batchSize = 10;
  static const int _pendingDeletionWarningThreshold = 1000;

  SwiperNotifier(this._mediaDatasource, this._sessionDbDatasource)
      : super(SwiperState(activeQueue: Queue())) {
    _initialize();
  }

  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true);
    final hasPermission = await _mediaDatasource.requestPermissions();
    if (!hasPermission) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Izin akses galeri ditolak',
      );
      return;
    }

    List<AssetPathEntity> albums = [];
    AssetPathEntity? selectedAlbum;
    int totalCount = 0;
    try {
      albums = await _mediaDatasource.fetchAlbums();
      if (albums.isNotEmpty) {
        selectedAlbum = albums.first;
        totalCount = await selectedAlbum.assetCountAsync;
      }
    } catch (e) {
      debugPrint('Failed to fetch albums: $e');
    }

    final pendingIds = await _sessionDbDatasource.getPendingDeletionIds();
    state = state.copyWith(
      albums: albums,
      selectedAlbum: selectedAlbum,
      totalAssetCount: totalCount,
      currentIndex: 0,
      pendingDeletionCount: pendingIds.length,
    );
    await loadNextBatch();
  }

  /// Changes the currently active folder and re-initializes swiper queue
  Future<void> changeAlbum(AssetPathEntity album) async {
    state = state.copyWith(
      isLoading: true,
      selectedAlbum: album,
      activeQueue: Queue(), // Clear current deck
      currentIndex: 0,
    );
    _currentOffset = 0;
    
    final totalCount = await album.assetCountAsync;
    state = state.copyWith(
      totalAssetCount: totalCount,
    );
    
    await loadNextBatch();
  }

  /// Paginates local gallery and loads next batch to active UI deck queue
  Future<void> loadNextBatch() async {
    if (state.isLoading && state.activeQueue.isNotEmpty) return;

    try {
      final assets = await _mediaDatasource.fetchRecentAssets(
        limit: _batchSize,
        offset: _currentOffset,
        album: state.selectedAlbum,
      );

      if (assets.isNotEmpty) {
        _currentOffset += assets.length;
        final newQueue = Queue<AssetEntity>.from(state.activeQueue)..addAll(assets);
        state = state.copyWith(activeQueue: newQueue, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat batch media',
      );
    }
  }

  /// Handles Swipe Action (Kiri: Delete, Kanan: Kept)
  Future<void> swipeCard({required bool isDelete}) async {
    if (state.activeQueue.isEmpty) return;

    final swipedAsset = state.activeQueue.removeFirst();
    final newPendingCount = state.pendingDeletionCount + (isDelete ? 1 : 0);
    
    // Instant UI updates and increments current index
    state = state.copyWith(
      activeQueue: Queue<AssetEntity>.from(state.activeQueue),
      lastSwipedAsset: swipedAsset,
      lastSwipeWasDelete: isDelete,
      currentIndex: state.currentIndex + 1,
      pendingDeletionCount: newPendingCount,
    );

    // Save status to SQLite asynchronously (background task logic)
    final int size = await _getAssetSize(swipedAsset);

    try {
      await _sessionDbDatasource.saveSwipeStatus(
        mediaId: swipedAsset.id,
        albumId: null,
        status: isDelete ? 'PENDING_DELETION' : 'KEPT',
        fileSize: size,
        mediaType: swipedAsset.typeInt,
        createdAt: swipedAsset.createDateTime.millisecondsSinceEpoch,
      );

      // Check soft warning limit for pending deletions
      if (newPendingCount >= _pendingDeletionWarningThreshold) {
        final currentWarning = state.storageWarning;
        if (currentWarning == null || currentWarning.contains('Antrean hapus')) {
          state = state.copyWith(
            storageWarning: 'Antrean hapus mencapai $newPendingCount foto. Disarankan untuk segera menghapus permanen guna menghemat penyimpanan.',
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to save swipe status: $e');
      String warning = 'Gagal menyimpan status ke database.';
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('full') || errStr.contains('no space') || errStr.contains('13')) {
        warning = 'Memori penyimpanan HP Anda penuh! Silakan lakukan Hapus Permanen terlebih dahulu.';
      }
      state = state.copyWith(storageWarning: warning);
    }

    // MEMORY OPTIMIZATION: Clear Flutter imageCache memory pools
    // This allows Dart's GC to immediately reclaim memory from discarded byte arrays
    imageCache.clearLiveImages(); 
    imageCache.clear();

    // Prefetch if queue is running low
    if (state.activeQueue.length < 3) {
      loadNextBatch();
    }
  }

  /// Helper to fetch file size in a non-blocking way
  Future<int> _getAssetSize(AssetEntity asset) async {
    try {
      final file = await asset.file;
      return file?.lengthSync() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Restores the last swiped card to the top of the stack and removes its DB record
  Future<void> undoLastSwipe() async {
    if (state.lastSwipedAsset == null) return;
    
    final restoredAsset = state.lastSwipedAsset!;
    final newQueue = Queue<AssetEntity>.from(state.activeQueue);
    
    newQueue.addFirst(restoredAsset);
    
    final wasDelete = state.lastSwipeWasDelete ?? false;
    final newCount = (state.pendingDeletionCount - (wasDelete ? 1 : 0)).clamp(0, double.infinity).toInt();

    // Revert SQLite status record
    await _sessionDbDatasource.removeSwipeStatus(restoredAsset.id);

    // Dynamic warning management
    String? newWarning = state.storageWarning;
    if (newCount < _pendingDeletionWarningThreshold &&
        newWarning != null &&
        newWarning.contains('Antrean hapus')) {
      newWarning = null;
    }

    state = state.copyWith(
      activeQueue: newQueue,
      lastSwipedAsset: null,
      lastSwipeWasDelete: null,
      currentIndex: (state.currentIndex - 1).clamp(0, state.totalAssetCount),
      pendingDeletionCount: newCount,
      storageWarning: newWarning,
    );
  }

  /// Manually clears/dismisses the active storage warning banner
  void dismissStorageWarning() {
    state = state.copyWith(storageWarning: null);
  }

  /// Permanently deletes all photos tracked in the PENDING_DELETION table
  /// by popping up the native OS delete verification dialog
  Future<void> executeFinalDeletion() async {
    final ids = await _sessionDbDatasource.getPendingDeletionIds();
    if (ids.isEmpty) return;

    try {
      // Trigger Native OS Pop-Up for photo deletion permission
      final List<String> resultIds = await PhotoManager.editor.deleteWithIds(ids);
      if (resultIds.isNotEmpty) {
        // Delete items from our SQLite session index upon successful native deletion
        await _sessionDbDatasource.clearPendingDeletions();
        
        // Reset current index offset based on deletions
        state = state.copyWith(
          totalAssetCount: (state.totalAssetCount - resultIds.length).clamp(0, double.infinity).toInt(),
          currentIndex: (state.currentIndex - resultIds.length).clamp(0, double.infinity).toInt(),
          pendingDeletionCount: 0,
          storageWarning: null,
        );
      }
    } catch (e) {
      debugPrint('Error executing final deletion: $e');
    }
  }
}
