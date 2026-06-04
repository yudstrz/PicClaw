import 'dart:collection';
import 'package:photo_manager/photo_manager.dart';

class SwiperState {
  final Queue<AssetEntity> activeQueue; // Double-ended queue for fast card indexing & batch load
  final bool isLoading;
  final String? errorMessage;
  final AssetEntity? lastSwipedAsset; // Kept in memory to facilitate instantaneous Undo action
  final int totalAssetCount; // Total count of media items in the gallery
  final int currentIndex;    // Index of the current top card being swiped

  SwiperState({
    required this.activeQueue,
    this.isLoading = false,
    this.errorMessage,
    this.lastSwipedAsset,
    this.totalAssetCount = 0,
    this.currentIndex = 0,
  });

  SwiperState copyWith({
    Queue<AssetEntity>? activeQueue,
    bool? isLoading,
    String? errorMessage,
    AssetEntity? lastSwipedAsset,
    int? totalAssetCount,
    int? currentIndex,
  }) {
    return SwiperState(
      activeQueue: activeQueue ?? this.activeQueue,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      lastSwipedAsset: lastSwipedAsset ?? this.lastSwipedAsset,
      totalAssetCount: totalAssetCount ?? this.totalAssetCount,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

