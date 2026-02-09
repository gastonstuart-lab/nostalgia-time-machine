import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../state.dart';
import '../services/firestore_service.dart';
import '../models/song.dart';
import '../models/episode.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NostalgiaProvider>();
    final groupId = provider.currentGroup?.id;

    if (groupId == null) {
      return Scaffold(
        backgroundColor: AppTheme.lightBackground,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('History'),
        ),
        body: const Center(child: Text('No active group')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.lightOnPrimary),
          onPressed: () => context.pop(),
        ),
        backgroundColor: AppTheme.lightPrimary,
        title: Text(
          'Week History',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.lightOnPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('weeks')
            .orderBy('weekStart', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No weeks found'));
          }

          final weeks = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            itemCount: weeks.length,
            itemBuilder: (context, index) {
              final weekDoc = weeks[index];
              final weekData = weekDoc.data() as Map<String, dynamic>;
              final year = weekData['year'] as int;
              final weekStart = (weekData['weekStart'] as Timestamp?)?.toDate();
              final isClosed = weekData['isClosed'] as bool? ?? false;
              final weekId = weekDoc.id;

              return _WeekCard(
                groupId: groupId,
                weekId: weekId,
                year: year,
                weekStart: weekStart,
                isClosed: isClosed,
              );
            },
          );
        },
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  final String groupId;
  final String weekId;
  final int year;
  final DateTime? weekStart;
  final bool isClosed;

  const _WeekCard({
    required this.groupId,
    required this.weekId,
    required this.year,
    required this.weekStart,
    required this.isClosed,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = weekStart != null
        ? DateFormat('MMM d, yyyy').format(weekStart!)
        : 'Unknown date';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _WeekDetailScreen(
              groupId: groupId,
              weekId: weekId,
              year: year,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        decoration: BoxDecoration(
          color: isClosed ? AppTheme.lightSurface : AppTheme.lightAccent,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(color: AppTheme.lightOnSurface, width: 3),
          boxShadow: AppTheme.shadowMd,
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.lightPrimary,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.lightOnSurface, width: 2),
              ),
              child: Center(
                child: Text(
                  '$year',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.lightOnPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Year $year',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.lightPrimaryText,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.lightSecondaryText,
                    ),
                  ),
                  if (isClosed)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.lightSecondary,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        'CLOSED',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.lightOnPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.lightOnSurface, size: 32),
          ],
        ),
      ),
    );
  }
}

class _WeekDetailScreen extends StatelessWidget {
  final String groupId;
  final String weekId;
  final int year;

  const _WeekDetailScreen({
    required this.groupId,
    required this.weekId,
    required this.year,
  });

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.lightOnPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: AppTheme.lightPrimary,
        title: Column(
          children: [
            Text(
              'Year $year',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.lightOnPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Read-Only',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.lightOnPrimary,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Songs Section
              Row(
                children: [
                  const Icon(Icons.music_note_rounded, color: AppTheme.lightSecondary, size: 24),
                  const SizedBox(width: AppTheme.spacingSm),
                  Text(
                    'Songs',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.lightPrimaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMd),
              StreamBuilder<List<Song>>(
                stream: firestoreService.streamSongs(groupId, weekId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(AppTheme.spacingLg),
                      decoration: BoxDecoration(
                        color: AppTheme.lightSurface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(color: AppTheme.lightDivider, width: 2),
                      ),
                      child: const Text('No songs added', textAlign: TextAlign.center),
                    );
                  }

                  final songs = snapshot.data!;
                  return Column(
                    children: songs.map((song) => _SongItem(song: song)).toList(),
                  );
                },
              ),
              const SizedBox(height: AppTheme.spacingXl),

              // Episodes Section
              Row(
                children: [
                  const Icon(Icons.tv_rounded, color: AppTheme.lightPrimary, size: 24),
                  const SizedBox(width: AppTheme.spacingSm),
                  Text(
                    'TV Episodes',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.lightPrimaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMd),
              StreamBuilder<List<Episode>>(
                stream: firestoreService.streamEpisodes(groupId, weekId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(AppTheme.spacingLg),
                      decoration: BoxDecoration(
                        color: AppTheme.lightSurface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(color: AppTheme.lightDivider, width: 2),
                      ),
                      child: const Text('No episodes added', textAlign: TextAlign.center),
                    );
                  }

                  final episodes = snapshot.data!;
                  return Column(
                    children: episodes.map((episode) => _EpisodeItem(episode: episode)).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SongItem extends StatelessWidget {
  final Song song;

  const _SongItem({required this.song});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
    padding: const EdgeInsets.all(AppTheme.spacingMd),
    decoration: BoxDecoration(
      color: AppTheme.lightSurface,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      border: Border.all(color: AppTheme.lightDivider, width: 2),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.lightSecondary,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: const Color(0xFF1E7066), width: 2),
          ),
          child: const Icon(Icons.music_note_rounded, color: AppTheme.lightOnPrimary, size: 24),
        ),
        const SizedBox(width: AppTheme.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.lightPrimaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${song.artist} • Added by ${song.addedByName}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.lightSecondaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _EpisodeItem extends StatelessWidget {
  final Episode episode;

  const _EpisodeItem({required this.episode});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
    padding: const EdgeInsets.all(AppTheme.spacingMd),
    decoration: BoxDecoration(
      color: AppTheme.lightSurface,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      border: Border.all(color: AppTheme.lightDivider, width: 2),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.lightPrimary,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: const Color(0xFF8F3E02), width: 2),
          ),
          child: const Icon(Icons.tv_rounded, color: AppTheme.lightOnPrimary, size: 24),
        ),
        const SizedBox(width: AppTheme.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                episode.showTitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.lightPrimaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${episode.episodeTitle} • Added by ${episode.addedByName}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.lightSecondaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
