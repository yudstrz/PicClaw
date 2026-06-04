import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../providers/gallery_swiper_notifier.dart';

/// Memory-optimized thumbnail renderer
class MediaThumbnail extends ConsumerStatefulWidget {
  final AssetEntity asset;

  const MediaThumbnail({
    super.key,
    required this.asset,
  });

  @override
  ConsumerState<MediaThumbnail> createState() => _MediaThumbnailState();
}

class _MediaThumbnailState extends ConsumerState<MediaThumbnail> {
  Uint8List? _bytes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    if (!mounted) return;
    
    final datasource = ref.read(mediaLocalDatasourceProvider);
    final bytes = await datasource.getMediumResThumbnail(widget.asset);
    
    if (mounted) {
      setState(() {
        _bytes = bytes;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    // MEMORY OPTIMIZATION: Nullify reference immediately when card is removed
    // to facilitate fast Dart Garbage Collection of the byte array.
    _bytes = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: const Color(0xFF1F1F2E),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
          ),
        ),
      );
    }

    if (_bytes == null) {
      return Container(
        color: const Color(0xFF1F1F2E),
        child: const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Colors.white24,
            size: 36,
          ),
        ),
      );
    }

    // MEMORY OPTIMIZATION: Explicitly set cacheWidth & cacheHeight bounds 
    // to tell the native Flutter Skia/Impeller renderer to decode the image 
    // at a maximum size of 500px, avoiding allocation of larger texture buffers.
    return Image.memory(
      _bytes!,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      cacheWidth: 500,
      cacheHeight: 500,
    );
  }
}
