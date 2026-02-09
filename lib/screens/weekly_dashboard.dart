import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../theme.dart';
import '../state.dart';
import '../services/firestore_service.dart';
import '../models/episode.dart';
import '../models/group_message.dart';
import '../models/quiz_score.dart';
import '../models/movie.dart';
import '../models/decade_score.dart';
import '../models/decade_winner.dart';
import '../components/theme_toggle.dart';

class WeeklyDashboardScreen extends StatefulWidget {
  const WeeklyDashboardScreen({super.key});

  @override
  State<WeeklyDashboardScreen> createState() => _WeeklyDashboardScreenState();
}

class _WeeklyDashboardScreenState extends State<WeeklyDashboardScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _chatController = TextEditingController();
  bool _isAdvancing = false;
  bool _isSendingMessage = false;

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _showAdvanceYearDialog(
      BuildContext context, String groupId, int currentYear) async {
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

  Future<void> _sendChatMessage(String groupId) async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _isSendingMessage) return;

    setState(() => _isSendingMessage = true);

    try {
      final provider = context.read<NostalgiaProvider>();
      final userProfile = provider.currentUserProfile;

      if (userProfile == null) {
        throw Exception('User profile not found');
      }

      await _firestoreService.sendGroupMessage(
        groupId,
        text,
        userProfile.uid,
        userProfile.displayName,
      );

      _chatController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: AppTheme.lightError,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingMessage = false);
      }
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
    final userProfile = provider.currentUserProfile;
    final songs = provider.songs;
    final episodes = provider.episodes;
    final weekId = provider.currentWeekId;

    if (provider.isCheckingAuth ||
        group == null ||
        userProfile == null ||
        weekId == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppTheme.spacingSm),
              Text('Loading your time machine...'),
            ],
          ),
        ),
      );
    }

    // Calculate progress
    final userSongs =
        songs.where((s) => s.addedByUid == userProfile.uid).length;
    final userTV = episodes.any((e) => e.addedByUid == userProfile.uid);
    final songCap = group.songCapPerUser;
    final int? currentYear = group.currentYear > 0 ? group.currentYear : null;
    final int? weekNumber = group.weekIndex > 0 ? group.weekIndex : null;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar with Theme Toggle and Settings
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const ThemeToggle(),
                  const SizedBox(width: AppTheme.spacingSm),
                  GestureDetector(
                    onTap: () => context.push('/settings'),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.onSurface,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.settings_rounded,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMd),
              // Year Circle
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: AppTheme.lightAccent,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: AppTheme.lightOnSurface, width: 6),
                      boxShadow: AppTheme.shadowXl,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "YEAR",
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.lightOnSurface,
                                ),
                          ),
                          Text(
                            currentYear?.toString() ?? "Loading...",
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.lightOnSurface,
                                  fontSize: 48,
                                ),
                          ),
                          Text(
                            currentYear == null || weekNumber == null
                                ? "Loading..."
                                : "WEEK $weekNumber",
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.lightOnSurface,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Decorative ticks
                  Positioned(
                    left: 0,
                    top: 80,
                    child: Container(
                        width: 20,
                        height: 8,
                        decoration: BoxDecoration(
                            color: AppTheme.lightOnSurface,
                            borderRadius: BorderRadius.circular(2))),
                  ),
                  Positioned(
                    right: 0,
                    top: 80,
                    child: Container(
                        width: 20,
                        height: 8,
                        decoration: BoxDecoration(
                            color: AppTheme.lightOnSurface,
                            borderRadius: BorderRadius.circular(2))),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingLg),

              _MagicActionsSection(
                year: group.currentYear,
                onHistory: () => context.push('/history'),
                onPlaylist: () => context.push('/playlist'),
                onAssistant: () => context.push('/assistant'),
              ),
              const SizedBox(height: AppTheme.spacingLg),

              // Group Code Card
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: AppTheme.lightAccent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.lightOnSurface, width: 2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.key_rounded,
                        color: AppTheme.lightOnSurface, size: 20),
                    const SizedBox(width: AppTheme.spacingSm),
                    Text(
                      "Group Code: ",
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.lightOnSurface,
                          ),
                    ),
                    SelectableText(
                      group.code,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.lightOnSurface,
                            letterSpacing: 2,
                          ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: group.code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied group code!')),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.lightBackground,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(
                              color: AppTheme.lightOnSurface, width: 2),
                        ),
                        child: const Icon(Icons.copy_rounded,
                            size: 16, color: AppTheme.lightOnSurface),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingSm),
                    GestureDetector(
                      onTap: () {
                        SharePlus.instance.share(
                          ShareParams(
                              text: 'Join my Rewind crew! Code: ${group.code}'),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.lightSecondary,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(
                              color: const Color(0xFF1E7066), width: 2),
                        ),
                        child: const Icon(Icons.share_rounded,
                            size: 16, color: AppTheme.lightOnPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),

              // Collection Card
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                decoration: BoxDecoration(
                  color: AppTheme.lightBackground,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  border: Border.all(color: AppTheme.lightOnSurface, width: 3),
                  boxShadow: AppTheme.shadowMd,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Your Collection",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.lightPrimaryText,
                                  ),
                            ),
                            Text(
                              "$userSongs of $songCap songs added",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppTheme.lightSecondaryText,
                                  ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => context.push('/add-song'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.lightSecondary,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusLg),
                              border: Border.all(
                                  color: const Color(0xFF1E7066), width: 2),
                            ),
                            child: const Text(
                              "+ ADD",
                              style: TextStyle(
                                color: AppTheme.lightOnPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(songCap, (index) {
                        final filled = index < userSongs;
                        return Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: filled
                                ? AppTheme.lightPrimary
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: filled
                                  ? AppTheme.lightPrimary
                                  : AppTheme.lightDivider,
                              width: 2,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    const Divider(color: AppTheme.lightDivider, thickness: 2),
                    const SizedBox(height: AppTheme.spacingMd),
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.lightPrimary,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(
                                color: const Color(0xFF8F3E02), width: 2),
                          ),
                          child: const Icon(Icons.tv_rounded,
                              color: AppTheme.lightOnPrimary, size: 24),
                        ),
                        const SizedBox(width: AppTheme.spacingMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "TV Episode",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.lightPrimaryText,
                                    ),
                              ),
                              Text(
                                userTV
                                    ? "Added"
                                    : "Missing for ${group.currentYear}",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppTheme.lightPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => context.push('/add-tv'),
                          style: OutlinedButton.styleFrom(
                            side:
                                const BorderSide(color: AppTheme.lightPrimary),
                            foregroundColor: AppTheme.lightPrimary,
                          ),
                          child: Text(userTV ? "VIEW" : "PICK SHOW"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingMd),

              _WeeklyQuizCard(
                groupId: group.id,
                weekId: weekId,
                userId: userProfile.uid,
              ),
              const SizedBox(height: AppTheme.spacingMd),
              _DecadeLeaderboardCard(
                groupId: group.id,
                decadeStart: group.currentDecadeStart,
              ),
              const SizedBox(height: AppTheme.spacingMd),
              _WeeklyMovieCard(
                groupId: group.id,
                weekId: weekId,
                userId: userProfile.uid,
              ),
              const SizedBox(height: AppTheme.spacingMd),

              // This Week's Episode Card
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                decoration: BoxDecoration(
                  color: AppTheme.lightBackground,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  border: Border.all(color: AppTheme.lightOnSurface, width: 3),
                  boxShadow: AppTheme.shadowMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "This Week's Episode",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.lightPrimaryText,
                          ),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    if (episodes.isEmpty)
                      Column(
                        children: [
                          Text(
                            "No episode added yet",
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppTheme.lightSecondaryText,
                                ),
                          ),
                          const SizedBox(height: AppTheme.spacingSm),
                          OutlinedButton.icon(
                            onPressed: () => context.push('/add-tv'),
                            icon: const Icon(Icons.tv_rounded),
                            label: const Text("Add Episode"),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppTheme.lightPrimary),
                              foregroundColor: AppTheme.lightPrimary,
                            ),
                          ),
                        ],
                      )
                    else
                      _ThisWeekEpisodeCard(
                        episode: episodes.first,
                        onOpen: () => context.push('/playlist'),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingMd),

              // Advance Year Button
              if (songs.length >= songCap)
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingLg),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.lightPrimary, AppTheme.lightSecondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    border:
                        Border.all(color: AppTheme.lightOnSurface, width: 3),
                    boxShadow: AppTheme.shadowLg,
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.rocket_launch_rounded,
                        color: AppTheme.lightOnPrimary,
                        size: 32,
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                      Text(
                        'Week Complete!',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.lightOnPrimary,
                            ),
                      ),
                      const SizedBox(height: AppTheme.spacingXs),
                      Text(
                        'Ready to move on?',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.lightOnPrimary,
                            ),
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isAdvancing
                              ? null
                              : () => _showAdvanceYearDialog(
                                    context,
                                    group.id,
                                    group.currentYear,
                                  ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.lightBackground,
                            foregroundColor: AppTheme.lightOnSurface,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusLg),
                              side: const BorderSide(
                                color: AppTheme.lightOnSurface,
                                width: 2,
                              ),
                            ),
                          ),
                          child: _isAdvancing
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.lightOnSurface,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Start Next Year (${group.currentYear + 1})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (songs.length >= songCap)
                const SizedBox(height: AppTheme.spacingMd),

              // Group Chat Card
              _GroupChatCard(
                groupId: group.id,
                currentUserUid: userProfile.uid,
                chatController: _chatController,
                isSending: _isSendingMessage,
                onSendMessage: () => _sendChatMessage(group.id),
              ),
              const SizedBox(height: AppTheme.spacingMd),

              const SizedBox(height: AppTheme.spacingLg),

              // Activity Feed
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Friend Activity",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.lightPrimaryText,
                        ),
                  ),
                  Text(
                    "See All",
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.lightSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMd),
              // Live activity feed from real songs/episodes
              ...songs.take(3).map((song) => _ActivityItem(
                    displayName: song.addedByName,
                    action: 'added a track',
                    title: '${song.title} - ${song.artist}',
                    type: 'music',
                  )),
              ...episodes.take(2).map((episode) => _ActivityItem(
                    displayName: episode.addedByName,
                    action: 'picked a show',
                    title: '${episode.showTitle} - ${episode.episodeTitle}',
                    type: 'tv',
                  )),

              const SizedBox(height: 80), // Fab spacing
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/settings'),
        backgroundColor: AppTheme.lightOnSurface,
        foregroundColor: AppTheme.lightOnPrimary,
        icon: const Icon(Icons.group_add_rounded),
        label: const Text("Invite Friends"),
      ),
    );
  }
}

