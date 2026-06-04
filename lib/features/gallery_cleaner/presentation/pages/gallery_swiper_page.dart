import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/gallery_swiper_notifier.dart';
import '../providers/gallery_swiper_state.dart';
import '../widgets/swiper_card.dart';


class GallerySwiperPage extends ConsumerWidget {
  const GallerySwiperPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(swiperNotifierProvider);
    final notifier = ref.read(swiperNotifierProvider.notifier);

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
          // Visibility of System Status: Privacy & Sandbox confirmation
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      ? _buildEmptyState(context, notifier)
                      : Column(
                          children: [
                            const SizedBox(height: 8),
                            // PRINCIPLE 1: Visibility of System Status (Progress bar & counts)
                            _buildProgressIndicator(context, state),
                            const SizedBox(height: 24),

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
                                                      )
                                                    : IgnorePointer(
                                                        child: SwiperCard(asset: asset),
                                                      ),
                                              ),
                                            ),
                                          );
                                        },
                                      ).reversed.toList(),
                                    );
                                  },
                                ),
                              ),
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

  Widget _buildEmptyState(BuildContext context, SwiperNotifier notifier) {
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
          // PRINCIPLE 5: Error Prevention (Permanent deletion via separate final dialog approval)
          ElevatedButton.icon(
            onPressed: () => notifier.executeFinalDeletion(),
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
            label: const Text(
              'Hapus Permanen Foto Pilihan',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gesture and physics detector cards with real-time visual feedback overlays
class _InteractiveCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;

  const _InteractiveCard({
    super.key,
    required this.child,
    required this.onSwipeLeft,
    required this.onSwipeRight,
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
    final double deleteOpacity = (-_dragOffset.dx / 150.0).clamp(0.0, 0.85);
    final double keepOpacity = (_dragOffset.dx / 150.0).clamp(0.0, 0.85);

    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _dragOffset += details.delta;
        });
      },
      onPanEnd: (details) {
        // Confirm swipe if drag surpasses threshold, otherwise reset to center
        if (_dragOffset.dx < -140) {
          widget.onSwipeLeft();
        } else if (_dragOffset.dx > 140) {
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
