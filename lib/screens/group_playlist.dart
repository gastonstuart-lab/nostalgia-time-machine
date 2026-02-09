import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../theme.dart';
import '../state.dart';
import '../models/song.dart';
import '../models/episode.dart';
import '../services/firestore_service.dart';
import '../nav.dart';

class GroupPlaylistScreen extends StatefulWidget {
  const GroupPlaylistScreen({super.key});

  @override
  State<GroupPlaylistScreen> createState() => _GroupPlaylistScreenState();
}

class _GroupPlaylistScreenState extends State<GroupPlaylistScreen> {
  late YoutubePlayerController _controller;
  Song? _currentSong;
  Episode? _currentEpisode;
  bool _isPlayAllActive = false;
  int _currentIndex = 0;
  String _selectedTab = 'Songs';
  bool _shuffleEnabled = false;
  String _shuffleMode = 'Random';
  List<Song> _playQueue = [];

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: 'dQw4w9WgXcQ',
      autoPlay: false,
      params: const YoutubePlayerParams(showFullscreenButton: true),
    );
    _controller.listen(_onPlayerStateChange);
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  void _onPlayerStateChange(YoutubePlayerValue value) {
    if (value.playerState == PlayerState.ended && _isPlayAllActive) {
      _playNext();
    }
  }

  void _playSong(Song song) {
    setState(() {
      _currentSong = song;
      _currentEpisode = null;
    });
    if (song.youtubeId.isNotEmpty && song.youtubeId != "mock_video_id") {
      _controller.loadVideoById(videoId: song.youtubeId);
    } else {
      _controller.loadVideoById(videoId: 'dQw4w9WgXcQ');
    }
    _controller.playVideo();
  }

  void _playEpisode(Episode episode) {
    setState(() {
      _currentEpisode = episode;
      _currentSong = null;
    });
    if (episode.youtubeId.isNotEmpty && episode.youtubeId != "mock_video_id") {
      _controller.loadVideoById(videoId: episode.youtubeId);
    } else {
      _controller.loadVideoById(videoId: 'dQw4w9WgXcQ');
    }
    _controller.playVideo();
  }

  List<Song> _buildPlayQueue(List<Song> songs) {
    if (!_shuffleEnabled) return songs;

    if (_shuffleMode == 'Random') {
      final shuffled = List<Song>.from(songs);
      shuffled.shuffle();
      return shuffled;
    } else {
      final grouped = <String, List<Song>>{};
      for (final song in songs) {
        grouped.putIfAbsent(song.addedByUid, () => []).add(song);
      }
      for (final userSongs in grouped.values) {
        userSongs.sort((a, b) => a.addedAt.compareTo(b.addedAt));
      }

      final result = <Song>[];
      final userKeys = grouped.keys.toList();
      int maxLength = grouped.values
          .map((list) => list.length)
          .reduce((a, b) => a > b ? a : b);

      for (int i = 0; i < maxLength; i++) {
        for (final uid in userKeys) {
          final userSongs = grouped[uid]!;
          if (i < userSongs.length) {
            result.add(userSongs[i]);
          }
        }
      }
      return result;
    }
  }

  void _startPlayAll() {
    final provider = context.read<NostalgiaProvider>();
    final songs = provider.songs;

    if (songs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No songs yet")),
      );
      return;
    }

    setState(() {
      _playQueue = _buildPlayQueue(songs);
      _isPlayAllActive = true;
      _currentIndex = 0;
    });
    _playSong(_playQueue[0]);
  }

  void _stopPlayAll() {
    setState(() {
      _isPlayAllActive = false;
      _currentIndex = 0;
      _playQueue = [];
    });
  }

  void _playNext() {
    if (_currentIndex + 1 < _playQueue.length) {
      setState(() => _currentIndex++);
      _playSong(_playQueue[_currentIndex]);
    } else {
      _stopPlayAll();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Playlist complete")),
      );
    }
  }

  void _playPrevious() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _playSong(_playQueue[_currentIndex]);
    }
  }

  void _playSpecificSong(Song song) {
    if (_isPlayAllActive) {
      final index = _playQueue.indexWhere((s) => s.id == song.id);
      if (index != -1) {
        setState(() => _currentIndex = index);
        _playSong(_playQueue[_currentIndex]);
      } else {
        _playSong(song);
      }
    } else {
      _playSong(song);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NostalgiaProvider>();
    final group = provider.currentGroup;
    final songs = provider.songs;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (group == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Column(
          children: [
            Text("The Weekly Spin",
                style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800)),
            Text("${group.currentYear} Playlist",
                style: theme.textTheme.headlineSmall?.copyWith(
                    color: isDark
                        ? AppTheme.darkPrimaryText
                        : AppTheme.lightPrimaryText,
                    fontWeight: FontWeight.w900)),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border:
                    Border.all(color: theme.colorScheme.onSurface, width: 2),
              ),
              child: Icon(Icons.settings_input_component,
                  color: theme.colorScheme.onSurface, size: 24),
            ),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            return isWide
                ? _buildWideLayout(provider, songs)
                : _buildNarrowLayout(provider, songs, constraints);
          },
        ),
      ),
    );
  }

  Widget _buildWideLayout(NostalgiaProvider provider, List<Song> songs) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                child: _buildPlayerCard(songs),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.only(
                  top: AppTheme.spacingLg,
                  right: AppTheme.spacingLg,
                  bottom: AppTheme.spacingLg),
              child: _buildTabContent(provider, songs),
            ),
          ),
        ],
      );

  Widget _buildNarrowLayout(NostalgiaProvider provider, List<Song> songs,
          BoxConstraints constraints) =>
      Column(
        children: [
          ConstrainedBox(
            constraints:
                BoxConstraints(maxHeight: constraints.maxHeight * 0.45),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                child: _buildPlayerCard(songs),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
              child: _buildTabContent(provider, songs),
            ),
          ),
        ],
      );

  Widget _buildPlayerCard(List<Song> songs) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSecondary : AppTheme.lightSecondary,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: theme.colorScheme.onSurface, width: 3),
        boxShadow: AppTheme.shadowXl,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: YoutubePlayer(controller: _controller),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            _currentSong?.title ??
                _currentEpisode?.showTitle ??
                "Select a track",
            style: theme.textTheme.titleLarge?.copyWith(
              color:
                  isDark ? AppTheme.darkOnSecondary : AppTheme.lightOnPrimary,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            _currentSong?.artist ?? _currentEpisode?.episodeTitle ?? "Artist",
            style: theme.textTheme.bodyMedium?.copyWith(
              color:
                  (isDark ? AppTheme.darkOnSecondary : AppTheme.lightOnPrimary)
                      .withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
          if (_isPlayAllActive) ...[
            const SizedBox(height: AppTheme.spacingMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.skip_previous,
                      color: isDark
                          ? AppTheme.darkOnSecondary
                          : AppTheme.lightOnPrimary),
                  onPressed: _currentIndex > 0 ? _playPrevious : null,
                ),
                IconButton(
                  icon: Icon(Icons.stop,
                      color: isDark
                          ? AppTheme.darkOnSecondary
                          : AppTheme.lightOnPrimary),
                  onPressed: _stopPlayAll,
                ),
                IconButton(
                  icon: Icon(Icons.skip_next,
                      color: isDark
                          ? AppTheme.darkOnSecondary
                          : AppTheme.lightOnPrimary),
                  onPressed:
                      _currentIndex < _playQueue.length - 1 ? _playNext : null,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabContent(NostalgiaProvider provider, List<Song> songs) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: theme.colorScheme.onSurface, width: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = 'Songs'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedTab == 'Songs'
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Text(
                    "Songs",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _selectedTab == 'Songs'
                          ? (isDark
                              ? AppTheme.darkOnPrimary
                              : AppTheme.lightOnPrimary)
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = 'TV'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedTab == 'TV'
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Text(
                    "TV",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _selectedTab == 'TV'
                          ? (isDark
                              ? AppTheme.darkOnPrimary
                              : AppTheme.lightOnPrimary)
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppTheme.spacingMd),
      if (_selectedTab == 'Songs') ..._buildSongsView(songs),
      if (_selectedTab == 'TV') ..._buildTVView(provider.episodes),
    ]);
  }

  void _confirmDelete(Song song) async {
    final provider = context.read<NostalgiaProvider>();
    final currentUid = provider.currentUserId;

    if (song.addedByUid != currentUid) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Song?"),
        content: const Text(
            "Delete this song? This removes it for the whole group."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final groupId = provider.currentGroup?.id;
      final weekId = provider.currentWeekId;
      if (groupId != null && weekId != null) {
        try {
          await FirestoreService().deleteSong(groupId, weekId, song.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Song deleted")),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Failed to delete: $e")),
            );
          }
        }
      }
    }
  }

  void _confirmDeleteEpisode(Episode episode) async {
    final provider = context.read<NostalgiaProvider>();
    final currentUid = provider.currentUserId;

    if (episode.addedByUid != currentUid) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Episode?"),
        content: const Text(
            "Delete this episode? This removes it for the whole group."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final groupId = provider.currentGroup?.id;
      final weekId = provider.currentWeekId;
      if (groupId != null && weekId != null) {
        try {
          await FirestoreService().deleteEpisode(groupId, weekId, episode.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Episode deleted")),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Failed to delete: $e")),
            );
          }
        }
      }
    }
  }

  List<Widget> _buildSongsView(List<Song> songs) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<NostalgiaProvider>();
    final group = provider.currentGroup;
    final songCap = group?.songCapPerUser ?? 7;
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Group Contributions",
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppTheme.darkPrimaryText
                      : AppTheme.lightPrimaryText)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (!_isPlayAllActive) ...[
                GestureDetector(
                  onTap: () =>
                      setState(() => _shuffleEnabled = !_shuffleEnabled),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _shuffleEnabled
                          ? theme.colorScheme.primary
                          : theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      border: Border.all(
                          color: theme.colorScheme.onSurface, width: 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shuffle,
                            color: _shuffleEnabled
                                ? (isDark
                                    ? AppTheme.darkOnPrimary
                                    : AppTheme.lightOnPrimary)
                                : theme.colorScheme.onSurface,
                            size: 16),
                        const SizedBox(width: 4),
                        Text("Shuffle",
                            style: TextStyle(
                                color: _shuffleEnabled
                                    ? (isDark
                                        ? AppTheme.darkOnPrimary
                                        : AppTheme.lightOnPrimary)
                                    : theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                if (_shuffleEnabled)
                  PopupMenuButton<String>(
                    initialValue: _shuffleMode,
                    onSelected: (value) => setState(() => _shuffleMode = value),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                          value: 'Random', child: Text('Random')),
                      const PopupMenuItem(
                          value: 'By User', child: Text('By User')),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiary,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                        border: Border.all(
                            color: theme.colorScheme.onSurface, width: 2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_shuffleMode,
                              style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down,
                              color: theme.colorScheme.onSurface, size: 16),
                        ],
                      ),
                    ),
                  ),
                GestureDetector(
                  onTap: _startPlayAll,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      border: Border.all(
                          color: theme.colorScheme.onSurface, width: 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow,
                            color: isDark
                                ? AppTheme.darkOnPrimary
                                : AppTheme.lightOnPrimary,
                            size: 16),
                        const SizedBox(width: 4),
                        Text("Play All",
                            style: TextStyle(
                                color: isDark
                                    ? AppTheme.darkOnPrimary
                                    : AppTheme.lightOnPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border:
                      Border.all(color: theme.colorScheme.onSurface, width: 2),
                ),
                child: Text("${songs.length} / $songCap Songs",
                    style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: AppTheme.spacingMd),
      Expanded(
        child: ListView.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            final isCurrent = _currentSong?.id == song.id;
            return _SongItemWithReactions(
              song: song,
              isPlaying: isCurrent,
              onPlay: () => _playSpecificSong(song),
              onDelete: () => _confirmDelete(song),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _buildTVView(List<Episode> episodes) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<NostalgiaProvider>();
    final group = provider.currentGroup;
    final episodeCap = group?.episodeCapPerUser ?? 1;
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("TV Episodes",
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppTheme.darkPrimaryText
                      : AppTheme.lightPrimaryText)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              border: Border.all(color: theme.colorScheme.onSurface, width: 2),
            ),
            child: Text("${episodes.length} / $episodeCap Episodes",
                style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
        ],
      ),
      const SizedBox(height: AppTheme.spacingMd),
      Expanded(
        child: episodes.isEmpty
            ? Center(
                child: Text(
                  "No TV episodes yet",
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppTheme.darkSecondaryText
                          : AppTheme.lightSecondaryText),
                ),
              )
            : ListView.builder(
                itemCount: episodes.length,
                itemBuilder: (context, index) {
                  final episode = episodes[index];
                  final isCurrent = _currentEpisode?.id == episode.id;
                  return _EpisodeItem(
                    episode: episode,
                    isPlaying: isCurrent,
                    onPlay: () => _playEpisode(episode),
                    onDelete: () => _confirmDeleteEpisode(episode),
                  );
                },
              ),
      ),
    ];
  }
}

