import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../state.dart';
import '../components/theme_toggle.dart';
import '../components/movie_trailer_sheet.dart';
import '../models/tv_discovery_result.dart';
import '../services/tv_discovery_service.dart';

class AddTVEpisodeScreen extends StatefulWidget {
  const AddTVEpisodeScreen({super.key});

  @override
  State<AddTVEpisodeScreen> createState() => _AddTVEpisodeScreenState();
}

class _AddTVEpisodeScreenState extends State<AddTVEpisodeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TvDiscoveryService _tvDiscoveryService = TvDiscoveryService();

  List<TvDiscoveryResult> _results = [];
  bool _searching = false;
  bool _saving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _getUserEpisodeCount(NostalgiaProvider provider) {
    final uid = provider.currentUserProfile?.uid;
    if (uid == null) return provider.episodes.length;
    return provider.episodes
        .where((episode) => episode.addedByUid == uid)
        .length;
  }

  int _getEpisodeCap(NostalgiaProvider provider) {
    return provider.currentGroup?.episodeCapPerUser ?? 1;
  }

  bool _isYearMatch(TvDiscoveryResult show, int year) {
    return show.isRunningInYear(year);
  }

  List<String> _suggestionsForYear(int year) {
    if (year < 1985) {
      return ['Classic Sitcoms', 'Detective Shows', 'Variety TV', 'Cartoons'];
    }
    if (year < 1995) {
      return ['90s Sitcoms', 'Sci-Fi TV', 'Prime Time Drama', 'MTV Era Shows'];
    }
    if (year < 2005) {
      return ['Y2K Shows', 'Teen Drama', 'Reality TV', 'Animation'];
    }
    return ['Prestige TV', 'Streaming Originals', 'Crime Drama', 'Comedy'];
  }

  Future<void> _searchShows(int year, {String? queryOverride}) async {
    final query = (queryOverride ?? _searchController.text).trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _errorMessage = null;
    });
    try {
      final results = await _tvDiscoveryService.searchShows(
        query,
        yearHint: year,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        if (results.isEmpty) {
          _errorMessage =
              'No shows found for "$query". Try another title, actor, or genre.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not search shows right now. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _previewTrailer(TvDiscoveryResult show, int year) async {
    try {
      final trailerId = await _tvDiscoveryService.findTrailerVideoId(
        showTitle: show.title,
        year: show.premieredYear ?? year,
      );
      if (!mounted) return;
      await showMovieTrailerSheet(
        context,
        title: show.title,
        trailerYoutubeId: trailerId,
        trailerYoutubeUrl:
            trailerId == null ? null : 'https://www.youtube.com/watch?v=$trailerId',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to preview trailer: $e')),
      );
    }
  }

  Future<void> _pickShow(TvDiscoveryResult show, int year) async {
    final provider = context.read<NostalgiaProvider>();
    final userEpisodeCount = _getUserEpisodeCount(provider);
    final episodeCap = _getEpisodeCap(provider);
    if (userEpisodeCount >= episodeCap) {
      _showLimitDialog(episodeCap: episodeCap);
      return;
    }
    if (!_isYearMatch(show, year)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${show.title} was not running in $year.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final trailerId = await _tvDiscoveryService.findTrailerVideoId(
        showTitle: show.title,
        year: show.premieredYear ?? year,
      );
      if (trailerId == null || trailerId.isEmpty) {
        throw Exception('No trailer found for this show.');
      }

      final success = await provider.addEpisode(
        showTitle: show.title,
        episodeTitle: show.genresText.isEmpty
            ? 'Official Trailer'
            : '${show.genresText} • Official Trailer',
        youtubeId: trailerId,
        youtubeUrl: 'https://www.youtube.com/watch?v=$trailerId',
      );

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${show.title} to this week!')),
        );
        context.pop();
      } else {
        final refreshedCount = _getUserEpisodeCount(provider);
        if (refreshedCount >= episodeCap) {
          _showLimitDialog(episodeCap: episodeCap);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to add show. Please try again.')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save show pick: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showLimitDialog({required int episodeCap}) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          side: BorderSide(color: theme.colorScheme.onSurface, width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Episode Limit', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: Text(
          'You have reached your weekly cap ($episodeCap/$episodeCap episodes).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NostalgiaProvider>();
    final group = provider.currentGroup;
    final userEpisodeCount = _getUserEpisodeCount(provider);
    final episodeCap = _getEpisodeCap(provider);
    final year = group?.currentYear ?? 1990;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryText =
        isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText;
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final accent = theme.colorScheme.tertiary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
          onPressed: () => context.pop(),
        ),
        title: Column(
          children: [
            Text(
              "TV TIME MACHINE",
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              "THE $year",
              style: theme.textTheme.labelLarge?.copyWith(
                color: onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Ask AI Assistant',
            onPressed: () => context.push('/assistant'),
            icon: Icon(Icons.smart_toy_rounded, color: theme.colorScheme.primary),
          ),
          const ThemeToggle(),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: accent, width: 2),
                  boxShadow: AppTheme.shadowSm,
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: accent, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'AI Show Finder: describe what you remember and pick a show that was running in $year.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Wrap(
                spacing: AppTheme.spacingSm,
                runSpacing: AppTheme.spacingSm,
                children: _suggestionsForYear(year)
                    .map((label) => ActionChip(
                          label: Text(label),
                          onPressed: () {
                            _searchController.text = '$label $year';
                            _searchShows(year, queryOverride: '$label $year');
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMd,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: onSurface, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: onSurface),
                    const SizedBox(width: AppTheme.spacingMd),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: onSurface),
                        cursorColor: onSurface,
                        decoration: const InputDecoration(
                          filled: false,
                          hintText: 'Search show title, actor, vibe, network...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        onSubmitted: (_) => _searchShows(year),
                      ),
                    ),
                    TextButton(
                      onPressed: _searching || _saving
                          ? null
                          : () => _searchShows(year),
                      child: _searching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('SEARCH'),
                    ),
                  ],
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: AppTheme.spacingMd),
              Text(
                '$userEpisodeCount / $episodeCap used this week',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: secondaryText,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              if (_results.isEmpty && !_searching)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingLg),
                  child: Text(
                    'Find TV shows that were running in $year.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: secondaryText,
                    ),
                  ),
                ),
              ..._results.map(
                (show) {
                  final isMatch = _isYearMatch(show, year);
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(
                        color: isMatch ? theme.dividerColor : Colors.red.shade300,
                        width: 2,
                      ),
                    ),
                    child: ListTile(
                      leading: show.posterUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSm),
                              child: Image.network(
                                show.posterUrl,
                                width: 50,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.tv_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            )
                          : Icon(Icons.tv_rounded, color: theme.colorScheme.primary),
                      title: Text(
                        show.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${show.runRangeText}'
                        '${show.genresText.isNotEmpty ? ' • ${show.genresText}' : ''}\n'
                        '${isMatch ? 'Running in $year' : 'Not running in $year'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Preview trailer',
                            onPressed: _saving ? null : () => _previewTrailer(show, year),
                            icon: Icon(Icons.play_circle_fill_rounded,
                                color: theme.colorScheme.primary),
                          ),
                          IconButton(
                            tooltip: isMatch ? 'Pick this show' : 'Not running in $year',
                            onPressed:
                                _saving || !isMatch ? null : () => _pickShow(show, year),
                            icon: Icon(
                              Icons.check_circle_rounded,
                              color: isMatch
                                  ? theme.colorScheme.secondary
                                  : theme.disabledColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppTheme.spacingSm),
              OutlinedButton.icon(
                onPressed: () => context.push('/assistant'),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Need help? Ask Nostalgia Assistant'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
