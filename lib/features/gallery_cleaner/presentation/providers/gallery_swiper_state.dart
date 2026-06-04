import 'dart:collection';
import 'package:flutter/material.dart';
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
  final DateTimeRange? dateFilter; // Optional date filter for albums
  final int resumedFromIndex; // > 0 if app resumed from a previous session, 0 if fresh start
  final RequestType requestType; // Determines if showing images or videos

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
    this.dateFilter,
    this.resumedFromIndex = 0,
    this.requestType = RequestType.image,
  });

  SwiperState copyWith({
    Queue<AssetEntity>? activeQueue,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? storageWarning,
    bool clearStorageWarning = false,
    AssetEntity? lastSwipedAsset,
    bool clearLastSwipedAsset = false,
    bool? lastSwipeWasDelete,
    bool clearLastSwipeWasDelete = false,
    int? totalAssetCount,
    int? currentIndex,
    int? pendingDeletionCount,
    List<AssetPathEntity>? albums,
    AssetPathEntity? selectedAlbum,
    bool clearSelectedAlbum = false,
    DateTimeRange? dateFilter,
    bool clearDateFilter = false,
    int? resumedFromIndex,
    RequestType? requestType,
  }) {
    return SwiperState(
      activeQueue: activeQueue ?? this.activeQueue,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      storageWarning: clearStorageWarning ? null : (storageWarning ?? this.storageWarning),
      lastSwipedAsset: clearLastSwipedAsset ? null : (lastSwipedAsset ?? this.lastSwipedAsset),
      lastSwipeWasDelete: clearLastSwipeWasDelete ? null : (lastSwipeWasDelete ?? this.lastSwipeWasDelete),
      totalAssetCount: totalAssetCount ?? this.totalAssetCount,
      currentIndex: currentIndex ?? this.currentIndex,
      pendingDeletionCount: pendingDeletionCount ?? this.pendingDeletionCount,
      albums: albums ?? this.albums,
      selectedAlbum: clearSelectedAlbum ? null : (selectedAlbum ?? this.selectedAlbum),
      dateFilter: clearDateFilter ? null : (dateFilter ?? this.dateFilter),
      resumedFromIndex: resumedFromIndex ?? this.resumedFromIndex,
      requestType: requestType ?? this.requestType,
    );
  }
}

