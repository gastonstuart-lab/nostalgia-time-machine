import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../theme.dart';

String? extractYouTubeVideoId(String? raw) {
  if (raw == null) return null;
  final value = raw.trim();
  if (value.isEmpty) return null;

  final idRegex = RegExp(r'^[a-zA-Z0-9_-]{11}$');
  if (idRegex.hasMatch(value)) return value;

  final uri = Uri.tryParse(value);
  if (uri == null) return null;

  if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
    final id = uri.pathSegments.first;
    return idRegex.hasMatch(id) ? id : null;
  }

  final queryId = uri.queryParameters['v'];
  if (queryId != null && idRegex.hasMatch(queryId)) return queryId;

  final embedIndex = uri.pathSegments.indexOf('embed');
  if (embedIndex >= 0 && embedIndex + 1 < uri.pathSegments.length) {
    final embedId = uri.pathSegments[embedIndex + 1];
    return idRegex.hasMatch(embedId) ? embedId : null;
  }

  return null;
}

Future<void> showMovieTrailerSheet(
  BuildContext context, {
  required String title,
  required String? trailerYoutubeId,
  required String? trailerYoutubeUrl,
}) async {
  final videoId =
      extractYouTubeVideoId(trailerYoutubeId) ?? extractYouTubeVideoId(trailerYoutubeUrl);
  if (videoId == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No trailer available for this movie.')),
      );
    }
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _MovieTrailerSheet(
      title: title,
      videoId: videoId,
    ),
  );
}

class _MovieTrailerSheet extends StatefulWidget {
  final String title;
  final String videoId;

  const _MovieTrailerSheet({
    required this.title,
    required this.videoId,
  });

  @override
  State<_MovieTrailerSheet> createState() => _MovieTrailerSheetState();
}

class _MovieTrailerSheetState extends State<_MovieTrailerSheet> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(showFullscreenButton: true),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText =
        isDark ? AppTheme.darkPrimaryText : AppTheme.lightPrimaryText;
    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.spacingLg,
        right: AppTheme.spacingLg,
        top: AppTheme.spacingLg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.title} Trailer',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: primaryText,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: YoutubePlayer(
              controller: _controller,
              aspectRatio: 16 / 9,
            ),
          ),
        ],
      ),
    );
  }
}
