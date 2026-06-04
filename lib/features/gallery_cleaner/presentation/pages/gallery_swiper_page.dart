import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/gallery_swiper_notifier.dart';
import '../providers/gallery_swiper_state.dart';
import '../providers/update_checker_provider.dart';
import '../widgets/swiper_card.dart';


class GallerySwiperPage extends ConsumerWidget {
  const GallerySwiperPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(swiperNotifierProvider);
    final notifier = ref.read(swiperNotifierProvider.notifier);

    // Listen for updates and show dialog
    ref.listen<UpdateState>(updateCheckerProvider, (previous, next) {
      if (next.isUpdateAvailable && !next.isLoading) {
        _showUpdateDialog(context, next);
      }
    });

    // Show a one-time snackbar when the session is resumed from a saved position
    ref.listen<int>(
      swiperNotifierProvider.select((s) => s.resumedFromIndex),
      (previous, next) {
        if (next > 0 && (previous == null || previous == 0)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.history_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Melanjutkan dari foto ke-$next 👋',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF8B5CF6),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.cleaning_services_rounded, color: Color(0xFFFF5353)),
            const SizedBox(width: 8),
            Text(
              'PicClaw',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.delete_sweep_rounded,
                    color: state.pendingDeletionCount > 0
                        ? const Color(0xFFFF5353)
                        : Colors.white30,
                  ),
                  tooltip: state.pendingDeletionCount > 0
                      ? 'Hapus Permanen Pilihan (${state.pendingDeletionCount})'
                      : 'Antrean Hapus Kosong',
                  onPressed: state.pendingDeletionCount > 0
                      ? () => _showPendingDeletionDetailBottomSheet(context, state, notifier)
                      : null,
                ),
                if (state.pendingDeletionCount > 0)
                  Positioned(
                    right: 4,
                    top: 8,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF8B5CF6),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${state.pendingDeletionCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded, color: Colors.white54),
            tooltip: 'Mulai Ulang dari Foto Pertama',
            onPressed: () => _showResetProgressDialog(context, notifier),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: Colors.white70),
            tooltip: 'Panduan & Batasan',
            onPressed: () => _showHelpDialog(context),
          ),
          // Visibility of System Status: Privacy & Sandbox confirmation
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.25), width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_rounded, color: Colors.green, size: 14),
                SizedBox(width: 4),
                Text(
                  '100% Offline',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: state.isLoading && state.activeQueue.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5353)),
                  ),
                )
              : state.errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            state.errorMessage!,
                            style: const TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : state.activeQueue.isEmpty
                      ? _buildEmptyState(context, state, notifier)
                      : Column(
                          children: [
                            const SizedBox(height: 8),
                            // PRINCIPLE 1: Visibility of System Status (Progress bar & counts)
                            _buildProgressIndicator(context, state),
                            const SizedBox(height: 12),
                            _buildFolderSelectorButton(context, state, notifier),
                            const SizedBox(height: 12),
                            _buildStorageWarning(context, state, notifier),
                            const SizedBox(height: 16),

                            // PRINCIPLE 6 & 12: Recognition rather than Recall & Aesthetic-Usability Effect (80% Height Card Swiper)
                            Expanded(
                              child: Center(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final list = state.activeQueue.toList();
                                      return Stack(
                                        clipBehavior: Clip.none,
                                        children: List.generate(
                                          list.length > 3 ? 3 : list.length,
                                          (index) {
                                            final reversedIndex = (list.length > 3 ? 3 : list.length) - 1 - index;
                                            final asset = list[reversedIndex];
                                            
                                            // Stack cascade visuals
                                            final scale = 1.0 - (reversedIndex * 0.045);
                                            final yOffset = reversedIndex * 16.0;

                                            return Positioned.fill(
                                              key: ValueKey(asset.id),
                                              child: Align(
                                                alignment: Alignment.center,
                                                child: AnimatedContainer(
                                                  duration: const Duration(milliseconds: 200),
                                                  curve: Curves.easeOut,
                                                  transform: Matrix4.identity()
                                                    ..translate(0.0, yOffset)
                                                    ..scale(scale),
                                                  child: reversedIndex == 0
                                                      ? _InteractiveCard(
                                                          key: ValueKey(asset.id),
                                                          child: SwiperCard(asset: asset),
                                                          onSwipeLeft: () => notifier.swipeCard(isDelete: true),
                                                          onSwipeRight: () => notifier.swipeCard(isDelete: false),
                                                          onTap: () => _showMediaDetailDialog(context, asset),
                                                        )
                                                      : IgnorePointer(
                                                          child: SwiperCard(asset: asset),
                                                        ),
                                                ),
                                              ),
                                            );
                                          },
                                        ), 
                                      );
                                    },
                                  ),),
                              ),
                            

                            const SizedBox(height: 28),

                            // PRINCIPLE 9 & 10: Fitts's Law & Hick's Law (Thumb zone action buttons)
                            _buildControlBar(context, state, notifier),
                            const SizedBox(height: 20),
                          ],
                        ),
        ),
      ),
    );
  }

  Widget _buildFolderSelectorButton(BuildContext context, SwiperState state, SwiperNotifier notifier) {
    if (state.albums.isEmpty) return const SizedBox.shrink();

    final selected = state.selectedAlbum;
    final name = selected != null ? selected.name : 'Pilih Folder Analisis';

    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () => _showFolderSelectorBottomSheet(context, state, notifier),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_copy_rounded, color: Color(0xFF8B5CF6), size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white60, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStorageWarning(BuildContext context, SwiperState state, SwiperNotifier notifier) {
    if (state.storageWarning == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5353).withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF5353).withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5353), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              state.storageWarning!,
              style: const TextStyle(
                color: Color(0xFFFF5353),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.close_rounded, color: Color(0xFFFF5353), size: 18),
            onPressed: () => notifier.dismissStorageWarning(),
          ),
        ],
      ),
    );
  }

  void _showFolderSelectorBottomSheet(BuildContext context, SwiperState state, SwiperNotifier notifier) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14141B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    const Icon(Icons.folder_special_rounded, color: Color(0xFF8B5CF6), size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Pilih Folder Analisis',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Pilih folder khusus yang berisi media di HP Anda untuk mulai memilah secara lokal.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white10, height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: state.albums.length,
                  itemBuilder: (context, index) {
                    final album = state.albums[index];
                    final isSelected = album.id == state.selectedAlbum?.id;

                    return FutureBuilder<int>(
                      future: album.assetCountAsync,
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        return InkWell(
                          onTap: () {
                            notifier.changeAlbum(album);
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white.withOpacity(0.04) : Colors.transparent,
                            ),
                            child: Row(
                              children: [
                                _FolderCoverThumbnail(album: album),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        album.name,
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$count berkas media terdeteksi',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.4),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF2ECA87),
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMediaDetailDialog(BuildContext context, AssetEntity asset) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return FutureBuilder<Map<String, dynamic>>(
          future: () async {
            final file = await asset.file;
            final size = file != null ? await file.length() : 0;
            final path = file?.path ?? 'Tidak diketahui';
            Uint8List? thumbBytes;
            if (asset.type == AssetType.video) {
              thumbBytes = await asset.thumbnailDataWithSize(const ThumbnailSize(500, 500));
            }
            return {
              'file': file,
              'size': size,
              'path': path,
              'thumbBytes': thumbBytes,
            };
          }(),
          builder: (context, snapshot) {
            final loaded = snapshot.hasData;
            final io.File? file = loaded ? snapshot.data!['file'] as io.File? : null;
            final bytes = loaded ? snapshot.data!['size'] as int : 0;
            final path = loaded ? snapshot.data!['path'] as String : 'Loading...';
            final thumbBytes = loaded ? snapshot.data!['thumbBytes'] as Uint8List? : null;

            String fileSizeText = 'Loading...';
            if (loaded) {
              if (bytes <= 0) fileSizeText = "0 B";
              else if (bytes < 1024) fileSizeText = "$bytes B";
              else if (bytes < 1024 * 1024) fileSizeText = "${(bytes / 1024).toStringAsFixed(1)} KB";
              else if (bytes < 1024 * 1024 * 1024) fileSizeText = "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
              else fileSizeText = "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB";
            }

            return Dialog(
              backgroundColor: const Color(0xFF14141B),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Colors.white10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            asset.type == AssetType.video ? 'Detail Video' : 'Detail Foto',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  
                  // Full Resolution Preview / Thumbnail
                  Expanded(
                    child: Container(
                      color: Colors.black26,
                      child: InteractiveViewer(
                        maxScale: 4.0,
                        minScale: 0.8,
                        child: Center(
                          child: asset.type == AssetType.video
                              ? Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (thumbBytes != null)
                                      Image.memory(
                                        thumbBytes,
                                        fit: BoxFit.contain,
                                      )
                                    else
                                      const Icon(Icons.video_library_rounded, color: Colors.white30, size: 64),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                                    ),
                                  ],
                                )
                              : file != null
                                  ? Image.file(
                                      file,
                                      fit: BoxFit.contain,
                                    )
                                  : const Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5353)),
                                      ),
                                    ),
                        ),
                      ),
                    ),
                  ),

                  // Metadata Information Panel
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A1A24),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Nama Berkas', asset.title ?? 'Unnamed'),
                        const SizedBox(height: 10),
                        _buildDetailRow('Resolusi', '${asset.width} x ${asset.height} px'),
                        const SizedBox(height: 10),
                        _buildDetailRow('Ukuran File', fileSizeText),
                        const SizedBox(height: 10),
                        _buildDetailRow(
                          'Tanggal',
                          '${asset.createDateTime.day}/${asset.createDateTime.month}/${asset.createDateTime.year} '
                          '${asset.createDateTime.hour.toString().padLeft(2, '0')}:${asset.createDateTime.minute.toString().padLeft(2, '0')}',
                        ),
                        const SizedBox(height: 10),
                        _buildDetailRow('Path Lokasi', path, isPath: true),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isPath = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: isPath ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(BuildContext context, SwiperState state) {
    final double percent = state.totalAssetCount > 0 ? (state.currentIndex / state.totalAssetCount) : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Foto ${state.currentIndex} dari ${state.totalAssetCount}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
            ),
            Text(
              '${(percent * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Color(0xFF8B5CF6),
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 6,
            backgroundColor: Colors.white.withOpacity(0.05),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
          ),
        ),
      ],
    );
  }

  Widget _buildControlBar(BuildContext context, SwiperState state, SwiperNotifier notifier) {
    final hasUndo = state.lastSwipedAsset != null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // PRINCIPLE 3: User Control and Freedom (Instant Undo)
        IconButton.filledTonal(
          onPressed: hasUndo ? () => notifier.undoLastSwipe() : null,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.05),
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.white.withOpacity(0.01),
            disabledForegroundColor: Colors.white12,
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.undo_rounded, size: 24),
        ),

        // PRINCIPLE 2 & 7: Match between System/Real World & Efficiency (Trash Bin - Swipe Left Button)
        ElevatedButton(
          onPressed: () => notifier.swipeCard(isDelete: true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF5353),
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(22),
            elevation: 8,
          ),
          child: const Icon(Icons.delete_outline_rounded, size: 30),
        ),

        // PRINCIPLE 2 & 7: Match between System/Real World & Efficiency (Claw/Capit - Swipe Right Button)
        ElevatedButton(
          onPressed: () => notifier.swipeCard(isDelete: false),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2ECA87),
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(22),
            elevation: 8,
          ),
          child: const Icon(Icons.front_hand_rounded, size: 30), // Capit/Claw metaphor
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, SwiperState state, SwiperNotifier notifier) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: Color(0xFF2ECA87),
            size: 72,
          ),
          const SizedBox(height: 20),
          Text(
            'Semua Bersih!',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 8),
          const Text(
            'Seluruh foto di galeri Anda telah selesai ditinjau.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 36),
          // PRINCIPLE 5: Error Prevention (Permanent deletion via separate final dialog approval or view queue details)
          ElevatedButton.icon(
            onPressed: state.pendingDeletionCount > 0
                ? () => _showPendingDeletionDetailBottomSheet(context, state, notifier)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5353),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 4,
            ),
            icon: const Icon(Icons.delete_forever_rounded),
            label: Text(
              state.pendingDeletionCount > 0
                  ? 'Hapus Permanen Foto Pilihan (${state.pendingDeletionCount})'
                  : 'Hapus Permanen Foto Pilihan',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: const Color(0xFF181820),
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFFFF5353), size: 28),
              SizedBox(width: 12),
              Text(
                'Panduan & Informasi',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cara Menggunakan Gestur:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 12),
                _buildHelpItem(
                  icon: Icons.swipe_left_rounded,
                  iconColor: const Color(0xFFFF5353),
                  title: 'Swipe Kiri (Geser Kiri) / Tombol Merah',
                  description: 'Memasukkan foto ke keranjang sampah sementara (Trash).',
                ),
                const SizedBox(height: 12),
                _buildHelpItem(
                  icon: Icons.swipe_right_rounded,
                  iconColor: const Color(0xFF2ECA87),
                  title: 'Swipe Kanan (Geser Kanan) / Tombol Hijau',
                  description: 'Menyimpan/membiarkan foto tetap berada di galeri HP Anda (Keep).',
                ),
                const SizedBox(height: 12),
                _buildHelpItem(
                  icon: Icons.undo_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  title: 'Tombol Urungkan (Undo)',
                  description: 'Mengembalikan 1 foto terakhir yang baru saja di-swipe ke tumpukan.',
                ),
                const Divider(color: Colors.white10, height: 24),
                const Text(
                  'Keamanan & Batasan Aplikasi:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 12),
                _buildHelpItem(
                  icon: Icons.shield_rounded,
                  iconColor: Colors.green,
                  title: '100% Offline & Lokal',
                  description: 'Aplikasi berjalan sepenuhnya di HP Anda. Foto Anda tidak akan diunggah ke internet/server mana pun.',
                ),
                const SizedBox(height: 12),
                _buildHelpItem(
                  icon: Icons.delete_sweep_rounded,
                  iconColor: Colors.amber,
                  title: 'Penghapusan Galeri Aman',
                  description: 'Foto tidak langsung terhapus saat di-swipe kiri. Anda harus menekan tombol "Hapus Permanen" setelah selesai meninjau semua foto untuk menghapusnya lewat dialog izin keamanan resmi OS Anda.',
                ),
                const SizedBox(height: 12),
                _buildHelpItem(
                  icon: Icons.memory_rounded,
                  iconColor: Colors.lightBlue,
                  title: 'Batas Memori (Batching)',
                  description: 'Foto dimuat secara bertahap dalam batch (masing-masing 10 foto) agar performa HP tetap lancar dan tidak memakan RAM berlebih.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Mengerti',
                style: TextStyle(
                  color: Color(0xFFFF5353),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHelpItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPendingDeletionDetailBottomSheet(
    BuildContext context,
    SwiperState state,
    SwiperNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14141B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return _PendingDeletionBottomSheetContent(
          notifier: notifier,
        );
      },
    );
  }
  void _showResetProgressDialog(BuildContext context, SwiperNotifier notifier) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.restart_alt_rounded, color: Color(0xFF8B5CF6), size: 26),
              SizedBox(width: 10),
              Text(
                'Mulai dari Awal?',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Posisi swipe akan dikembalikan ke foto pertama di galeri kamu.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Foto dalam antrean hapus tetap aman — tidak ikut direset.',
                        style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Batal', style: TextStyle(color: Colors.white54)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      notifier.resetProgress();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.restart_alt_rounded, size: 16),
                    label: const Text('Reset', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showUpdateDialog(BuildContext context, UpdateState state) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false, // Prevent back button from dismissing
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            backgroundColor: const Color(0xFF181820),
            title: const Row(
              children: [
                Icon(Icons.system_update_rounded, color: Color(0xFF8B5CF6), size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pembaruan Wajib',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5353).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFF5353).withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5353), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Versi ini sudah tidak didukung. Anda harus memperbarui aplikasi untuk melanjutkan.',
                          style: TextStyle(color: Color(0xFFFF5353), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Versi baru (${state.latestVersion}) telah dirilis. Unduh dan install untuk mendapatkan fitur terbaru serta perbaikan bug penting.',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                if (state.releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Yang Baru:',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    width: double.maxFinite,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        state.releaseNotes,
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final Uri url = Uri.parse(state.downloadUrl);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text(
                    'Download & Install Sekarang',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Gesture and physics detector cards with real-time visual feedback overlays
class _InteractiveCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  final VoidCallback onTap;

  const _InteractiveCard({
    super.key,
    required this.child,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    required this.onTap,
  });

  @override
  State<_InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<_InteractiveCard> {
  Offset _dragOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final double rotation = _dragOffset.dx / 350.0;
    
    // PRINCIPLE 11: Immediate Visual Feedback (Dynamic overlay opacities based on drag)
    final double deleteOpacity = (-_dragOffset.dx / 50.0).clamp(0.0, 0.85);
    final double keepOpacity = (_dragOffset.dx / 50.0).clamp(0.0, 0.85);

    return GestureDetector(
      onTap: widget.onTap,
      onPanUpdate: (details) {
        setState(() {
          _dragOffset += details.delta;
        });
      },
      onPanEnd: (details) {
        // Confirm swipe if drag surpasses threshold, otherwise reset to center
        if (_dragOffset.dx < -50) {
          widget.onSwipeLeft();
        } else if (_dragOffset.dx > 50) {
          widget.onSwipeRight();
        } else {
          setState(() {
            _dragOffset = Offset.zero;
          });
        }
      },
      child: Transform.translate(
        offset: _dragOffset,
        child: Transform.rotate(
          angle: rotation,
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,

              // PRINCIPLE 11: Real-time visual feedback overlay (TRASH / LEFT)
              if (deleteOpacity > 0.0)
                Positioned.fill(
                  child: Opacity(
                    opacity: deleteOpacity,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5353).withOpacity(0.75),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'TRASH',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // PRINCIPLE 11: Real-time visual feedback overlay (KEEP / RIGHT)
              if (keepOpacity > 0.0)
                Positioned.fill(
                  child: Opacity(
                    opacity: keepOpacity,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECA87).withOpacity(0.75),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'KEEP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper widget to fetch and display the cover image of a folder
class _FolderCoverThumbnail extends StatefulWidget {
  final AssetPathEntity album;
  const _FolderCoverThumbnail({required this.album});

  @override
  State<_FolderCoverThumbnail> createState() => _FolderCoverThumbnailState();
}

class _FolderCoverThumbnailState extends State<_FolderCoverThumbnail> {
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCover();
  }

  Future<void> _loadCover() async {
    try {
      final assets = await widget.album.getAssetListRange(start: 0, end: 1);
      if (assets.isNotEmpty) {
        final bytes = await assets.first.thumbnailDataWithSize(const ThumbnailSize(120, 120));
        if (mounted) {
          setState(() {
            _bytes = bytes;
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
            ),
          ),
        ),
      );
    }

    if (_bytes == null) {
      return Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.folder_rounded, color: Colors.white24, size: 24),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 54,
        height: 54,
        child: Image.memory(
          _bytes!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.white10,
            child: const Icon(Icons.broken_image_rounded, color: Colors.white24, size: 20),
          ),
        ),
      ),
    );
  }
}

class _PendingAssetThumbnail extends StatefulWidget {
  final AssetEntity asset;
  const _PendingAssetThumbnail({required this.asset});

  @override
  State<_PendingAssetThumbnail> createState() => _PendingAssetThumbnailState();
}

class _PendingAssetThumbnailState extends State<_PendingAssetThumbnail> {
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    try {
      final bytes = await widget.asset.thumbnailDataWithSize(const ThumbnailSize(200, 200));
      if (mounted) {
        setState(() {
          _bytes = bytes;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: Colors.white.withOpacity(0.03),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white24),
            ),
          ),
        ),
      );
    }

    if (_bytes == null) {
      return Container(
        color: Colors.white.withOpacity(0.03),
        child: const Icon(Icons.broken_image_rounded, color: Colors.white24, size: 20),
      );
    }

    return Image.memory(
      _bytes!,
      fit: BoxFit.cover,
      cacheWidth: 200,
      cacheHeight: 200,
    );
  }
}

class _PendingDeletionBottomSheetContent extends ConsumerStatefulWidget {
  final SwiperNotifier notifier;
  const _PendingDeletionBottomSheetContent({required this.notifier});

  @override
  ConsumerState<_PendingDeletionBottomSheetContent> createState() =>
      __PendingDeletionBottomSheetContentState();
}

class __PendingDeletionBottomSheetContentState
    extends ConsumerState<_PendingDeletionBottomSheetContent> {
  List<AssetEntity>? _assets;
  bool _loading = true;
  final Set<String> _selectedIds = {}; // Stores IDs marked for UNDO/RESTORE

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    final assets = await widget.notifier.getPendingDeletionAssets();
    if (mounted) {
      setState(() {
        _assets = assets;
        _loading = false;
      });
    }
  }

  void _toggleSelectAll(bool allSelected) {
    if (_assets == null) return;
    setState(() {
      if (allSelected) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_assets!.map((a) => a.id));
      }
    });
  }

  Future<void> _executeRestore() async {
    if (_selectedIds.isEmpty) return;
    final toRestore = _selectedIds.toList();
    setState(() => _loading = true);
    await widget.notifier.restoreAssetsFromDeletion(toRestore);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${toRestore.length} foto dipulihkan dari antrean hapus.'),
          backgroundColor: const Color(0xFF2ECA87),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _executePartialDelete(List<String> remainingIds) async {
    if (remainingIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFF181820),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5353), size: 28),
            SizedBox(width: 12),
            Text(
              'Hapus Permanen',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus secara permanen ${remainingIds.length} foto yang tersisa dari galeri HP Anda?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5353),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (mounted) setState(() => _loading = true);
      await widget.notifier.executeDeletionForIds(remainingIds);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto permanen berhasil dihapus.'),
            backgroundColor: Color(0xFFFF5353),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double sheetHeight = MediaQuery.of(context).size.height * 0.85;

    if (_loading) {
      return SizedBox(
        height: sheetHeight,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5353)),
          ),
        ),
      );
    }

    final assets = _assets ?? [];
    if (assets.isEmpty) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.delete_outline_rounded, color: Colors.white24, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Antrean Hapus Kosong',
                style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.05),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Tutup'),
              ),
            ],
          ),
        ),
      );
    }

    final allSelected = _selectedIds.length == assets.length;
    final remainingIds = assets.map((a) => a.id).where((id) => !_selectedIds.contains(id)).toList();

    return Container(
      height: sheetHeight,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Antrean Hapus (${assets.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Centang foto yang ingin dipulihkan (batal hapus).',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => _toggleSelectAll(allSelected),
                icon: Icon(
                  allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                  color: const Color(0xFF8B5CF6),
                  size: 18,
                ),
                label: Text(
                  allSelected ? 'Batal Pilih Semua' : 'Pilih Semua',
                  style: const TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              if (_selectedIds.isNotEmpty)
                Text(
                  '${_selectedIds.length} Terpilih',
                  style: const TextStyle(
                    color: Color(0xFF2ECA87),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: assets.length,
              itemBuilder: (context, index) {
                final asset = assets[index];
                final isSelected = _selectedIds.contains(asset.id);

                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedIds.remove(asset.id);
                      } else {
                        _selectedIds.add(asset.id);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _PendingAssetThumbnail(asset: asset),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.3),
                              Colors.transparent,
                              Colors.black.withOpacity(0.3),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF8B5CF6) : Colors.black38,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.transparent : Colors.white70,
                              width: 1.5,
                            ),
                          ),
                          padding: const EdgeInsets.all(3),
                          child: isSelected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 12,
                                )
                              : const SizedBox(
                                  width: 12,
                                  height: 12,
                                ),
                        ),
                      ),
                      if (asset.type == AssetType.video)
                        Positioned(
                          bottom: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 10),
                                const SizedBox(width: 2),
                                Text(
                                  _formatDuration(asset.duration),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectedIds.isNotEmpty ? _executeRestore : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white.withOpacity(0.04),
                    disabledForegroundColor: Colors.white24,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _selectedIds.isNotEmpty
                        ? 'Pulihkan Terpilih (${_selectedIds.length})'
                        : 'Pulihkan Terpilih',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: remainingIds.isNotEmpty ? () => _executePartialDelete(remainingIds) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5353),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white.withOpacity(0.04),
                    disabledForegroundColor: Colors.white24,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    remainingIds.isNotEmpty
                        ? 'Hapus Sisanya (${remainingIds.length})'
                        : 'Hapus Sisanya',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}
