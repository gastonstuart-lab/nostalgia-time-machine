import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:nostalgia_time_machine/components/theme_toggle.dart';
import 'package:nostalgia_time_machine/models/movie.dart';
import 'package:nostalgia_time_machine/services/firestore_service.dart';
import 'package:nostalgia_time_machine/state.dart';
import 'package:nostalgia_time_machine/theme.dart';
import 'package:nostalgia_time_machine/widgets/error_state.dart';
import 'package:nostalgia_time_machine/components/movie_trailer_sheet.dart';

class WeeklyMoviesScreen extends StatefulWidget {
  const WeeklyMoviesScreen({super.key});

  @override
  State<WeeklyMoviesScreen> createState() => _WeeklyMoviesScreenState();
}

class _WeeklyMoviesScreenState extends State<WeeklyMoviesScreen> {
  final Set<String> _expandedMovieIds = <String>{};

  Future<void> _openTrailer(BuildContext context, Movie movie) async {
    await showMovieTrailerSheet(
      context,
      title: movie.title,
      trailerYoutubeId: movie.trailerYoutubeId,
      trailerYoutubeUrl: movie.trailerYoutubeUrl,
    );
  }

  void _showMovieInfo(BuildContext context, Movie movie) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText =
        isDark ? AppTheme.darkPrimaryText : AppTheme.lightPrimaryText;
    final secondaryText =
        isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              movie.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: primaryText,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '${movie.year ?? 'Unknown year'}'
              '${(movie.genre ?? '').isNotEmpty ? ' • ${movie.genre}' : ''}'
              ' • added by ${movie.addedByName}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: secondaryText,
                  ),
            ),
            if ((movie.overview ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                movie.overview!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: primaryText,
                      height: 1.4,
                    ),
              ),
            ],
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => _openTrailer(context, movie),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Play Trailer'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMovie(
    BuildContext context, {
    required String groupId,
    required String weekId,
    required String movieId,
  }) async {
    try {
      await FirestoreService().deleteMovie(groupId, weekId, movieId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Movie deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete movie: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText =
        isDark ? AppTheme.darkPrimaryText : AppTheme.lightPrimaryText;
    final secondaryText =
        isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText;
    final cardColor = theme.colorScheme.surface;
    final borderColor = theme.dividerColor;
    final provider = context.watch<NostalgiaProvider>();
    final group = provider.currentGroup;
    final weekId = provider.currentWeekId;
    final currentUid = provider.currentUserId;
    final isAdmin = group != null && group.adminUid == currentUid;
    if (group == null || weekId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Weekly Movie Picks',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        actions: const [
          ThemeToggle(),
          SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: StreamBuilder<List<Movie>>(
            stream: FirestoreService().streamMovies(group.id, weekId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: AppTheme.spacingSm),
                      Text('Loading this week\'s movie picks...'),
                    ],
                  ),
                );
              }
              if (snapshot.hasError) {
                return const ErrorState(
                  message: 'Could not load movie picks right now. Please try again.',
                );
              }
              final movies = snapshot.data ?? [];
              if (movies.isEmpty) {
                return Center(
                  child: Text(
                    'No movie picks yet.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: secondaryText),
                  ),
                );
              }

              return ListView.builder(
                itemCount: movies.length,
                itemBuilder: (context, index) {
                  final movie = movies[index];
                  final canDelete = movie.addedByUid == currentUid || isAdmin;
                  final subtitle = movie.year != null
                      ? '${movie.year} • added by ${movie.addedByName}'
                      : 'added by ${movie.addedByName}';
                  return GestureDetector(
                    onTap: () => _showMovieInfo(context, movie),
                    child: Container(
                    margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(color: borderColor, width: 2),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: movie.posterUrl != null &&
                                  movie.posterUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusSm),
                                  child: Image.network(
                                    movie.posterUrl!,
                                    width: 48,
                                    height: 68,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.local_movies_rounded,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                )
                              : Icon(Icons.local_movies_rounded,
                                  color: theme.colorScheme.primary),
                          title: Text(movie.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(subtitle,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Wrap(
                            spacing: 6,
                            children: [
                              IconButton(
                                icon: Icon(Icons.play_circle_fill_rounded,
                                    color: theme.colorScheme.primary),
                                onPressed: () => _openTrailer(context, movie),
                              ),
                              if (canDelete)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red),
                                  onPressed: () => _deleteMovie(
                                    context,
                                    groupId: group.id,
                                    weekId: weekId,
                                    movieId: movie.id,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if ((movie.overview ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: AppTheme.spacingMd,
                              right: AppTheme.spacingMd,
                              bottom: AppTheme.spacingMd,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      if (_expandedMovieIds.contains(movie.id)) {
                                        _expandedMovieIds.remove(movie.id);
                                      } else {
                                        _expandedMovieIds.add(movie.id);
                                      }
                                    });
                                  },
                                  icon: Icon(
                                    _expandedMovieIds.contains(movie.id)
                                        ? Icons.expand_less_rounded
                                        : Icons.expand_more_rounded,
                                  ),
                                  label: Text(
                                    _expandedMovieIds.contains(movie.id)
                                        ? 'Hide info'
                                        : 'More info',
                                  ),
                                ),
                                if (_expandedMovieIds.contains(movie.id))
                                  Container(
                                    width: double.infinity,
                                    padding:
                                        const EdgeInsets.all(AppTheme.spacingSm),
                                    decoration: BoxDecoration(
                                      color: theme.scaffoldBackgroundColor,
                                      borderRadius: BorderRadius.circular(
                                          AppTheme.radiusMd),
                                      border: Border.all(
                                          color: borderColor, width: 1.5),
                                    ),
                                    child: Text(
                                      movie.overview!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: primaryText,
                                            height: 1.35,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-movie'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Pick Movie'),
      ),
    );
  }
}
