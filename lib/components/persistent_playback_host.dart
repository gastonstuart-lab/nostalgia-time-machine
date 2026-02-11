import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../state.dart';
import '../services/playback_service.dart';
import '../theme.dart';

class PersistentPlaybackHost extends StatelessWidget {
  final Widget child;

  const PersistentPlaybackHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<NostalgiaProvider>();
    return Consumer<PlaybackService>(
      builder: (context, playback, _) {
        final canShowPlayer = appState.isSignedIn &&
            !appState.requiresEmailVerification &&
            appState.authResolved &&
            appState.canExitSplash;
        final showMiniPlayer = playback.hasTrack && canShowPlayer;
        final showGlobalPlayerSurface = playback.hasTrack && canShowPlayer;

        return Stack(
          children: [
            child,
            if (showGlobalPlayerSurface) const _GlobalPlayerSurface(),
            if (showMiniPlayer)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: _MiniPlayer(playback: playback),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GlobalPlayerSurface extends StatefulWidget {
  const _GlobalPlayerSurface();

  @override
  State<_GlobalPlayerSurface> createState() => _GlobalPlayerSurfaceState();
}

class _GlobalPlayerSurfaceState extends State<_GlobalPlayerSurface> {
  Offset _offset = Offset.zero;
  double _windowWidth = 420;

  double _clampDouble(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<PlaybackService>();
    final theme = Theme.of(context);
    final isVisible = playback.showVideoWindow;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final effectiveMaxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : screenWidth;
        final maxWidth = _clampDouble(effectiveMaxWidth - 20, 280.0, 760.0);
        final width = _clampDouble(_windowWidth, 280.0, maxWidth);
        final minX = -(effectiveMaxWidth - width - 16);
        final maxX = 0.0;
        final minY =
            -_clampDouble(MediaQuery.of(context).size.height * 0.6, 120, 900);
        final maxY = 0.0;
        final safeOffset = Offset(
          _clampDouble(_offset.dx, minX, maxX),
          _clampDouble(_offset.dy, minY, maxY),
        );
        if (safeOffset != _offset) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _offset = safeOffset);
          });
        }

        const collapsedTabWidth = 56.0;
        final margin = const EdgeInsets.only(right: 12, bottom: 84);
        final containerWidth = width;
        final collapsedShiftX = containerWidth - collapsedTabWidth;
        final decoration = BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: theme.colorScheme.onSurface, width: 2),
          boxShadow: AppTheme.shadowSm,
        );

