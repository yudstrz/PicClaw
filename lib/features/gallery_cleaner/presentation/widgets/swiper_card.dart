import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'media_thumbnail.dart';

class SwiperCard extends StatelessWidget {
  final AssetEntity asset;

  const SwiperCard({
    super.key,
    required this.asset,
  });

  String _formatDuration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    if (bytes < 1024 * 1024 * 1024) return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB";
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Native Media Thumbnail
          MediaThumbnail(asset: asset),

          // Top Overlay Badges
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Media Type Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12, width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        asset.type == AssetType.video ? Icons.play_arrow_rounded : Icons.image_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      if (asset.type == AssetType.video) ...[
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(asset.duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Size Badge
                FutureBuilder<int>(
                  future: asset.titleAsync.then((_) async {
                    try {
                      final file = await asset.file;
                      return file?.lengthSync() ?? 0;
                    } catch (_) {
                      return 0;
                    }
                  }),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data! > 0) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12, width: 0.5),
                        ),
                        child: Text(
                          _formatFileSize(snapshot.data!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),

          // Bottom Detail Dark Gradient Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.95),
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (asset.title != null && asset.title!.isNotEmpty) ? asset.title! : 'Unnamed Asset',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Dibuat: ${asset.createDateTime.day}/${asset.createDateTime.month}/${asset.createDateTime.year}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
