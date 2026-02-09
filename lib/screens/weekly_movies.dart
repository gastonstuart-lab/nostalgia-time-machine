import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:nostalgia_time_machine/components/theme_toggle.dart';
import 'package:nostalgia_time_machine/models/movie.dart';
import 'package:nostalgia_time_machine/services/firestore_service.dart';
import 'package:nostalgia_time_machine/state.dart';
import 'package:nostalgia_time_machine/theme.dart';

class WeeklyMoviesScreen extends StatelessWidget {
  const WeeklyMoviesScreen({super.key});

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
    final provider = context.watch<NostalgiaProvider>();
    final group = provider.currentGroup;
    final weekId = provider.currentWeekId;
    final currentUid = provider.currentUserId;
    final isAdmin = group != null && group.adminUid == currentUid;
    if (group == null || weekId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
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
                return const Center(child: CircularProgressIndicator());
              }
              final movies = snapshot.data ?? [];
              if (movies.isEmpty) {
                return Center(
                  child: Text(
                    'No movie picks yet.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppTheme.lightSecondaryText),
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
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                    decoration: BoxDecoration(
                      color: AppTheme.lightSurface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border:
                          Border.all(color: AppTheme.lightDivider, width: 2),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.local_movies_rounded,
                          color: AppTheme.lightPrimary),
                      title: Text(movie.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(subtitle,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: canDelete
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () => _deleteMovie(
                                context,
                                groupId: group.id,
                                weekId: weekId,
                                movieId: movie.id,
                              ),
                            )
                          : null,
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
        backgroundColor: AppTheme.lightPrimary,
        foregroundColor: AppTheme.lightOnPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Pick Movie'),
      ),
    );
  }
}
