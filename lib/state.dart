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
  StreamSubscription? _authSubscription;
  Timer? _splashTimer;
  DateTime? _splashStartedAt;
  static const Duration _minSplashDuration = Duration(milliseconds: 1400);
  bool _authResolved = false;

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
  String? get currentUserEmail => _authService.currentEmail;
  bool get isSignedIn => _authService.isSignedIn;
  bool get requiresEmailVerification {
    final user = _authService.currentUser;
    if (user == null) return false;
    final hasPasswordProvider =
        user.providerData.any((p) => p.providerId == 'password');
    return hasPasswordProvider && !user.emailVerified;
  }
  bool get isGroupJoined => _currentGroup != null;
  bool get isCheckingAuth => !_isInitialized;
  bool get authResolved => _authResolved;
  bool get canExitSplash {
    if (_splashStartedAt == null || !_authResolved) return false;
    return DateTime.now().difference(_splashStartedAt!) >= _minSplashDuration;
  }

  void _resetSplashClock() {
    _splashStartedAt = DateTime.now();
  }

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  Future<void> initialize() async {
    _resetSplashClock();
    _authResolved = false;
    if (_isInitialized) return;

    try {
      debugPrint('🔄 Initializing NostalgiaProvider...');

      _splashTimer?.cancel();
      final remaining = _minSplashDuration -
          DateTime.now().difference(_splashStartedAt!);
      if (remaining > Duration.zero) {
        _splashTimer = Timer(remaining, () {
          notifyListeners();
        });
      }

      // Load theme preference
      await _loadThemePreference();

      _authSubscription = _authService.authStateChanges.listen((_) async {
        await _handleAuthChanged();
        if (!_authResolved) {
          _authResolved = true;
        }
        notifyListeners();
      });
      try {
        await _authService.authStateChanges
            .first
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        // Fallback for slow / flaky network auth resolution.
      }
      if (!_authResolved) {
        await _handleAuthChanged();
        _authResolved = true;
      }

      _isInitialized = true;
      notifyListeners();
      debugPrint('✅ NostalgiaProvider initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize: $e');
    }
  }

  Future<void> _handleAuthChanged() async {
    final uid = _authService.currentUid;
    if (uid == null) {
      await _groupSubscription?.cancel();
      await _membersSubscription?.cancel();
      await _songsSubscription?.cancel();
      await _episodesSubscription?.cancel();
      _currentUserProfile = null;
      _currentGroup = null;
      _currentWeekId = null;
      _members = [];
      _songs = [];
      _episodes = [];
      return;
    }

    final existingProfile = await _firestoreService.getUserProfile(uid);
    if (existingProfile != null) {
      _currentUserProfile = existingProfile;
      await _firestoreService.updateLastSeen(uid);
      final groupId = await _firestoreService.getUserGroupId(uid);
      if (groupId != null) {
        await _listenToGroup(groupId);
      }
    } else {
      await _groupSubscription?.cancel();
      await _membersSubscription?.cancel();
      await _songsSubscription?.cancel();
      await _episodesSubscription?.cancel();
      _currentUserProfile = null;
      _currentGroup = null;
      _currentWeekId = null;
      _members = [];
      _songs = [];
      _episodes = [];
    }
  }

  Future<void> signInWithGoogle() async {
    await _authService.signInWithGoogle();
    await _handleAuthChanged();
    notifyListeners();
  }

  Future<void> signUpWithEmail(String email, String password) async {
    await _authService.signUpWithEmailAndPassword(email, password);
    await _handleAuthChanged();
    notifyListeners();
  }

  Future<void> resendVerificationEmail() async {
    await _authService.sendEmailVerification();
  }

  Future<void> refreshEmailVerification() async {
    await _authService.reloadCurrentUser();
    notifyListeners();
  }

  Future<void> signOutUser() async {
    await _authService.signOut();
    await _handleAuthChanged();
    notifyListeners();
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
    _splashTimer?.cancel();
    _authSubscription?.cancel();
    _groupSubscription?.cancel();
    _membersSubscription?.cancel();
    _songsSubscription?.cancel();
    _episodesSubscription?.cancel();
    super.dispose();
  }
}
