import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/join_create.dart';
import 'screens/weekly_dashboard.dart';
import 'screens/add_song.dart';
import 'screens/add_tv.dart';
import 'screens/group_playlist.dart';
import 'screens/weekly_recap.dart';
import 'screens/share_export.dart';
import 'screens/nostalgia_assistant.dart';
import 'screens/group_settings.dart';
import 'screens/history.dart';
import 'screens/group_chat.dart';
import 'screens/weekly_quiz.dart';
import 'screens/add_movie.dart';
import 'screens/weekly_movies.dart';
import 'screens/welcome.dart';
import 'screens/email_verification.dart';
import 'state.dart';
import 'theme.dart';

class AppRouter {
  static GoRouter createRouter(NostalgiaProvider provider) => GoRouter(
        initialLocation: AppRoutes.splash,
        refreshListenable: provider,
        redirect: (context, state) {
          final isOnSplash = state.matchedLocation == AppRoutes.splash;
          final isOnWelcome = state.matchedLocation == AppRoutes.welcome;
          final isOnEmailVerification =
              state.matchedLocation == AppRoutes.emailVerification;
          final isOnJoinCreate = state.matchedLocation == AppRoutes.joinCreate;
          final isInitialized = provider.isInitialized;
          final authResolved = provider.authResolved;
          final canExitSplash = provider.canExitSplash;
          final isSignedIn = provider.isSignedIn;
          final requiresEmailVerification = provider.requiresEmailVerification;
          final isGroupJoined = provider.isGroupJoined;
          debugPrint(
              '[SPLASH] authResolved=$authResolved, canExitSplash=$canExitSplash, initialized=$isInitialized');

          // Show splash while initializing
          if ((!isInitialized || !authResolved || !canExitSplash) &&
              !isOnSplash) {
            return AppRoutes.splash;
          }

          if (isOnSplash &&
              (!isInitialized || !authResolved || !canExitSplash)) {
            return null;
          }

          // Once initialized, redirect from splash based on group status
          if (isInitialized && isOnSplash) {
            if (!isSignedIn) return AppRoutes.welcome;
            if (requiresEmailVerification) return AppRoutes.emailVerification;
            return isGroupJoined ? AppRoutes.dashboard : AppRoutes.joinCreate;
          }

          if (!isSignedIn && !isOnWelcome) {
            return AppRoutes.welcome;
          }

          if (isSignedIn && requiresEmailVerification && !isOnEmailVerification) {
            return AppRoutes.emailVerification;
          }

          if (isSignedIn &&
              !requiresEmailVerification &&
              (isOnWelcome || isOnEmailVerification)) {
            return isGroupJoined ? AppRoutes.dashboard : AppRoutes.joinCreate;
          }

          // If user has a group and tries to visit join/create, redirect to dashboard
          if (isGroupJoined && isOnJoinCreate) {
            return AppRoutes.dashboard;
          }

          return null; // No redirect needed
        },
        routes: [
          GoRoute(
            path: AppRoutes.splash,
            builder: (context, state) => const SplashScreen(),
          ),
          GoRoute(
            path: AppRoutes.joinCreate,
            builder: (context, state) => const JoinCreateScreen(),
          ),
          GoRoute(
            path: AppRoutes.welcome,
            builder: (context, state) => const WelcomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.emailVerification,
            builder: (context, state) => const EmailVerificationScreen(),
          ),
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const WeeklyDashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.addSong,
            builder: (context, state) => const AddSongScreen(),
          ),
          GoRoute(
            path: AppRoutes.addTV,
            builder: (context, state) => const AddTVEpisodeScreen(),
          ),
          GoRoute(
            path: AppRoutes.playlist,
            builder: (context, state) => const GroupPlaylistScreen(),
          ),
          GoRoute(
            path: AppRoutes.recap,
            builder: (context, state) => const WeeklyRecapScreen(),
          ),
          GoRoute(
            path: AppRoutes.share,
            builder: (context, state) => const ShareExportScreen(),
          ),
          GoRoute(
            path: AppRoutes.assistant,
            builder: (context, state) => const NostalgiaAssistantScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const GroupSettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.history,
            builder: (context, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: AppRoutes.crewChat,
            builder: (context, state) => const GroupChatScreen(),
          ),
          GoRoute(
            path: AppRoutes.weeklyQuiz,
            builder: (context, state) => const WeeklyQuizScreen(),
          ),
          GoRoute(
            path: AppRoutes.addMovie,
            builder: (context, state) => const AddMovieScreen(),
          ),
          GoRoute(
            path: AppRoutes.weeklyMovies,
            builder: (context, state) => const WeeklyMoviesScreen(),
          ),
        ],
      );
}

class AppRoutes {
  static const String splash = '/';
  static const String joinCreate = '/join-create';
  static const String welcome = '/welcome';
  static const String emailVerification = '/email-verification';
  static const String dashboard = '/dashboard';
  static const String addSong = '/add-song';
  static const String addTV = '/add-tv';
  static const String playlist = '/playlist';
  static const String recap = '/recap';
  static const String share = '/share';
  static const String assistant = '/assistant';
  static const String settings = '/settings';
  static const String history = '/history';
  static const String crewChat = '/crew-chat';
  static const String weeklyQuiz = '/weekly-quiz';
  static const String addMovie = '/add-movie';
  static const String weeklyMovies = '/movies';
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _items = <({IconData icon, String label})>[
    (icon: Icons.album, label: 'VINYL'),
    (icon: Icons.library_music, label: 'CASSETTE'),
    (icon: Icons.disc_full, label: 'CD'),
    (icon: Icons.graphic_eq, label: 'STREAM'),
  ];

  Timer? _ticker;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _items.length);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _items[_index];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1020), Color(0xFF1A2238), Color(0xFF0E1628)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: Icon(
                  current.icon,
                  key: ValueKey(current.label),
                  size: 110,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                child: Text(
                  current.label,
                  key: ValueKey('label_${current.label}'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.4,
                      ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              Text(
                'Nostalgia Time Machine',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                'Travel back in time through the music of your life',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              const SizedBox(
                width: 220,
                child: LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
