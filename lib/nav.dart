import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
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
import 'state.dart';
import 'theme.dart';

class AppRouter {
  static GoRouter createRouter(NostalgiaProvider provider) => GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: provider,
    redirect: (context, state) {
      final isOnSplash = state.matchedLocation == AppRoutes.splash;
      final isOnJoinCreate = state.matchedLocation == AppRoutes.joinCreate;
      final isInitialized = provider.isInitialized;
      final isGroupJoined = provider.isGroupJoined;
      
      // Show splash while initializing
      if (!isInitialized && !isOnSplash) {
        return AppRoutes.splash;
      }
      
      // Once initialized, redirect from splash based on group status
      if (isInitialized && isOnSplash) {
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
    ],
  );
}

class AppRoutes {
  static const String splash = '/';
  static const String joinCreate = '/join-create';
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
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NostalgiaProvider>();
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                border: Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 3,
                ),
              ),
              child: Icon(
                Icons.access_time_rounded,
                size: 60,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXl),
            Text(
              'Nostalgia Time Machine',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            if (provider.isGroupJoined && provider.currentUserProfile != null)
              Text(
                'Welcome back, ${provider.currentUserProfile!.displayName}! 👋',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
