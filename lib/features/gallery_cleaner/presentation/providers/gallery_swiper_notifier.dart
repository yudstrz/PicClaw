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

    // Get total asset count for "Visibility of System Status"
    int totalCount = 0;
    try {
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        type: RequestType.common,
      );
      if (paths.isNotEmpty) {
        totalCount = await paths.first.assetCountAsync;
      }
    } catch (e) {
      debugPrint('Failed to fetch total asset count: $e');
    }

    state = state.copyWith(
      totalAssetCount: totalCount,
      currentIndex: 0,
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
    
    // Instant UI updates and increments current index
    state = state.copyWith(
      activeQueue: Queue<AssetEntity>.from(state.activeQueue),
      lastSwipedAsset: swipedAsset,
      currentIndex: state.currentIndex + 1,
    );

    // Save status to SQLite asynchronously (background task logic)
    final int size = await _getAssetSize(swipedAsset);

    await _sessionDbDatasource.saveSwipeStatus(
      mediaId: swipedAsset.id,
      albumId: null,
      status: isDelete ? 'PENDING_DELETION' : 'KEPT',
      fileSize: size,
      mediaType: swipedAsset.typeInt,
      createdAt: swipedAsset.createDateTime.millisecondsSinceEpoch,
    );

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
    
    state = state.copyWith(
      activeQueue: newQueue,
      lastSwipedAsset: null,
      currentIndex: (state.currentIndex - 1).clamp(0, state.totalAssetCount),
    );

    // Revert SQLite status record
    await _sessionDbDatasource.removeSwipeStatus(restoredAsset.id);
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
        );
      }
    } catch (e) {
      debugPrint('Error executing final deletion: $e');
    }
  }
}
