import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

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

  /// In-memory cache of all IDs already swiped (KEPT + PENDING_DELETION).
  /// Used to filter out already-processed photos from each loaded batch,
  /// ensuring resume works correctly even when the offset drifts due to deletions.
  final Set<String> _swipedIdsCache = {};

  /// Tracks the batch start offset for each asset currently in activeQueue.
  final Queue<int> _itemBatchOffsets = Queue();
  int? _lastSwipedBatchOffset;

  SwiperNotifier(this._mediaDatasource, this._sessionDbDatasource)
      : super(SwiperState(activeQueue: Queue())) {
    _initialize();
  }

  String _albumKey(AssetPathEntity? album) => album?.id ?? 'all_recent';

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
      albums = await _mediaDatasource.fetchAlbums(
        startDate: state.dateFilter?.start,
        endDate: state.dateFilter?.end,
      );
      if (albums.isNotEmpty) {
        selectedAlbum = albums.first;
        totalCount = await selectedAlbum.assetCountAsync;
      }
    } catch (e) {
      debugPrint('Failed to fetch albums: $e');
    }

    final pendingIds = await _sessionDbDatasource.getPendingDeletionIds();

    // ── Session Resume ────────────────────────────────────────────────────
    // Load all swiped IDs into memory cache (O(1) lookups for batch filtering)
    _swipedIdsCache
      ..clear()
      ..addAll(await _sessionDbDatasource.getAllSwipedIds());

    // Restore the last saved position for this album
    final albumKey = _albumKey(selectedAlbum);
    final progress = await _sessionDbDatasource.getSessionProgress(albumKey);
    _currentOffset = progress.offset;
    final resumedIndex = progress.currentIndex;
    // ─────────────────────────────────────────────────────────────────────

    state = state.copyWith(
      albums: albums,
      selectedAlbum: selectedAlbum,
      totalAssetCount: totalCount,
      currentIndex: resumedIndex,
      pendingDeletionCount: pendingIds.length,
      resumedFromIndex: resumedIndex, // Signal UI to show resume snackbar
    );
    await loadNextBatch();
  }

  /// Changes the currently active folder and re-initializes swiper queue
  Future<void> changeAlbum(AssetPathEntity album) async {
    state = state.copyWith(
      isLoading: true,
      selectedAlbum: album,
      activeQueue: Queue(),
      currentIndex: 0,
      resumedFromIndex: 0,
    );

    _itemBatchOffsets.clear();
    _lastSwipedBatchOffset = null;

    // Rebuild ID cache for the new album context
    _swipedIdsCache
      ..clear()
      ..addAll(await _sessionDbDatasource.getAllSwipedIds());

    // Restore saved position for the new album
    final albumKey = _albumKey(album);
    final progress = await _sessionDbDatasource.getSessionProgress(albumKey);
    _currentOffset = progress.offset;
    final resumedIndex = progress.currentIndex;

    final totalCount = await album.assetCountAsync;
    state = state.copyWith(
      totalAssetCount: totalCount,
      currentIndex: resumedIndex,
      resumedFromIndex: resumedIndex,
    );

    await loadNextBatch();
  }

  /// Applies a date filter and re-initializes the gallery
  Future<void> applyDateFilter(DateTimeRange? range) async {
    state = state.copyWith(
      isLoading: true,
      dateFilter: range, // Can be null to clear filter
      activeQueue: Queue(),
      currentIndex: 0,
      resumedFromIndex: 0,
    );

    _currentOffset = 0;
    _itemBatchOffsets.clear();
    _lastSwipedBatchOffset = null;

    try {
      final albums = await _mediaDatasource.fetchAlbums(
        startDate: range?.start,
        endDate: range?.end,
      );
      
      AssetPathEntity? selectedAlbum;
      int totalCount = 0;
      if (albums.isNotEmpty) {
        // Try to keep the same album selected if it still exists in the filtered results
        final currentSelectedId = state.selectedAlbum?.id;
        selectedAlbum = albums.firstWhere(
          (a) => a.id == currentSelectedId,
          orElse: () => albums.first,
        );
        totalCount = await selectedAlbum.assetCountAsync;
      }

      state = state.copyWith(
        albums: albums,
        selectedAlbum: selectedAlbum,
        totalAssetCount: totalCount,
      );
    } catch (e) {
      debugPrint('Failed to fetch filtered albums: $e');
    }

    await loadNextBatch();
  }

  /// Paginates local gallery and loads next batch to active UI deck queue.
  /// Automatically skips photos already in _swipedIdsCache.
  Future<void> loadNextBatch() async {
    if (state.isLoading && state.activeQueue.isNotEmpty) return;

    try {
      // Try up to 5 successive batches to find unswiped photos
      // (handles the case where an entire batch is already-swiped)
      for (int attempt = 0; attempt < 5; attempt++) {
        final assets = await _mediaDatasource.fetchRecentAssets(
          limit: _batchSize,
          offset: _currentOffset,
          album: state.selectedAlbum,
        );

        if (assets.isEmpty) {
          // Reached end of gallery
          state = state.copyWith(isLoading: false);
          return;
        }

        _currentOffset += assets.length;

        // Filter out already-swiped photos using in-memory cache
        final filtered = assets.where((a) => !_swipedIdsCache.contains(a.id)).toList();

        if (filtered.isNotEmpty) {
          final newQueue = Queue<AssetEntity>.from(state.activeQueue)..addAll(filtered);
          _itemBatchOffsets.addAll(List.filled(filtered.length, attempt == 0 ? _currentOffset - assets.length : _currentOffset - assets.length));
          state = state.copyWith(activeQueue: newQueue, isLoading: false);
          return;
        }
        // All items in this batch were already swiped → try next batch
      }
      state = state.copyWith(isLoading: false);
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
    final swipedBatchOffset = _itemBatchOffsets.isNotEmpty ? _itemBatchOffsets.removeFirst() : _currentOffset;
    _lastSwipedBatchOffset = swipedBatchOffset;
    
    final newPendingCount = state.pendingDeletionCount + (isDelete ? 1 : 0);
    final newIndex = state.currentIndex + 1;

    // Instant UI update
    state = state.copyWith(
      activeQueue: Queue<AssetEntity>.from(state.activeQueue),
      lastSwipedAsset: swipedAsset,
      lastSwipeWasDelete: isDelete,
      currentIndex: newIndex,
      pendingDeletionCount: newPendingCount,
    );

    // Add to in-memory cache immediately so the photo doesn't show again
    _swipedIdsCache.add(swipedAsset.id);

    // Save swipe status + progress to SQLite asynchronously
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

      // Persist session progress so we resume from here next launch
      // We save the exact batch offset of the NEXT photo in the queue
      final offsetToSave = _itemBatchOffsets.isNotEmpty ? _itemBatchOffsets.first : _currentOffset;
      await _sessionDbDatasource.saveSessionProgress(
        _albumKey(state.selectedAlbum),
        offsetToSave,
        newIndex,
      );

      // Check soft warning limit
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
    
    final restoredBatchOffset = _lastSwipedBatchOffset ?? (_currentOffset > 10 ? _currentOffset - 10 : 0);
    _itemBatchOffsets.addFirst(restoredBatchOffset);

    final wasDelete = state.lastSwipeWasDelete ?? false;
    final newCount = (state.pendingDeletionCount - (wasDelete ? 1 : 0)).clamp(0, double.infinity).toInt();
    final newIndex = (state.currentIndex - 1).clamp(0, state.totalAssetCount);

    // Remove from in-memory cache so the photo can be re-seen
    _swipedIdsCache.remove(restoredAsset.id);

    // Revert SQLite status record
    await _sessionDbDatasource.removeSwipeStatus(restoredAsset.id);

    // Update saved session progress
    final offsetToSave = _itemBatchOffsets.isNotEmpty ? _itemBatchOffsets.first : _currentOffset;
    await _sessionDbDatasource.saveSessionProgress(
      _albumKey(state.selectedAlbum),
      offsetToSave,
      newIndex,
    );

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
      currentIndex: newIndex,
      pendingDeletionCount: newCount,
      storageWarning: newWarning,
    );
  }

  /// Resets the swiper back to photo #1.
  /// Only clears KEPT entries — PENDING_DELETION photos stay in queue & cache.
  Future<void> resetProgress() async {
    final albumKey = _albumKey(state.selectedAlbum);

    // Remove KEPT entries from SQLite and cache (PENDING_DELETION stays)
    await _sessionDbDatasource.clearKeptEntries();
    _swipedIdsCache.removeWhere((id) {
      // Keep only PENDING_DELETION IDs in cache; KEPT IDs are being reset
      // We don't have status info in cache, so we rebuild from the remaining SQLite
      return true; // clear all, then re-add pending below
    });

    // Rebuild cache from remaining SQLite records (only PENDING_DELETION now)
    _swipedIdsCache.addAll(await _sessionDbDatasource.getAllSwipedIds());

    // Clear session progress for this album
    await _sessionDbDatasource.clearSessionProgress(albumKey);

    // Reset offset and count
    _currentOffset = 0;
    _itemBatchOffsets.clear();
    _lastSwipedBatchOffset = null;
    final pendingIds = await _sessionDbDatasource.getPendingDeletionIds();

    state = state.copyWith(
      activeQueue: Queue(),
      currentIndex: 0,
      resumedFromIndex: 0,
      lastSwipedAsset: null,
      lastSwipeWasDelete: null,
      pendingDeletionCount: pendingIds.length,
      storageWarning: null,
    );

    await loadNextBatch();
  }

  /// Manually clears/dismisses the active storage warning banner
  void dismissStorageWarning() {
    state = state.copyWith(storageWarning: null);
  }

  /// Permanently deletes all photos tracked in the PENDING_DELETION table
  Future<void> executeFinalDeletion() async {
    final ids = await _sessionDbDatasource.getPendingDeletionIds();
    if (ids.isEmpty) return;

    try {
      final List<String> resultIds = await PhotoManager.editor.deleteWithIds(ids);
      if (resultIds.isNotEmpty) {
        // Remove from SQLite and cache
        await _sessionDbDatasource.clearPendingDeletions();
        for (final id in resultIds) {
          _swipedIdsCache.remove(id);
        }

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

  /// Fetches actual AssetEntity objects for all current pending deletion IDs
  Future<List<AssetEntity>> getPendingDeletionAssets() async {
    final ids = await _sessionDbDatasource.getPendingDeletionIds();
    if (ids.isEmpty) return [];
    try {
      final List<AssetEntity> results = [];
      for (final id in ids) {
        final entity = await AssetEntity.fromId(id);
        if (entity != null) results.add(entity);
      }
      return results;
    } catch (e) {
      debugPrint('Failed to get asset list with IDs: $e');
      return [];
    }
  }

  /// Restores multiple assets from the deletion queue
  Future<void> restoreAssetsFromDeletion(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      // Fetch AssetEntity objects & remove from SQLite + cache
      final List<AssetEntity> restoredAssets = [];
      for (final id in ids) {
        await _sessionDbDatasource.removeSwipeStatus(id);
        _swipedIdsCache.remove(id); // Remove from cache → can reappear in swiper

        final entity = await AssetEntity.fromId(id);
        if (entity != null) restoredAssets.add(entity);
      }

      // Prepend restored photos to the front of the active deck queue
      // Reversed so they appear in original order at the top of the stack
      final newQueue = Queue<AssetEntity>.from(state.activeQueue);
      for (final asset in restoredAssets.reversed) {
        newQueue.addFirst(asset);
        _itemBatchOffsets.addFirst(_currentOffset > 10 ? _currentOffset - 10 : 0); // Approximate offset for restored assets
      }

      final pendingIds = await _sessionDbDatasource.getPendingDeletionIds();
      final newCount = pendingIds.length;

      String? newWarning = state.storageWarning;
      if (newCount < _pendingDeletionWarningThreshold &&
          newWarning != null &&
          newWarning.contains('Antrean hapus')) {
        newWarning = null;
      }

      state = state.copyWith(
        activeQueue: newQueue,
        pendingDeletionCount: newCount,
        storageWarning: newWarning,
      );
    } catch (e) {
      debugPrint('Error restoring assets: $e');
    }
  }


  /// Permanently deletes specific photo IDs
  Future<void> executeDeletionForIds(List<String> ids) async {
    if (ids.isEmpty) return;

    try {
      final List<String> resultIds = await PhotoManager.editor.deleteWithIds(ids);
      if (resultIds.isNotEmpty) {
        for (final id in resultIds) {
          await _sessionDbDatasource.removeSwipeStatus(id);
          _swipedIdsCache.remove(id);
        }

        final pendingIds = await _sessionDbDatasource.getPendingDeletionIds();

        state = state.copyWith(
          totalAssetCount: (state.totalAssetCount - resultIds.length).clamp(0, double.infinity).toInt(),
          currentIndex: (state.currentIndex - resultIds.length).clamp(0, double.infinity).toInt(),
          pendingDeletionCount: pendingIds.length,
          storageWarning: pendingIds.length >= _pendingDeletionWarningThreshold ? state.storageWarning : null,
        );
      }
    } catch (e) {
      debugPrint('Error executing partial deletion: $e');
    }
  }
}
