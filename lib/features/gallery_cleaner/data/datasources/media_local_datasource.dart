import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

abstract class MediaLocalDatasource {
  Future<bool> requestPermissions();
  Future<List<AssetPathEntity>> fetchAlbums({DateTime? startDate, DateTime? endDate});
  Future<List<AssetEntity>> fetchRecentAssets({
    required int limit,
    required int offset,
    AssetPathEntity? album,
  });
  Future<Uint8List?> getMediumResThumbnail(AssetEntity asset);
}

class MediaLocalDatasourceImpl implements MediaLocalDatasource {
  static const int _thumbnailTargetSize = 500; // 500x500px is perfect for gallery cards

  @override
  Future<bool> requestPermissions() async {
    final PermissionState state = await PhotoManager.requestPermissionExtend();
    return state.isAuth;
  }

  @override
  Future<List<AssetPathEntity>> fetchAlbums({DateTime? startDate, DateTime? endDate}) async {
    return PhotoManager.getAssetPathList(
      type: RequestType.common, // Fetching both images and videos
      filterOption: FilterOptionGroup(
        imageOption: const FilterOption(
          sizeConstraint: SizeConstraint(ignoreSize: false),
        ),
        createTimeCond: startDate != null || endDate != null
            ? DateTimeCond(
                min: startDate ?? DateTime(1970),
                max: endDate ?? DateTime.now(),
              )
            : const DateTimeCond.def(),
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false), // Newest first
        ],
      ),
    );
  }

  @override
  Future<List<AssetEntity>> fetchRecentAssets({
    required int limit,
    required int offset,
    AssetPathEntity? album,
  }) async {
    if (album != null) {
      return album.getAssetListRange(start: offset, end: offset + limit);
    }

    final List<AssetPathEntity> paths = await fetchAlbums();
    if (paths.isEmpty) return [];

    final AssetPathEntity recentPath = paths.first;
    return recentPath.getAssetListRange(start: offset, end: offset + limit);
  }

  @override
  Future<Uint8List?> getMediumResThumbnail(AssetEntity asset) async {
    try {
      // MEMORY OPTIMIZATION: Avoid loading full assets into memory.
      // Use constrained size to prevent high GPU/Memory usage (OOM prevention).
      final Uint8List? thumbBytes = await asset.thumbnailDataWithSize(
        const ThumbnailSize(_thumbnailTargetSize, _thumbnailTargetSize),
        quality: 80,
      );
      
      return thumbBytes;
    } catch (e) {
      debugPrint('Failed to get thumbnail for asset ID ${asset.id}: $e');
      return null;
    }
  }
}