class _SongItemWithReactions extends StatelessWidget {
  final Song song;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  const _SongItemWithReactions({
    required this.song,
    required this.isPlaying,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NostalgiaProvider>(context, listen: false);
    final firestoreService = FirestoreService();
    final groupId = provider.currentGroup?.id;
    final weekId = provider.currentWeekId;
    final currentUid = provider.currentUserId;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (groupId == null || weekId == null) return const SizedBox();

    return StreamBuilder<Map<String, int>>(
      stream: firestoreService.streamReactionCounts(groupId, weekId, song.id),
      builder: (context, snapshot) {
        final reactionCounts = snapshot.data ?? {};
        final canDelete = song.addedByUid == currentUid;

        return Container(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          decoration: BoxDecoration(
            color: isPlaying
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
                color: isPlaying
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
                width: 2),
            boxShadow: AppTheme.shadowSm,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: onPlay,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkSecondary
                            : AppTheme.lightSecondary,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(
                            color: theme.colorScheme.onSurface, width: 2),
                      ),
                      child: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow_rounded,
                          color: isDark
                              ? AppTheme.darkOnSecondary
                              : AppTheme.lightOnPrimary,
                          size: 32),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(song.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? AppTheme.darkPrimaryText
                                    : AppTheme.lightPrimaryText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(song.artist,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppTheme.darkSecondaryText
                                    : AppTheme.lightSecondaryText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                  color: theme.colorScheme.tertiary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: theme.colorScheme.onSurface)),
                              child: Center(
                                  child: Text(
                                      song.addedByName.isNotEmpty
                                          ? song.addedByName.substring(0, 1)
                                          : "?",
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold))),
                            ),
                            const SizedBox(width: 4),
                            Text("Added by ${song.addedByName}",
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (canDelete)
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red, size: 20),
                      onPressed: onDelete,
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Row(
                children: [
                  _ReactionButton(
                    icon: '👍',
                    count: reactionCounts['like'] ?? 0,
                    onTap: () async {
                      final current = await firestoreService.getUserReaction(
                          groupId: groupId,
                          weekId: weekId,
                          songId: song.id,
                          uid: currentUid);
                      if (current == 'like') {
                        await firestoreService.removeReaction(
                            groupId: groupId,
                            weekId: weekId,
                            songId: song.id,
                            uid: currentUid);
                      } else {
                        await firestoreService.addReaction(
                            groupId: groupId,
                            weekId: weekId,
                            songId: song.id,
                            uid: currentUid,
                            type: 'like');
                      }
                    },
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  _ReactionButton(
                    icon: '😂',
                    count: reactionCounts['funny'] ?? 0,
                    onTap: () async {
                      final current = await firestoreService.getUserReaction(
                          groupId: groupId,
                          weekId: weekId,
                          songId: song.id,
                          uid: currentUid);
                      if (current == 'funny') {
                        await firestoreService.removeReaction(
                            groupId: groupId,
                            weekId: weekId,
                            songId: song.id,
                            uid: currentUid);
                      } else {
                        await firestoreService.addReaction(
                            groupId: groupId,
                            weekId: weekId,
                            songId: song.id,
                            uid: currentUid,
                            type: 'funny');
                      }
                    },
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  _ReactionButton(
                    icon: '😴',
                    count: reactionCounts['sleep'] ?? 0,
                    onTap: () async {
                      final current = await firestoreService.getUserReaction(
                          groupId: groupId,
                          weekId: weekId,
                          songId: song.id,
                          uid: currentUid);
                      if (current == 'sleep') {
                        await firestoreService.removeReaction(
                            groupId: groupId,
                            weekId: weekId,
                            songId: song.id,
                            uid: currentUid);
                      } else {
                        await firestoreService.addReaction(
                            groupId: groupId,
                            weekId: weekId,
                            songId: song.id,
                            uid: currentUid,
                            type: 'sleep');
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final String icon;
  final int count;
  final VoidCallback onTap;

  const _ReactionButton(
      {required this.icon, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: count > 0
              ? theme.colorScheme.primary.withValues(alpha: 0.2)
              : theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
              color: count > 0 ? theme.colorScheme.primary : theme.dividerColor,
              width: 2),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text('$count',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface)),
            ],
          ],
        ),
      ),
    );
  }
}

class _EpisodeItem extends StatelessWidget {
  final Episode episode;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  const _EpisodeItem({
    required this.episode,
    required this.isPlaying,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NostalgiaProvider>(context, listen: false);
    final currentUid = provider.currentUserId;
    final canDelete = episode.addedByUid == currentUid;
    final thumbnailUrl = episode.youtubeId.isNotEmpty
        ? 'https://img.youtube.com/vi/${episode.youtubeId}/hqdefault.jpg'
        : '';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: isPlaying
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
            color: isPlaying
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
            width: 2),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onPlay,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              child: thumbnailUrl.isNotEmpty
                  ? Image.network(
                      thumbnailUrl,
                      width: 80,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80,
                        height: 60,
                        color: isDark
                            ? AppTheme.darkSecondary
                            : AppTheme.lightSecondary,
                        child: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow_rounded,
                            color: isDark
                                ? AppTheme.darkOnSecondary
                                : AppTheme.lightOnPrimary,
                            size: 32),
                      ),
                    )
                  : Container(
                      width: 80,
                      height: 60,
                      color: isDark
                          ? AppTheme.darkSecondary
                          : AppTheme.lightSecondary,
                      child: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow_rounded,
                          color: isDark
                              ? AppTheme.darkOnSecondary
                              : AppTheme.lightOnPrimary,
                          size: 32),
                    ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  episode.showTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppTheme.darkPrimaryText
                        : AppTheme.lightPrimaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  episode.episodeTitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppTheme.darkSecondaryText
                        : AppTheme.lightSecondaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiary,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.colorScheme.onSurface),
                      ),
                      child: Center(
                        child: Text(
                          episode.addedByName.isNotEmpty
                              ? episode.addedByName.substring(0, 1)
                              : "?",
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Added by ${episode.addedByName}",
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (canDelete)
            IconButton(
              icon:
                  const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
