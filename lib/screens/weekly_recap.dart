import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../state.dart';
import '../models/song.dart';
import '../models/episode.dart';
import '../services/firestore_service.dart';

class WeeklyRecapScreen extends StatefulWidget {
  const WeeklyRecapScreen({super.key});

  @override
  State<WeeklyRecapScreen> createState() => _WeeklyRecapScreenState();
}

class _WeeklyRecapScreenState extends State<WeeklyRecapScreen> {
  bool _isAdvancing = false;
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> _showAdvanceYearDialog(String groupId, int currentYear) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Advance to ${currentYear + 1}?'),
        content: Text(
          'This starts a fresh week for ${currentYear + 1}. '
          'Old weeks remain in History.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.lightPrimary,
            ),
            child: const Text('Advance'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _handleAdvanceYear(groupId, currentYear);
    }
  }

  Future<void> _handleAdvanceYear(String groupId, int currentYear) async {
    setState(() => _isAdvancing = true);

    try {
      await _firestoreService.advanceYear(groupId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Advanced to ${currentYear + 1}'),
            backgroundColor: AppTheme.lightSecondary,
          ),
        );
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to advance year: $e'),
            backgroundColor: AppTheme.lightError,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAdvancing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NostalgiaProvider>();
    final group = provider.currentGroup;
    final songs = List<Song>.from(provider.songs);
    final episodes = List<Episode>.from(provider.episodes);

    if (group == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (songs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Recap")),
        body: const Center(child: Text("No songs added yet!")),
      );
    }

    // Sort by most recent for MVP (reactions removed)
    songs.sort((a, b) => b.addedAt.compareTo(a.addedAt));

    final topSong = songs.first;

    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                decoration: const BoxDecoration(
                  color: AppTheme.lightPrimary,
                  border: Border(bottom: BorderSide(color: AppTheme.lightOnSurface, width: 3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: AppTheme.lightOnPrimary),
                          onPressed: () => context.pop(),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.lightAccent,
                            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                            border: Border.all(color: AppTheme.lightOnSurface, width: 2),
                          ),
                          child: Text(
                            "RECAP: ${group.currentYear}",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.lightOnSurface,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.share_rounded, color: AppTheme.lightOnPrimary),
                          onPressed: () => context.push('/share'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    Text(
                      "The Year of Grunge & Growth", // Mock title
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.lightOnPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // AI Summary
              Container(
                margin: const EdgeInsets.all(AppTheme.spacingLg),
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                decoration: BoxDecoration(
                  color: AppTheme.lightSurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  border: Border.all(color: AppTheme.lightAccent, width: 2),
                  boxShadow: AppTheme.shadowMd,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: AppTheme.lightAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "AI NOSTALGIA ASSISTANT",
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.lightAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    Text(
                      "${group.currentYear} was a whirlwind! From the release of The Lion King to the launch of the PlayStation, your group captured the vibe perfectly. You leaned heavily into the Seattle sound but threw in some pop spice. It's clear that your group values flannel shirts and cinematic theme songs this week!",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.lightPrimaryText,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Song of the Week
              Container(
                margin: const EdgeInsets.fromLTRB(AppTheme.spacingLg, 0, AppTheme.spacingLg, AppTheme.spacingLg),
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  border: Border.all(color: AppTheme.lightOnSurface, width: 3),
                  boxShadow: AppTheme.shadowLg,
                  color: Colors.black, // Placeholder for image
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    // Mock image
                    Container(
                      color: Colors.grey.shade800,
                      child: const Center(child: Icon(Icons.music_note, color: Colors.white, size: 64)),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingLg),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.lightAccent,
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            child: Text(
                              "SONG OF THE WEEK",
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.lightPrimaryText,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingXs),
                          Text(
                            topSong.title,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppTheme.lightOnPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "${topSong.artist} • Added by ${topSong.addedByName}",
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.lightOnPrimary,
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.favorite_rounded, color: AppTheme.lightAccent, size: 18),
                                  const SizedBox(width: 4),
                                  const Text(
                                    "Popular",
                                    style: TextStyle(
                                      color: AppTheme.lightOnPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // TV Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "📺 TV Time Machine",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.lightOnSurface,
                          ),
                        ),
                        Text(
                          "See All",
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppTheme.lightSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    if (episodes.isEmpty)
                       const Text("No TV shows picked this week."),
                    ...episodes.map((episode) => _TVCard(episode: episode)),
                  ],
                ),
              ),

              // Playlist Summary
              Container(
                margin: const EdgeInsets.all(AppTheme.spacingLg),
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                decoration: BoxDecoration(
                  color: AppTheme.lightSurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: const Color(0xFF3D2B1F), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Group Playlist",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.lightPrimaryText,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    ...songs.take(5).map((song) => _SongSummaryItem(song: song)),
                    const SizedBox(height: AppTheme.spacingMd),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.music_note),
                      label: const Text("Export to Spotify"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DB954), // Spotify Green
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingXl),
                child: Column(
                  children: [
                    Text(
                      "Ready for ${group.currentYear + 1}?",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.lightSecondaryText,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    ElevatedButton(
                      onPressed: _isAdvancing 
                          ? null 
                          : () => _showAdvanceYearDialog(group.id, group.currentYear),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.lightPrimary,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: _isAdvancing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text("Start Next Year"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingLg),
            ],
          ),
        ),
      ),
    );
  }
}

class _TVCard extends StatelessWidget {
  final Episode episode;

  const _TVCard({required this.episode});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: const Color(0xFF3D2B1F), width: 2),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: const Color(0xFF3D2B1F)),
            ),
            child: const Icon(Icons.tv, color: AppTheme.lightSecondaryText),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  episode.showTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.lightPrimaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  episode.episodeTitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.lightSecondaryText,
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
                      decoration: const BoxDecoration(
                        color: AppTheme.lightAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          episode.addedByName.isNotEmpty ? episode.addedByName.substring(0, 1) : "?",
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Picked by ${episode.addedByName}",
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.lightSecondaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SongSummaryItem extends StatelessWidget {
  final Song song;

  const _SongSummaryItem({required this.song});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.lightDivider)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.lightSecondary,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: const Color(0xFF1D6E64)),
            ),
            child: const Icon(Icons.play_arrow_rounded, color: AppTheme.lightOnPrimary, size: 24),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.lightPrimaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  song.artist,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.lightSecondaryText,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite_rounded, color: AppTheme.lightError, size: 14),
                  const SizedBox(width: 4),
                  const Text(
                    "♥",
                    style: TextStyle(
                      color: AppTheme.lightPrimaryText,
                    ),
                  ),
                ],
              ),
              Text(
                song.addedByName,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.lightHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
