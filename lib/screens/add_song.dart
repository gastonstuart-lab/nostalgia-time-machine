import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../state.dart';
import '../services/youtube_service.dart';
import '../models/youtube_search_result.dart';
import '../components/theme_toggle.dart';

class AddSongScreen extends StatefulWidget {
  const AddSongScreen({super.key});

  @override
  State<AddSongScreen> createState() => _AddSongScreenState();
}

class _AddSongScreenState extends State<AddSongScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final YouTubeService _youtubeService = YouTubeService();
  List<YouTubeSearchResult> _results = [];
  bool _isSearching = false;
  String? _errorMessage;
  int _suggestionRotation = 0;

  int _getUserSongCount(NostalgiaProvider provider) {
    final uid = provider.currentUserProfile?.uid;
    if (uid == null) return provider.songs.length;
    return provider.songs.where((song) => song.addedByUid == uid).length;
  }

  int _getSongCap(NostalgiaProvider provider) {
    return provider.currentGroup?.songCapPerUser ?? 7;
  }

  Future<void> _search([String? queryOverride]) async {
    final query = (queryOverride ?? _searchController.text).trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final results = await _youtubeService.searchVideos(
        query,
        maxResults: 10,
        videoCategoryId: '10',
      );
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = e.toString().contains('API key not configured')
              ? 'YouTube API key not configured. Please add your API key in lib/config/youtube_config.dart'
              : 'Failed to search YouTube. Please try again.';
        });
      }
    }
  }

  List<String> _suggestionPoolForYear(int year) {
    if (year < 1980) {
      return [
        'Classic Rock',
        'Motown Soul',
        'Disco Dance',
        'Funk Grooves',
        'Singer Songwriter',
        'Psychedelic Rock',
      ];
    }
    if (year < 1990) {
      return [
        'Synth Pop',
        'New Wave',
        'Hair Metal',
        'Early Hip Hop',
        'Power Ballads',
        'Dance Pop',
      ];
    }
    if (year < 2000) {
      return [
        'Grunge Anthems',
        'Eurodance Hits',
        'West Coast Rap',
        'R&B Classics',
        'Britpop',
        'Pop Punk',
      ];
    }
    if (year < 2010) {
      return [
        'Y2K Pop',
        'Emo Rock',
        'Crunk Party',
        'Indie Rock',
        'Neptunes Era',
        'Garage Rock Revival',
      ];
    }
    return [
      'EDM Bangers',
      'Indie Pop',
      'Trap Anthems',
      'K-Pop Hits',
      'Bedroom Pop',
      'Afrobeats',
    ];
  }

  List<String> _visibleSuggestionsForYear(int year) {
    final pool = _suggestionPoolForYear(year);
    if (pool.length <= 4) return pool;
    final start = (_suggestionRotation * 4) % pool.length;
    final rotated = [...pool.sublist(start), ...pool.sublist(0, start)];
    return rotated.take(4).toList();
  }

  void _refreshSuggestions() {
    setState(() {
      _suggestionRotation++;
    });
  }

  void _handleSuggestionTap(String label, int year) {
    final query = '$label $year songs';
    _searchController.text = query;
    _search(query);
  }

  Future<void> _addSongFromSearch(YouTubeSearchResult result) async {
    final provider = context.read<NostalgiaProvider>();
    final userSongCount = _getUserSongCount(provider);
    final songCap = _getSongCap(provider);

    // Check limit before attempting
    if (userSongCount >= songCap) {
      if (!mounted) return;
      _showLimitDialog(songCap: songCap);
      return;
    }

    final youtubeUrl = 'https://www.youtube.com/watch?v=${result.videoId}';

    final success = await provider.addSong(
      title: result.title,
      artist: result.channelTitle,
      youtubeId: result.videoId,
      youtubeUrl: youtubeUrl,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Added ${result.title} to the playlist!")),
      );
      context.pop();
    } else {
      final refreshedCount = _getUserSongCount(provider);
      if (refreshedCount >= songCap) {
        _showLimitDialog(songCap: songCap);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Failed to add song. Please try again.")),
        );
      }
    }
  }

  void _showLimitDialog({required int songCap}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          side: const BorderSide(color: AppTheme.lightOnSurface, width: 3),
        ),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Week Full', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: Text(
          'You have reached your weekly cap ($songCap/$songCap songs).',
          style: TextStyle(color: AppTheme.lightPrimaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NostalgiaProvider>();
    final group = provider.currentGroup;
    final userSongCount = _getUserSongCount(provider);
    final songCap = _getSongCap(provider);
    final year = group?.currentYear ?? 1990;
    final aiSuggestions = _visibleSuggestionsForYear(year);

    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      appBar: AppBar(
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
          onPressed: () => context.pop(),
        ),
        title: Text("ADD A TRACK",
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900)),
        actions: const [
          ThemeToggle(),
          SizedBox(width: 16),
        ],
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text("CURRENT YEAR: ",
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                        color: AppTheme.lightSecondaryText)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.lightPrimary,
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusSm),
                              ),
                              child: Text(
                                "$year",
                                style: const TextStyle(
                                    color: AppTheme.lightOnPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.lightAccent,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppTheme.lightOnSurface, width: 3),
                          ),
                          child: Center(
                            child: Text(
                              "$userSongCount/$songCap",
                              style: const TextStyle(
                                  color: AppTheme.lightOnSurface,
                                  fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingLg),

                    // Search Input
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingMd,
                          vertical: AppTheme.spacingSm),
                      decoration: BoxDecoration(
                        color: AppTheme.lightSurface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(
                            color: AppTheme.lightOnSurface, width: 3),
                        boxShadow: AppTheme.shadowMd,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search,
                              color: AppTheme.lightOnSurface),
                          const SizedBox(width: AppTheme.spacingMd),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: "Search YouTube...",
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                              onSubmitted: (_) => _search(),
                            ),
                          ),
                          GestureDetector(
                            onTap: _search,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.lightSecondary,
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusMd),
                              ),
                              child: const Text(
                                "SEARCH",
                                style: TextStyle(
                                    color: AppTheme.lightOnPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacingMd),

                    // Optional direct YouTube URL input
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingMd,
                          vertical: AppTheme.spacingSm),
                      decoration: BoxDecoration(
                        color: AppTheme.lightSurface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(
                            color: AppTheme.lightOnSurface, width: 3),
                        boxShadow: AppTheme.shadowSm,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.link, color: AppTheme.lightPrimary),
                          const SizedBox(width: AppTheme.spacingMd),
                          Expanded(
                            child: TextField(
                              controller: _urlController,
                              decoration: const InputDecoration(
                                hintText: "Paste YouTube URL (optional)",
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacingMd),

                    // AI Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome,
                                color: AppTheme.lightAccent, size: 20),
                            const SizedBox(width: 4),
                            Text("AI NOSTALGIA ASSISTANT",
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                        color: AppTheme.lightAccent,
                                        fontWeight: FontWeight.w800)),
                          ],
                        ),
                        GestureDetector(
                          onTap: _refreshSuggestions,
                          child: Text("REFRESH",
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      color: AppTheme.lightSecondary,
                                      fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: aiSuggestions
                            .map((label) => _AIChip(
                                  label: label,
                                  onTap: () => _handleSuggestionTap(label, year),
                                ))
                            .toList(),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacingLg),

                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingMd),
                        margin:
                            const EdgeInsets.only(bottom: AppTheme.spacingMd),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(color: Colors.red, width: 2),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: AppTheme.spacingSm),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_isSearching)
                      const Center(child: CircularProgressIndicator())
                    else if (_results.isNotEmpty)
                      ..._results.map((result) => _YouTubeResultCard(
                            result: result,
                            onAdd: () => _addSongFromSearch(result),
                            isDisabled: userSongCount >= songCap,
                          ))
                    else
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingXl),
                          child: Text(
                            "Search for hits from $year!",
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppTheme.lightSecondaryText),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AIChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AIChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: AppTheme.spacingSm),
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingSm),
        decoration: BoxDecoration(
          color: AppTheme.lightBackground,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(color: AppTheme.lightAccent, width: 2),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome,
                size: 14, color: AppTheme.lightAccent),
            const SizedBox(width: 4),
            Text(label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.lightOnSurface,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _YouTubeResultCard extends StatelessWidget {
  final YouTubeSearchResult result;
  final VoidCallback onAdd;
  final bool isDisabled;

  const _YouTubeResultCard({
    required this.result,
    required this.onAdd,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.lightOnSurface, width: 3),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(9),
              bottomLeft: Radius.circular(9),
            ),
            child: result.thumbnailUrl.isNotEmpty
                ? Image.network(
                    result.thumbnailUrl,
                    width: 120,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 120,
                      height: 90,
                      color: AppTheme.lightSecondary,
                      child: const Icon(Icons.music_note,
                          color: AppTheme.lightOnPrimary, size: 40),
                    ),
                  )
                : Container(
                    width: 120,
                    height: 90,
                    color: AppTheme.lightSecondary,
                    child: const Icon(Icons.music_note,
                        color: AppTheme.lightOnPrimary, size: 40),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.lightPrimaryText,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person,
                          size: 12, color: AppTheme.lightSecondaryText),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          result.channelTitle,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppTheme.lightSecondaryText),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: isDisabled ? null : onAdd,
            icon: Icon(
              Icons.add_circle,
              color: isDisabled ? Colors.grey : AppTheme.lightSecondary,
              size: 32,
            ),
          ),
          const SizedBox(width: AppTheme.spacingSm),
        ],
      ),
    );
  }
}
