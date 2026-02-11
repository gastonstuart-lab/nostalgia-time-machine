import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:nostalgia_time_machine/components/theme_toggle.dart';
import 'package:nostalgia_time_machine/services/firestore_service.dart';
import 'package:nostalgia_time_machine/services/movie_discovery_service.dart';
import 'package:nostalgia_time_machine/state.dart';
import 'package:nostalgia_time_machine/theme.dart';
import 'package:nostalgia_time_machine/models/movie_discovery_result.dart';
import 'package:nostalgia_time_machine/components/movie_trailer_sheet.dart';

class AddMovieScreen extends StatefulWidget {
  const AddMovieScreen({super.key});

  @override
  State<AddMovieScreen> createState() => _AddMovieScreenState();
}

class _AddMovieScreenState extends State<AddMovieScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final MovieDiscoveryService _movieDiscoveryService = MovieDiscoveryService();
  List<MovieDiscoveryResult> _results = [];
  MovieDiscoveryResult? _selectedMovie;
  String? _errorMessage;
  bool _searching = false;
  bool _saving = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showLimitDialog() {
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
            Text('Movie Limit', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: const Text(
          'You already reached your weekly cap (1/1 movies).',
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

  Future<void> _searchMovies(int year) async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _errorMessage = null;
    });
    try {
      final results =
          await _movieDiscoveryService.searchMovies(query, yearHint: year);
      if (!mounted) return;
      setState(() {
        _results = results;
        _selectedMovie = null;
        if (results.isEmpty) {
          _errorMessage =
              'No movie matches found for "$query". Try another title, actor, or quote.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not search movies right now. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  bool _isYearMatch(MovieDiscoveryResult movie, int targetYear) {
    return movie.year != null && movie.year == targetYear;
  }

  Future<void> _previewTrailer(MovieDiscoveryResult movie, int year) async {
    try {
      final trailerId = await _movieDiscoveryService.findTrailerVideoId(
        title: movie.title,
        year: movie.year ?? year,
      );
      if (!mounted) return;
      await showMovieTrailerSheet(
        context,
        title: movie.title,
        trailerYoutubeId: trailerId,
        trailerYoutubeUrl:
            trailerId == null ? null : 'https://www.youtube.com/watch?v=$trailerId',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open trailer: $e')),
      );
    }
  }

  Future<void> _saveMovie(int targetYear) async {
    final provider = context.read<NostalgiaProvider>();
    final groupId = provider.currentGroup?.id;
    final weekId = provider.currentWeekId;
    final userId = provider.currentUserId;

    if (groupId == null || weekId == null || userId.isEmpty) return;

    final selected = _selectedMovie;
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a movie result first.')),
      );
      return;
    }
    if (!_isYearMatch(selected, targetYear)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('That movie is not a $targetYear release. Pick a $targetYear movie.')),
      );
      return;
    }

    final existing =
        await _firestoreService.getMyMoviePickThisWeek(groupId, weekId, userId);
    if (existing != null) {
      _showLimitDialog();
      return;
    }

    setState(() => _saving = true);
    try {
      final trailerId = await _movieDiscoveryService.findTrailerVideoId(
        title: selected.title,
        year: selected.year ?? targetYear,
      );
      await _firestoreService.addMovie(
        groupId: groupId,
        weekId: weekId,
        title: selected.title,
        year: selected.year ?? targetYear,
        posterUrl: selected.posterUrl,
        overview: selected.overview,
        genre: selected.genre,
        trailerYoutubeId: trailerId,
        trailerYoutubeUrl:
            trailerId == null ? null : 'https://www.youtube.com/watch?v=$trailerId',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Movie pick saved!')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('LIMIT_REACHED')) {
        _showLimitDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save movie: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final year =
        context.watch<NostalgiaProvider>().currentGroup?.currentYear ?? 1990;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final accent = theme.colorScheme.tertiary;
    final secondaryText =
        isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText;
    final divider = theme.dividerColor;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Pick a Movie ($year)',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w900),
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
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: accent, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI Movie Finder: type what you remember, then pick a confirmed $year release.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd, vertical: 4),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: onSurface, width: 3),
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
                          hintText:
                              'Search movie title, actor, scene, quote...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        onSubmitted: (_) => _searchMovies(year),
                      ),
                    ),
                    TextButton(
                      onPressed: _searching ? null : () => _searchMovies(year),
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
                const SizedBox(height: AppTheme.spacingMd),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: AppTheme.spacingLg),
              if (_results.isEmpty && !_searching)
                Text(
                  'Search for movies from $year.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: secondaryText,
                      ),
                ),
              ..._results.map(
                (movie) {
                  final isMatch = _isYearMatch(movie, year);
                  final isSelected = _selectedMovie == movie;
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : (isMatch ? divider : Colors.red.shade300),
                        width: 2,
                      ),
                    ),
                    child: ListTile(
                      leading: movie.posterUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSm),
                              child: Image.network(
                                movie.posterUrl,
                                width: 50,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.local_movies_rounded,
                                    color: AppTheme.lightPrimary),
                              ),
                            )
                          : const Icon(Icons.local_movies_rounded,
                              color: AppTheme.lightPrimary),
                      title: Text(
                        movie.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${movie.year ?? 'Unknown year'}'
                        '${movie.genre.isNotEmpty ? ' • ${movie.genre}' : ''}\n'
                        '${isMatch ? 'Matches $year' : 'Not a $year release'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Wrap(
                        spacing: 6,
                        children: [
                          IconButton(
                            tooltip: 'Preview trailer',
                            onPressed: () => _previewTrailer(movie, year),
                            icon: const Icon(Icons.play_circle_fill_rounded),
                          ),
                          IconButton(
                            tooltip: isMatch
                                ? 'Select movie'
                                : 'Not released in $year',
                            onPressed: isMatch
                                ? () => setState(() => _selectedMovie = movie)
                                : null,
                            icon: Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.add_circle_outline_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppTheme.spacingMd),
              ElevatedButton(
                onPressed: _saving ? null : () => _saveMovie(year),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Confirm Movie Pick for $year'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