        return IgnorePointer(
          ignoring: false,
          child: Align(
            alignment: Alignment.bottomRight,
            child: Transform.translate(
              offset: isVisible
                  ? safeOffset
                  : Offset(
                      _clampDouble(safeOffset.dx + collapsedShiftX, minX, maxX),
                      _clampDouble(safeOffset.dy, minY, maxY),
                    ),
              child: Container(
                width: containerWidth,
                margin: margin,
                decoration: decoration,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          _offset += details.delta;
                        });
                      },
                      onDoubleTap: () => setState(() => _offset = Offset.zero),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(AppTheme.radiusMd),
                            topRight: Radius.circular(AppTheme.radiusMd),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isVisible
                                  ? Icons.drag_indicator
                                  : Icons.picture_in_picture_alt_rounded,
                              size: 18,
                              color: theme.colorScheme.onSurface,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                isVisible
                                    ? (playback.currentTitle ?? 'Now playing')
                                    : 'Video hidden',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (isVisible) ...[
                              IconButton(
                                iconSize: 18,
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  setState(() {
                                    _windowWidth = _clampDouble(
                                        _windowWidth - 48, 280.0, maxWidth);
                                  });
                                },
                                icon: const Icon(Icons.remove_rounded),
                              ),
                              IconButton(
                                iconSize: 18,
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  setState(() {
                                    _windowWidth = _clampDouble(
                                        _windowWidth + 48, 280.0, maxWidth);
                                  });
                                },
                                icon: const Icon(Icons.add_rounded),
                              ),
                            ],
                            IconButton(
                              iconSize: 18,
                              visualDensity: VisualDensity.compact,
                              onPressed: isVisible
                                  ? playback.hideVideo
                                  : playback.showVideo,
                              icon: Icon(
                                isVisible
                                    ? Icons.keyboard_arrow_down_rounded
                                    : Icons.keyboard_arrow_up_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: isVisible ? 1 : 0.25,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(AppTheme.radiusMd),
                              bottomRight: Radius.circular(AppTheme.radiusMd),
                            ),
                            child: IgnorePointer(
                              ignoring: !isVisible,
                              child: YoutubePlayer(
                                key: const ValueKey(
                                    'persistent_global_youtube_player'),
                                controller: playback.controller,
                                aspectRatio: 16 / 9,
                              ),
                            ),
                          ),
                          if (!isVisible)
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: playback.showVideo,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    width: collapsedTabWidth,
                                    color: Colors.transparent,
                                    child: Icon(
                                      Icons.keyboard_arrow_up_rounded,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isVisible) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 8, right: 8, bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Drag title bar to move',
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanUpdate: (details) {
                                setState(() {
                                  _windowWidth = _clampDouble(
                                    _windowWidth + details.delta.dx,
                                    280.0,
                                    maxWidth,
                                  );
                                });
                              },
                              child: Container(
                                width: 42,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface
                                      .withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: theme.colorScheme.onSurface,
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  Icons.open_in_full_rounded,
                                  size: 14,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniPlayer extends StatefulWidget {
  final PlaybackService playback;

  const _MiniPlayer({required this.playback});

  @override
  State<_MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<_MiniPlayer> {
  Offset _dragOffset = Offset.zero;

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _resetPosition() {
    setState(() {
      _dragOffset = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final playback = widget.playback;

    return LayoutBuilder(
      builder: (context, constraints) {
        final card = playback.isMinimized
            ? _buildMinimizedCard(context, playback, isDark)
            : _buildExpandedCard(context, playback, isDark);
        final width = playback.isMinimized
            ? 248.0
            : (constraints.maxWidth > 520 ? 420.0 : constraints.maxWidth - 20);

        return IgnorePointer(
          ignoring: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Transform.translate(
              offset: _dragOffset,
              child: SizedBox(
                width: width,
                child: GestureDetector(
                  onPanUpdate: _onPanUpdate,
                  onDoubleTap: _resetPosition,
                  behavior: HitTestBehavior.translucent,
                  child: card,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMinimizedCard(
      BuildContext context, PlaybackService playback, bool isDark) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: theme.colorScheme.onSurface, width: 2),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.zero,
            onPressed:
                playback.canGoPrevious ? () => playback.previous() : null,
            icon: const Icon(Icons.skip_previous_rounded, size: 18),
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.zero,
            onPressed: () {
              if (playback.isPlaying) {
                playback.pause();
              } else {
                playback.resume();
              }
            },
            icon: Icon(
              playback.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 20,
            ),
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.zero,
            onPressed: playback.canGoNext ? () => playback.next() : null,
            icon: const Icon(Icons.skip_next_rounded, size: 18),
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.zero,
            onPressed: playback.expand,
            icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.zero,
            onPressed: playback.showVideoWindow
                ? playback.hideVideo
                : playback.showVideo,
            icon: Icon(
              playback.showVideoWindow
                  ? Icons.visibility_off_rounded
                  : Icons.picture_in_picture_alt_rounded,
              size: 18,
            ),
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.zero,
            onPressed: playback.stop,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedCard(
      BuildContext context, PlaybackService playback, bool isDark) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: theme.colorScheme.onSurface, width: 2),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed:
                playback.canGoPrevious ? () => playback.previous() : null,
            icon: Icon(
              Icons.skip_previous_rounded,
              color: theme.colorScheme.onSurface,
            ),
          ),
          IconButton(
            onPressed: () {
              if (playback.isPlaying) {
                playback.pause();
              } else {
                playback.resume();
              }
            },
            icon: Icon(
              playback.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: theme.colorScheme.onSurface,
            ),
          ),
          IconButton(
            onPressed: playback.canGoNext ? () => playback.next() : null,
            icon: Icon(Icons.skip_next_rounded, color: theme.colorScheme.onSurface),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push('/playlist'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    playback.currentTitle ?? 'Now playing',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppTheme.darkPrimaryText
                          : AppTheme.lightPrimaryText,
                    ),
                  ),
                  Text(
                    playback.currentSubtitle ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppTheme.darkSecondaryText
                          : AppTheme.lightSecondaryText,
                    ),
                  ),
                  if (playback.queueLabel != null)
                    Text(
                      playback.queueLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: playback.minimize,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          IconButton(
            onPressed: playback.showVideoWindow
                ? playback.hideVideo
                : playback.showVideo,
            icon: Icon(playback.showVideoWindow
                ? Icons.visibility_off_rounded
                : Icons.picture_in_picture_alt_rounded),
          ),
          IconButton(
            onPressed: playback.stop,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
