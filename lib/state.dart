import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nostalgia_time_machine/services/auth_service.dart';
import 'package:nostalgia_time_machine/services/firestore_service.dart';
import 'package:nostalgia_time_machine/models/user_profile.dart';
import 'package:nostalgia_time_machine/models/group.dart';
import 'package:nostalgia_time_machine/models/member.dart';
import 'package:nostalgia_time_machine/models/song.dart';
import 'package:nostalgia_time_machine/models/episode.dart';

class NostalgiaProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  UserProfile? _currentUserProfile;
  Group? _currentGroup;
  String? _currentWeekId;
  List<Member> _members = [];
  List<Song> _songs = [];
  List<Episode> _episodes = [];

  StreamSubscription? _groupSubscription;
  StreamSubscription? _membersSubscription;
  StreamSubscription? _songsSubscription;
  StreamSubscription? _episodesSubscription;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  UserProfile? get currentUserProfile => _currentUserProfile;
  Group? get currentGroup => _currentGroup;
  String? get currentWeekId => _currentWeekId;
  List<Member> get members => _members;
  List<Song> get songs => _songs;
  List<Episode> get episodes => _episodes;

  String get currentUserId => _authService.currentUid ?? '';
  bool get isGroupJoined => _currentGroup != null;
  bool get isCheckingAuth => !_isInitialized;

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🔄 Initializing NostalgiaProvider...');

      // Load theme preference
      await _loadThemePreference();

      // Check if user is already signed in (persisted from previous session)
      String? uid = _authService.currentUid;

      // Only sign in anonymously if no user exists
      if (uid == null) {
        debugPrint('🔐 No existing session, signing in anonymously...');
        await _authService.signInAnonymously();
        uid = _authService.currentUid;
      } else {
        debugPrint('✅ Found existing session for user: $uid');
      }

      if (uid == null) {
        debugPrint('❌ No user after initialization');
        return;
      }

      // Load user profile if exists
      final existingProfile = await _firestoreService.getUserProfile(uid);
      if (existingProfile != null) {
        _currentUserProfile = existingProfile;
        await _firestoreService.updateLastSeen(uid);
        debugPrint('✅ Loaded user profile: ${existingProfile.displayName}');

        // Check if user is in a group and restore session
        final groupId = await _firestoreService.getUserGroupId(uid);
        if (groupId != null) {
          debugPrint('🔄 Restoring group session: $groupId');
          await _listenToGroup(groupId);
        }
      }

      _isInitialized = true;
      notifyListeners();
      debugPrint('✅ NostalgiaProvider initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize: $e');
    }
  }

  // ============================================================================
  // THEME MANAGEMENT
  // ============================================================================

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool('isDarkMode') ?? false;
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      debugPrint('✅ Loaded theme preference: $_themeMode');
    } catch (e) {
      debugPrint('❌ Failed to load theme preference: $e');
    }
  }

  Future<void> toggleTheme() async {
    try {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _themeMode == ThemeMode.dark);
      debugPrint('✅ Theme toggled to: $_themeMode');
    } catch (e) {
      debugPrint('❌ Failed to save theme preference: $e');
    }
  }

  // ============================================================================
  // JOIN / CREATE GROUP
  // ============================================================================

  Future<bool> joinGroup({
    required String code,
    required String displayName,
    required String avatarIcon,
    required int avatarColor,
  }) async {
    try {
      final uid = _authService.currentUid;
      if (uid == null) {
        debugPrint('❌ No authenticated user');
        return false;
      }

      // Find group by code
      final group = await _firestoreService.findGroupByCode(code);
      if (group == null) {
        debugPrint('❌ Group not found with code: $code');
        return false;
      }

      // Create or update user profile
      _currentUserProfile = UserProfile(
        uid: uid,
        displayName: displayName,
        avatarColor: avatarColor,
        avatarIcon: avatarIcon,
        createdAt: DateTime.now(),
        lastSeenAt: DateTime.now(),
      );
      await _firestoreService.createUserProfile(_currentUserProfile!);

      // Add member to group
      await _firestoreService.addMemberToGroup(
        groupId: group.id,
        uid: uid,
        displayName: displayName,
        avatarColor: avatarColor,
        avatarIcon: avatarIcon,
      );

      // Start listening to group data
      await _listenToGroup(group.id);

      debugPrint('✅ Successfully joined group: ${group.code}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to join group: $e');
      return false;
    }
  }

  Future<bool> createGroup({
    required String displayName,
    required String avatarIcon,
    required int avatarColor,
    required int startDecade,
    required String quizDifficulty,
    int songCapPerUser = 7,
    int episodeCapPerUser = 1,
  }) async {
    try {
      final uid = _authService.currentUid;
      if (uid == null) {
        debugPrint('❌ No authenticated user');
        return false;
      }

      // Generate unique code
      final code = _generateGroupCode();

      // Create or update user profile
      _currentUserProfile = UserProfile(
        uid: uid,
        displayName: displayName,
        avatarColor: avatarColor,
        avatarIcon: avatarIcon,
        createdAt: DateTime.now(),
        lastSeenAt: DateTime.now(),
      );
      await _firestoreService.createUserProfile(_currentUserProfile!);

      // Create group
      final group = await _firestoreService.createGroup(
        code: code,
        createdByUid: uid,
        startDecade: startDecade,
        quizDifficulty: quizDifficulty,
        songCapPerUser: songCapPerUser,
        episodeCapPerUser: episodeCapPerUser,
      );

      // Add creator as first member
      await _firestoreService.addMemberToGroup(
        groupId: group.id,
        uid: uid,
        displayName: displayName,
        avatarColor: avatarColor,
        avatarIcon: avatarIcon,
      );

      // Create default chat session immediately
      await _firestoreService.getOrCreateChatSession(group.id,
          createdByUid: uid);
      debugPrint('✅ Default chat session created for new group');

      // Start listening to group data
      await _listenToGroup(group.id);

      debugPrint('✅ Successfully created group: $code');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to create group: $e');
      return false;
    }
  }

  String _generateGroupCode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final shortCode = (timestamp % 100000).toString().padLeft(5, '0');
    return 'REWIND-$shortCode';
  }

  // ============================================================================
  // REAL-TIME LISTENERS
  // ============================================================================

  Future<void> _listenToGroup(String groupId) async {
    // Cancel existing subscriptions
    await _groupSubscription?.cancel();
    await _membersSubscription?.cancel();
    await _songsSubscription?.cancel();
    await _episodesSubscription?.cancel();

    // Listen to group
    _groupSubscription =
        _firestoreService.streamGroup(groupId).listen((group) async {
      if (group != null) {
        final previousWeekId = _currentWeekId;
        _currentGroup = group;

        // Use currentWeekId from group if available, otherwise generate one
        if (group.currentWeekId != null) {
          _currentWeekId = group.currentWeekId;
        } else {
          _currentWeekId = await _firestoreService.getCurrentWeekId(
            groupId,
            group.currentYear,
          );
        }

        // If week changed, update streams
        if (_currentWeekId != previousWeekId && _currentWeekId != null) {
          await _updateWeekStreams(groupId, _currentWeekId!);
        }

        notifyListeners();
      }
    });

    // Listen to members
    _membersSubscription =
        _firestoreService.streamMembers(groupId).listen((members) {
      _members = members;
      notifyListeners();
    });

    // Wait for group to load to get weekId
    await Future.delayed(const Duration(milliseconds: 500));

    if (_currentWeekId != null) {
      await _updateWeekStreams(groupId, _currentWeekId!);
    }
  }

  Future<void> _updateWeekStreams(String groupId, String weekId) async {
    // Cancel existing streams
    await _songsSubscription?.cancel();
    await _episodesSubscription?.cancel();

    // Listen to songs
    _songsSubscription =
        _firestoreService.streamSongs(groupId, weekId).listen((songs) {
      _songs = songs;
      notifyListeners();
    });

    // Listen to episodes
    _episodesSubscription =
        _firestoreService.streamEpisodes(groupId, weekId).listen((episodes) {
      _episodes = episodes;
      notifyListeners();
    });
  }

  // ============================================================================
  // ADD CONTENT
  // ============================================================================

  Future<bool> addSong({
    required String title,
    required String artist,
    required String youtubeId,
    required String youtubeUrl,
  }) async {
    try {
      if (_currentGroup == null || _currentWeekId == null) {
        debugPrint('❌ No active group or week');
        return false;
      }

      final uid = _authService.currentUid;
      if (uid == null || _currentUserProfile == null) {
        debugPrint('❌ No user profile');
        return false;
      }

      await _firestoreService.addSong(
        groupId: _currentGroup!.id,
        weekId: _currentWeekId!,
        title: title,
        artist: artist,
        youtubeId: youtubeId,
        youtubeUrl: youtubeUrl,
        yearTag: _currentGroup!.currentYear,
        addedByUid: uid,
        addedByName: _currentUserProfile!.displayName,
      );

      debugPrint('✅ Song added successfully');
      return true;
    } catch (e) {
      if (e.toString().contains('LIMIT_REACHED')) {
        debugPrint('⚠️ Song limit reached');
      } else {
        debugPrint('❌ Failed to add song: $e');
      }
      return false;
    }
  }

  Future<bool> addEpisode({
    required String showTitle,
    required String episodeTitle,
    required String youtubeId,
    required String youtubeUrl,
  }) async {
    try {
      if (_currentGroup == null || _currentWeekId == null) {
        debugPrint('❌ No active group or week');
        return false;
      }

      final uid = _authService.currentUid;
      if (uid == null || _currentUserProfile == null) {
        debugPrint('❌ No user profile');
        return false;
      }

      await _firestoreService.addEpisode(
        groupId: _currentGroup!.id,
        weekId: _currentWeekId!,
        showTitle: showTitle,
        episodeTitle: episodeTitle,
        youtubeId: youtubeId,
        youtubeUrl: youtubeUrl,
        decadeTag: _currentGroup!.currentYear,
        addedByUid: uid,
        addedByName: _currentUserProfile!.displayName,
      );

      debugPrint('✅ Episode added successfully');
      return true;
    } catch (e) {
      if (e.toString().contains('LIMIT_REACHED')) {
        debugPrint('⚠️ Episode limit reached (1/1)');
      } else {
        debugPrint('❌ Failed to add episode: $e');
      }
      return false;
    }
  }

  // ============================================================================
  // LEAVE GROUP
  // ============================================================================

  Future<void> leaveGroup() async {
    try {
      final uid = _authService.currentUid;
      if (uid == null || _currentGroup == null) {
        debugPrint('❌ No user or group to leave');
        return;
      }

      // Remove member from group
      await _firestoreService.removeMemberFromGroup(
        groupId: _currentGroup!.id,
        uid: uid,
      );

      // Cancel all subscriptions
      await _groupSubscription?.cancel();
      await _membersSubscription?.cancel();
      await _songsSubscription?.cancel();
      await _episodesSubscription?.cancel();

      // Clear local state
      _currentGroup = null;
      _currentWeekId = null;
      _members = [];
      _songs = [];
      _episodes = [];

      notifyListeners();
      debugPrint('✅ Successfully left group');
    } catch (e) {
      debugPrint('❌ Failed to leave group: $e');
      rethrow;
    }
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================

  @override
  void dispose() {
    _groupSubscription?.cancel();
    _membersSubscription?.cancel();
    _songsSubscription?.cancel();
    _episodesSubscription?.cancel();
    super.dispose();
  }
}
