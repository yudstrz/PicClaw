import 'dart:collection';
import 'package:photo_manager/photo_manager.dart';

class SwiperState {
  final Queue<AssetEntity> activeQueue; // Double-ended queue for fast card indexing & batch load
  final bool isLoading;
  final String? errorMessage;
  final String? storageWarning;      // Warning message regarding disk space or pending limits
  final AssetEntity? lastSwipedAsset; // Kept in memory to facilitate instantaneous Undo action
  final bool? lastSwipeWasDelete;    // Tracks if the last swiped action was a deletion
  final int totalAssetCount; // Total count of media items in the gallery
  final int currentIndex;    // Index of the current top card being swiped
  final int pendingDeletionCount; // Count of assets currently marked for deletion
  final List<AssetPathEntity> albums;   // List of all media albums/folders
  final AssetPathEntity? selectedAlbum; // Currently selected album/folder

  SwiperState({
    required this.activeQueue,
    this.isLoading = false,
    this.errorMessage,
    this.storageWarning,
    this.lastSwipedAsset,
    this.lastSwipeWasDelete,
    this.totalAssetCount = 0,
    this.currentIndex = 0,
    this.pendingDeletionCount = 0,
    this.albums = const [],
    this.selectedAlbum,
  });

  SwiperState copyWith({
    Queue<AssetEntity>? activeQueue,
    bool? isLoading,
    String? errorMessage,
    String? storageWarning,
    AssetEntity? lastSwipedAsset,
    bool? lastSwipeWasDelete,
    int? totalAssetCount,
    int? currentIndex,
    int? pendingDeletionCount,
    List<AssetPathEntity>? albums,
    AssetPathEntity? selectedAlbum,
  }) {
    return SwiperState(
      activeQueue: activeQueue ?? this.activeQueue,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      storageWarning: storageWarning ?? this.storageWarning,
      lastSwipedAsset: lastSwipedAsset ?? this.lastSwipedAsset,
      lastSwipeWasDelete: lastSwipeWasDelete ?? this.lastSwipeWasDelete,
      totalAssetCount: totalAssetCount ?? this.totalAssetCount,
      currentIndex: currentIndex ?? this.currentIndex,
      pendingDeletionCount: pendingDeletionCount ?? this.pendingDeletionCount,
      albums: albums ?? this.albums,
      selectedAlbum: selectedAlbum ?? this.selectedAlbum,
    );
  }
}