class _WeeklyQuizCard extends StatelessWidget {
  final String groupId;
  final String weekId;
  final String userId;

  const _WeeklyQuizCard({
    required this.groupId,
    required this.weekId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.lightBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.lightOnSurface, width: 3),
        boxShadow: AppTheme.shadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<QuizScore?>(
            stream:
                firestoreService.listenToUserQuizScore(groupId, weekId, userId),
            builder: (context, snapshot) {
              final hasTakenQuiz = snapshot.data != null;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Weekly Quiz",
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.lightPrimaryText,
                                ),
                      ),
                      if (hasTakenQuiz)
                        Text(
                          "You scored ${snapshot.data!.score}/20",
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.lightSecondaryText,
                                  ),
                        ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () => context.push('/weekly-quiz'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.lightSecondary,
                      foregroundColor: AppTheme.lightOnPrimary,
                    ),
                    child:
                        Text(hasTakenQuiz ? 'View Leaderboard' : 'Take Quiz'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppTheme.spacingMd),
          StreamBuilder<List<QuizScore>>(
            stream: firestoreService.listenToLeaderboard(groupId, weekId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final scores = snapshot.data ?? [];
              if (scores.isEmpty) {
                return Text(
                  "No scores yet this week.",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.lightSecondaryText,
                      ),
                );
              }

              return Column(
                children: scores.take(10).toList().asMap().entries.map((entry) {
                  final rank = entry.key + 1;
                  final score = entry.value;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Text('#$rank',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    title: Text(
                      score.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      '${score.score}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WeeklyMovieCard extends StatelessWidget {
  final String groupId;
  final String weekId;
  final String userId;

  const _WeeklyMovieCard({
    required this.groupId,
    required this.weekId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.lightBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.lightOnSurface, width: 3),
        boxShadow: AppTheme.shadowMd,
      ),
      child: StreamBuilder<List<Movie>>(
        stream: firestoreService.streamMovies(groupId, weekId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final movies = snapshot.data ?? [];
          Movie? myPick;
          for (final movie in movies) {
            if (movie.addedByUid == userId) {
              myPick = movie;
              break;
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Weekly Movie Pick",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.lightPrimaryText,
                    ),
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                myPick != null
                    ? "You picked: ${myPick.title}"
                    : "You haven't picked a movie yet",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.lightSecondaryText,
                    ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Row(
                children: [
                  if (myPick == null)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => context.push('/add-movie'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.lightSecondary,
                          foregroundColor: AppTheme.lightOnPrimary,
                        ),
                        child: const Text('Pick Movie'),
                      ),
                    ),
                  if (myPick == null) const SizedBox(width: AppTheme.spacingMd),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.push('/movies'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.lightPrimary),
                        foregroundColor: AppTheme.lightPrimary,
                      ),
                      child: const Text('View Picks'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DecadeLeaderboardCard extends StatelessWidget {
  final String groupId;
  final int decadeStart;

  const _DecadeLeaderboardCard({
    required this.groupId,
    required this.decadeStart,
  });

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.lightBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.lightOnSurface, width: 3),
        boxShadow: AppTheme.shadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Decade Race (${decadeStart}s)",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.lightPrimaryText,
                ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          StreamBuilder<DecadeWinner?>(
            stream: firestoreService.listenToLatestDecadeWinner(groupId),
            builder: (context, winnerSnapshot) {
              final winner = winnerSnapshot.data;
              if (winner == null) return const SizedBox.shrink();
              return Text(
                "Last decade winner (${winner.decadeStart}s): ${winner.displayName} (${winner.points} pts)",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.lightSecondaryText,
                      fontWeight: FontWeight.w600,
                    ),
              );
            },
          ),
          const SizedBox(height: AppTheme.spacingMd),
          StreamBuilder<List<DecadeScore>>(
            stream: firestoreService.listenToDecadeLeaderboard(
                groupId, decadeStart),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final scores = snapshot.data ?? [];
              if (scores.isEmpty) {
                return Text(
                  "No decade points yet. Take this week's quiz to start.",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.lightSecondaryText,
                      ),
                );
              }

              return Column(
                children: scores.take(10).toList().asMap().entries.map((entry) {
                  final rank = entry.key + 1;
                  final score = entry.value;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Text('#$rank',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    title: Text(
                      score.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      "${score.weeklyWins} weekly wins • ${score.weeksPlayed} weeks",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: Text(
                      "${score.points}",
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MagicActionsSection extends StatelessWidget {
  final int year;
  final VoidCallback onHistory;
  final VoidCallback onPlaylist;
  final VoidCallback onAssistant;

  const _MagicActionsSection({
    required this.year,
    required this.onHistory,
    required this.onPlaylist,
    required this.onAssistant,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isWide)
              Row(
                children: [
                  Expanded(
                    child: _MagicActionCard(
                      icon: Icons.history_rounded,
                      title: 'History',
                      subtitle: 'Replay your previous weeks',
                      backgroundColor: AppTheme.lightBackground,
                      borderColor: AppTheme.lightOnSurface,
                      foregroundColor: AppTheme.lightOnSurface,
                      onTap: onHistory,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _MagicActionCard(
                      icon: Icons.queue_music_rounded,
                      title: 'Open Playlist',
                      subtitle: 'Jump into your group picks',
                      backgroundColor: AppTheme.lightPrimary,
                      borderColor: const Color(0xFF8F3E02),
                      foregroundColor: AppTheme.lightOnPrimary,
                      onTap: onPlaylist,
                    ),
                  ),
                ],
              )
            else ...[
              _MagicActionCard(
                icon: Icons.history_rounded,
                title: 'History',
                subtitle: 'Replay your previous weeks',
                backgroundColor: AppTheme.lightBackground,
                borderColor: AppTheme.lightOnSurface,
                foregroundColor: AppTheme.lightOnSurface,
                onTap: onHistory,
              ),
              const SizedBox(height: 14),
              _MagicActionCard(
                icon: Icons.queue_music_rounded,
                title: 'Open Playlist',
                subtitle: 'Jump into your group picks',
                backgroundColor: AppTheme.lightPrimary,
                borderColor: const Color(0xFF8F3E02),
                foregroundColor: AppTheme.lightOnPrimary,
                onTap: onPlaylist,
              ),
            ],
            const SizedBox(height: 14),
            _MagicActionCard(
              icon: Icons.auto_awesome_rounded,
              title: 'Need help remembering?',
              subtitle:
                  'Ask the Nostalgia Assistant (AI) about $year.',
              backgroundColor: AppTheme.lightSecondary,
              borderColor: const Color(0xFF1E7066),
              foregroundColor: AppTheme.lightOnPrimary,
              onTap: onAssistant,
              prominent: true,
            ),
          ],
        );
      },
    );
  }
}

class _MagicActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;
  final VoidCallback onTap;
  final bool prominent;

  const _MagicActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    required this.borderColor,
    required this.foregroundColor,
    required this.onTap,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: prominent ? 2.5 : 2),
          boxShadow: prominent ? AppTheme.shadowLg : AppTheme.shadowMd,
        ),
        child: Row(
          children: [
            Icon(icon, color: foregroundColor, size: prominent ? 26 : 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: foregroundColor,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: foregroundColor.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: foregroundColor),
          ],
        ),
      ),
    );
  }
}

class _ThisWeekEpisodeCard extends StatefulWidget {
  final Episode episode;
  final VoidCallback onOpen;

  const _ThisWeekEpisodeCard({
    required this.episode,
    required this.onOpen,
  });

  @override
  State<_ThisWeekEpisodeCard> createState() => _ThisWeekEpisodeCardState();
}

class _ThisWeekEpisodeCardState extends State<_ThisWeekEpisodeCard> {
  Future<void> _confirmDelete() async {
    final provider = context.read<NostalgiaProvider>();
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

    if (confirmed == true && mounted) {
      final groupId = provider.currentGroup?.id;
      final weekId = provider.currentWeekId;
      if (groupId != null && weekId != null) {
        try {
          await FirestoreService()
              .deleteEpisode(groupId, weekId, widget.episode.id);
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

  Future<void> _replaceEpisode() async {
    final provider = context.read<NostalgiaProvider>();
    final groupId = provider.currentGroup?.id;
    final weekId = provider.currentWeekId;
    if (groupId != null && weekId != null) {
      try {
        await FirestoreService()
            .deleteEpisode(groupId, weekId, widget.episode.id);
        if (mounted) {
          context.push('/add-tv');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to replace: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NostalgiaProvider>();
    final currentUid = provider.currentUserId;
    final canDelete = widget.episode.addedByUid == currentUid;
    final thumbnailUrl = widget.episode.youtubeId.isNotEmpty
        ? 'https://img.youtube.com/vi/${widget.episode.youtubeId}/hqdefault.jpg'
        : '';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.lightDivider, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.radiusMd - 2),
                  bottomLeft: Radius.circular(AppTheme.radiusMd - 2),
                ),
                child: thumbnailUrl.isNotEmpty
                    ? Image.network(
                        thumbnailUrl,
                        width: 100,
                        height: 75,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 100,
                          height: 75,
                          color: AppTheme.lightPrimary,
                          child: const Icon(Icons.tv,
                              color: AppTheme.lightOnPrimary),
                        ),
                      )
                    : Container(
                        width: 100,
                        height: 75,
                        color: AppTheme.lightPrimary,
                        child: const Icon(Icons.tv,
                            color: AppTheme.lightOnPrimary),
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingSm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.episode.showTitle,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.lightPrimaryText,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.episode.episodeTitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.lightSecondaryText,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: AppTheme.spacingSm),
                child: ElevatedButton(
                  onPressed: widget.onOpen,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.lightPrimary,
                    foregroundColor: AppTheme.lightOnPrimary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text("Open"),
                ),
              ),
            ],
          ),
          if (canDelete) ...[
            const Divider(height: 1, color: AppTheme.lightDivider),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSm, vertical: AppTheme.spacingXs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _replaceEpisode,
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text("Replace"),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.lightSecondary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingXs),
                  TextButton.icon(
                    onPressed: _confirmDelete,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text("Delete"),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String displayName;
  final String action;
  final String title;
  final String type;

  const _ActivityItem({
    required this.displayName,
    required this.action,
    required this.title,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final initials = displayName.isNotEmpty
        ? displayName.substring(0, 1).toUpperCase()
        : 'U';
    final color =
        type == 'music' ? AppTheme.lightSecondary : AppTheme.lightPrimary;

    return Container(
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.lightOnSurface, width: 2),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: AppTheme.lightOnPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.lightPrimaryText,
                          ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      action,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.lightSecondaryText,
                          ),
                    ),
                  ],
                ),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.lightPrimaryText,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingXs),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF8F0),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.lightDivider),
            ),
            child: Icon(
              type == "music" ? Icons.music_note_rounded : Icons.tv_rounded,
              size: 18,
              color: AppTheme.lightSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupChatCard extends StatelessWidget {
  final String groupId;
  final String currentUserUid;
  final TextEditingController chatController;
  final bool isSending;
  final VoidCallback onSendMessage;

  const _GroupChatCard({
    required this.groupId,
    required this.currentUserUid,
    required this.chatController,
    required this.isSending,
    required this.onSendMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.lightBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.lightOnSurface, width: 3),
        boxShadow: AppTheme.shadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Crew Chat",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.lightPrimaryText,
                    ),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/crew-chat'),
                icon: const Icon(Icons.chat_rounded, size: 16),
                label: const Text("Open"),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.lightSecondary),
                  foregroundColor: AppTheme.lightSecondary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppTheme.lightSurface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.lightDivider, width: 2),
            ),
            child: StreamBuilder<List<GroupMessage>>(
              stream: FirestoreService().streamGroupMessages(groupId, limit: 8),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      "Say hello to the crew…",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.lightSecondaryText,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(AppTheme.spacingSm),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isCurrentUser = message.senderUid == currentUserUid;
                    final displayName =
                        isCurrentUser ? 'You' : message.senderName;

                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppTheme.spacingSm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.lightPrimary,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            message.text,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.lightPrimaryText,
                                    ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: chatController,
                  style: const TextStyle(color: AppTheme.lightPrimaryText),
                  cursorColor: AppTheme.lightPrimaryText,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle:
                        const TextStyle(color: AppTheme.lightSecondaryText),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: const BorderSide(
                          color: AppTheme.lightDivider, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: const BorderSide(
                          color: AppTheme.lightDivider, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: const BorderSide(
                          color: AppTheme.lightSecondary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingMd,
                      vertical: AppTheme.spacingSm,
                    ),
                  ),
                  onSubmitted: (_) => onSendMessage(),
                ),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              GestureDetector(
                onTap: isSending ? null : onSendMessage,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSending
                        ? AppTheme.lightDivider
                        : AppTheme.lightSecondary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: isSending
                          ? AppTheme.lightDivider
                          : const Color(0xFF1E7066),
                      width: 2,
                    ),
                  ),
                  child: isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.lightOnPrimary),
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: AppTheme.lightOnPrimary,
                          size: 20,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
