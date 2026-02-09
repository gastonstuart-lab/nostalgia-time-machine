import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:nostalgia_time_machine/models/user_profile.dart';
import 'package:nostalgia_time_machine/models/group.dart';
import 'package:nostalgia_time_machine/models/member.dart';
import 'package:nostalgia_time_machine/models/song.dart';
import 'package:nostalgia_time_machine/models/episode.dart';
import 'package:nostalgia_time_machine/models/chat_message.dart';
import 'package:nostalgia_time_machine/models/group_message.dart';
import 'package:nostalgia_time_machine/models/quiz_question.dart';
import 'package:nostalgia_time_machine/models/quiz_score.dart';
import 'package:nostalgia_time_machine/models/movie.dart';
import 'package:nostalgia_time_machine/models/decade_score.dart';
import 'package:nostalgia_time_machine/models/decade_winner.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================================
  // USER PROFILES
  // ============================================================================

  Future<void> createUserProfile(UserProfile profile) async {
    try {
      await _db.collection('users').doc(profile.uid).set(profile.toJson());
      debugPrint('✅ User profile created: ${profile.uid}');
    } catch (e) {
      debugPrint('❌ Failed to create user profile: $e');
      rethrow;
    }
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserProfile.fromJson(uid, doc.data()!);
    } catch (e) {
      debugPrint('❌ Failed to get user profile: $e');
      return null;
    }
  }

  Future<void> updateLastSeen(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'lastSeenAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Failed to update lastSeen: $e');
    }
  }

  // ============================================================================
  // GROUPS
  // ============================================================================

  Future<Group> createGroup({
    required String code,
    required String createdByUid,
    required int startDecade,
    String quizDifficulty = 'medium',
    int songCapPerUser = 7,
    int episodeCapPerUser = 1,
  }) async {
    try {
      final groupRef = _db.collection('groups').doc();
      final weekId = 'week_$startDecade';
      final group = Group(
        id: groupRef.id,
        code: code,
        createdAt: DateTime.now(),
        createdByUid: createdByUid,
        currentYear: startDecade,
        currentDecadeStart: startDecade,
        currentWeekStart: DateTime.now(),
        status: 'active',
        currentWeekId: weekId,
        adminUid: createdByUid,
        settings: {
          'songCapPerUser': songCapPerUser,
          'episodeCapPerUser': episodeCapPerUser,
          'quizDifficulty': quizDifficulty,
        },
      );
      // Use merge to preserve older fields
      await groupRef.set(group.toJson(), SetOptions(merge: true));

      // Create initial week document
      await groupRef.collection('weeks').doc(weekId).set({
        'year': startDecade,
        'weekStart': FieldValue.serverTimestamp(),
        'weekEnd': null,
        'isClosed': false,
      });

      debugPrint('✅ Group created: ${group.id} with code: $code');
      return group;
    } catch (e) {
      debugPrint('❌ Failed to create group: $e');
      rethrow;
    }
  }

  Future<Group?> findGroupByCode(String code) async {
    try {
      final snapshot = await _db
          .collection('groups')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      return Group.fromJson(doc.id, doc.data());
    } catch (e) {
      debugPrint('❌ Failed to find group by code: $e');
      return null;
    }
  }

  Stream<Group?> streamGroup(String groupId) {
    return _db.collection('groups').doc(groupId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Group.fromJson(doc.id, doc.data()!);
    });
  }

  Future<void> generateNewGroupCode(String groupId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final shortCode = (timestamp % 100000).toString().padLeft(5, '0');
      final newCode = 'REWIND-$shortCode';

      await _db.collection('groups').doc(groupId).update({
        'code': newCode,
      });

      debugPrint('✅ Generated new group code: $newCode');
    } catch (e) {
      debugPrint('❌ Failed to generate new group code: $e');
      rethrow;
    }
  }

  // ============================================================================
  // MEMBERS
  // ============================================================================

  Future<void> addMemberToGroup({
    required String groupId,
    required String uid,
    required String displayName,
    required int avatarColor,
    required String avatarIcon,
  }) async {
    try {
      final member = Member(
        uid: uid,
        displayName: displayName,
        avatarColor: avatarColor,
        avatarIcon: avatarIcon,
        joinedAt: DateTime.now(),
      );

      await _db
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(uid)
          .set(member.toJson());

      debugPrint('✅ Member added to group: $groupId');
    } catch (e) {
      debugPrint('❌ Failed to add member: $e');
      rethrow;
    }
  }

  Stream<List<Member>> streamMembers(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Member.fromJson(doc.id, doc.data()))
            .toList());
  }

  Future<String?> getUserGroupId(String uid) async {
    try {
      // Query all groups to find where this user is a member
      final groupsSnapshot = await _db.collection('groups').get();

      for (final groupDoc in groupsSnapshot.docs) {
        final memberDoc =
            await groupDoc.reference.collection('members').doc(uid).get();

        if (memberDoc.exists) {
          debugPrint('✅ Found user in group: ${groupDoc.id}');
          return groupDoc.id;
        }
      }

      debugPrint('ℹ️ User not in any group');
      return null;
    } catch (e) {
      debugPrint('❌ Failed to get user group: $e');
      return null;
    }
  }

  Future<void> removeMemberFromGroup({
    required String groupId,
    required String uid,
  }) async {
    try {
      await _db
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(uid)
          .delete();

      debugPrint('✅ Member removed from group: $groupId');
    } catch (e) {
      debugPrint('❌ Failed to remove member: $e');
      rethrow;
    }
  }

  // ============================================================================
  // WEEKS (auto-create current week if needed)
  // ============================================================================

  Future<String> getCurrentWeekId(String groupId, int year) async {
    try {
      // Use year as weekId for simplicity in MVP
      final weekId = 'week_$year';
      final weekRef =
          _db.collection('groups').doc(groupId).collection('weeks').doc(weekId);

      final weekDoc = await weekRef.get();
      if (!weekDoc.exists) {
        // Create week document
        await weekRef.set({
          'year': year,
          'weekStart': FieldValue.serverTimestamp(),
          'weekEnd': null,
        });
        debugPrint('✅ Week created: $weekId');
      }

      return weekId;
    } catch (e) {
      debugPrint('❌ Failed to get/create week: $e');
      rethrow;
    }
  }

  // ============================================================================
  // SONGS
  // ============================================================================

  Future<void> addSong({
    required String groupId,
    required String weekId,
    required String title,
    required String artist,
    required String youtubeId,
    required String youtubeUrl,
    required int yearTag,
    required String addedByUid,
    required String addedByName,
  }) async {
    try {
      final songsCollectionRef = _db
          .collection('groups')
          .doc(groupId)
          .collection('weeks')
          .doc(weekId)
          .collection('songs');
      final userSongsQuery =
          songsCollectionRef.where('addedByUid', isEqualTo: addedByUid);

      // Use count() before transaction for limit check (per user)
      final countSnapshot = await userSongsQuery.count().get();
      final groupDoc = await _db.collection('groups').doc(groupId).get();
      final group = Group.fromJson(groupDoc.id, groupDoc.data() ?? {});
      final songCap = group.songCapPerUser;

      final currentCount = countSnapshot.count ?? 0;
      if (currentCount >= songCap) {
        throw Exception('LIMIT_REACHED');
      }

      // Now write with transaction safety
      await _db.runTransaction((transaction) async {
        final docs = await userSongsQuery.limit(songCap + 1).get();
        if (docs.docs.length >= songCap) {
          throw Exception('LIMIT_REACHED');
        }

        // Create new song
        final songRef = songsCollectionRef.doc();
        final song = Song(
          id: songRef.id,
          title: title,
          artist: artist,
          youtubeId: youtubeId,
          youtubeUrl: youtubeUrl,
          yearTag: yearTag,
          addedByUid: addedByUid,
          addedByName: addedByName,
          addedAt: DateTime.now(),
        );

        transaction.set(songRef, song.toJson());
      });

      debugPrint('✅ Song added: $title');
    } catch (e) {
      debugPrint('❌ Failed to add song: $e');
      rethrow;
    }
  }

  Future<int> getSongCount(String groupId, String weekId) async {
    try {
      final snapshot = await _db
          .collection('groups')
          .doc(groupId)
          .collection('weeks')
          .doc(weekId)
          .collection('songs')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('❌ Failed to get song count: $e');
      return 0;
    }
  }

  Stream<List<Song>> streamSongs(String groupId, String weekId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('weeks')
        .doc(weekId)
        .collection('songs')
        .orderBy('addedAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Song.fromJson(doc.id, doc.data()))
            .toList());
  }

  Future<void> deleteSong(String groupId, String weekId, String songId) async {
    try {
      await _db
          .collection('groups')
          .doc(groupId)
          .collection('weeks')
          .doc(weekId)
          .collection('songs')
          .doc(songId)
          .delete();
      debugPrint('✅ Song deleted: $songId');
    } catch (e) {
      debugPrint('❌ Failed to delete song: $e');
      rethrow;
    }
  }

  // ============================================================================
  // EPISODES
  // ============================================================================

  Future<void> addEpisode({
    required String groupId,
    required String weekId,
    required String showTitle,
    required String episodeTitle,
    required String youtubeId,
    required String youtubeUrl,
    required int decadeTag,
    required String addedByUid,
    required String addedByName,
  }) async {
    try {
      final episodesCollectionRef = _db
          .collection('groups')
          .doc(groupId)
          .collection('weeks')
          .doc(weekId)
          .collection('episodes');
      final userEpisodesQuery =
          episodesCollectionRef.where('addedByUid', isEqualTo: addedByUid);

      // Use count() before transaction for limit check (per user)
      final countSnapshot = await userEpisodesQuery.count().get();
      final groupDoc = await _db.collection('groups').doc(groupId).get();
      final group = Group.fromJson(groupDoc.id, groupDoc.data() ?? {});
      final episodeCap = group.episodeCapPerUser;

      final currentCount = countSnapshot.count ?? 0;
      if (currentCount >= episodeCap) {
        throw Exception('LIMIT_REACHED');
      }

      // Now write with transaction safety
      await _db.runTransaction((transaction) async {
        final docs = await userEpisodesQuery.limit(episodeCap + 1).get();
        if (docs.docs.length >= episodeCap) {
          throw Exception('LIMIT_REACHED');
        }

        // Create new episode
        final episodeRef = episodesCollectionRef.doc();
        final episode = Episode(
          id: episodeRef.id,
          showTitle: showTitle,
          episodeTitle: episodeTitle,
          youtubeId: youtubeId,
          youtubeUrl: youtubeUrl,
          decadeTag: decadeTag,
          addedByUid: addedByUid,
          addedByName: addedByName,
          addedAt: DateTime.now(),
        );

        transaction.set(episodeRef, episode.toJson());
      });

      debugPrint('✅ Episode added: $showTitle - $episodeTitle');
    } catch (e) {
      debugPrint('❌ Failed to add episode: $e');
      rethrow;
    }
  }

  Future<int> getEpisodeCount(String groupId, String weekId) async {
    try {
      final snapshot = await _db
          .collection('groups')
          .doc(groupId)
          .collection('weeks')
          .doc(weekId)
          .collection('episodes')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('❌ Failed to get episode count: $e');
      return 0;
    }
  }

  Stream<List<Episode>> streamEpisodes(String groupId, String weekId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('weeks')
        .doc(weekId)
        .collection('episodes')
        .orderBy('addedAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Episode.fromJson(doc.id, doc.data()))
            .toList());
  }

  Future<void> deleteEpisode(
      String groupId, String weekId, String episodeId) async {
    try {
      await _db
          .collection('groups')
          .doc(groupId)
          .collection('weeks')
          .doc(weekId)
          .collection('episodes')
          .doc(episodeId)
          .delete();
      debugPrint('✅ Episode deleted: $episodeId');
    } catch (e) {
      debugPrint('❌ Failed to delete episode: $e');
      rethrow;
    }
  }

  // ============================================================================
  // MOVIES
  // ============================================================================

  Stream<List<Movie>> streamMovies(String groupId, String weekId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('weeks')
        .doc(weekId)
        .collection('movies')
        .orderBy('addedAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Movie.fromJson(doc.id, doc.data()))
            .toList());
  }

  Future<void> addMovie({
    required String groupId,
    required String weekId,
    required String title,
    int? year,
    String? posterUrl,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        throw Exception('UNAUTHENTICATED');
      }

      final userDoc = await _db.collection('users').doc(uid).get();
      final addedByName =
          userDoc.data()?['displayName'] as String? ?? 'Unknown';

      final moviesCollectionRef = _db
          .collection('groups')
          .doc(groupId)
          .collection('weeks')
          .doc(weekId)
          .collection('movies');
      final myMoviesQuery =
          moviesCollectionRef.where('addedByUid', isEqualTo: uid);

      final countSnapshot = await myMoviesQuery.count().get();
      final currentCount = countSnapshot.count ?? 0;
      if (currentCount >= 1) {
        throw Exception('LIMIT_REACHED');
      }

      await _db.runTransaction((transaction) async {
        final existing = await myMoviesQuery.limit(2).get();
        if (existing.docs.isNotEmpty) {
          throw Exception('LIMIT_REACHED');
        }

        final movieRef = moviesCollectionRef.doc();
        final movie = Movie(
          id: movieRef.id,
          title: title,
          year: year,
          posterUrl: posterUrl,
          addedByUid: uid,
          addedByName: addedByName,
          addedAt: DateTime.now(),
        );
        transaction.set(movieRef, movie.toJson());
      });
      debugPrint('✅ Movie added: $title');
    } catch (e) {
      debugPrint('❌ Failed to add movie: $e');
      rethrow;
    }
  }

  Future<void> deleteMovie(
      String groupId, String weekId, String movieId) async {
    try {
      await _db
          .collection('groups')
          .doc(groupId)
          .collection('weeks')
          .doc(weekId)
          .collection('movies')
          .doc(movieId)
          .delete();
      debugPrint('✅ Movie deleted: $movieId');
    } catch (e) {
      debugPrint('❌ Failed to delete movie: $e');
      rethrow;
    }
  }

  Future<Movie?> getMyMoviePickThisWeek(
      String groupId, String weekId, String uid) async {
    try {
      final snapshot = await _db
          .collection('groups')
          .doc(groupId)
          .collection('weeks')
          .doc(weekId)
          .collection('movies')
          .where('addedByUid', isEqualTo: uid)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return Movie.fromJson(doc.id, doc.data());
    } catch (e) {
      debugPrint('❌ Failed to get my movie pick: $e');
      return null;
    }
  }

  // ============================================================================
  // REACTIONS
  // ============================================================================

  Future<void> addReaction({
    required String groupId,
    required String weekId,
    required String songId,
    required String uid,
    required String type,
  }) async {
    try {
      await _db
          .collection('groups')
          .doc(groupId)
          .collection('weeks')
          .doc(weekId)
          .collection('songs')
          .doc(songId)
          .collection('reactions')
          .doc(uid)
          .set({
        'type': type,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Reaction added: $type');
    } catch (e) {
      debugPrint('❌ Failed to add reaction: $e');
      rethrow;
    }
  }

  Future<void> removeReaction({
    required String groupId,
    required String weekId,
    required String songId,
    required String uid,
  }) async {
    try {
      await _db
          .collection('groups')
          .doc(groupId)
          .collection('weeks')
          .doc(weekId)
          .collection('songs')
          .doc(songId)
          .collection('reactions')
          .doc(uid)
          .delete();
      debugPrint('✅ Reaction removed');
    } catch (e) {
      debugPrint('❌ Failed to remove reaction: $e');
      rethrow;
    }
  }

  Stream<Map<String, int>> streamReactionCounts(
      String groupId, String weekId, String songId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('weeks')
        .doc(weekId)
        .collection('songs')
        .doc(songId)
        .collection('reactions')
        .snapshots()
        .map((snapshot) {
      final counts = <String, int>{};
      for (final doc in snapshot.docs) {
        final type = doc.data()['type'] as String?;
        if (type != null) {
          counts[type] = (counts[type] ?? 0) + 1;
        }
      }
      return counts;
    });
  }

  Future<String?> getUserReaction({
    required String groupId,
    required String weekId,
    required String songId,
    required String uid,
  }) async {
    try {
      final doc = await _db
          .collection('groups')
          .doc(groupId)
          .collection('weeks')
          .doc(weekId)
          .collection('songs')
          .doc(songId)
          .collection('reactions')
          .doc(uid)
          .get();

      if (!doc.exists) return null;
      return doc.data()?['type'] as String?;
    } catch (e) {
      debugPrint('❌ Failed to get user reaction: $e');
      return null;
    }
  }

  // ============================================================================
  // YEAR ADVANCEMENT
  // ============================================================================

  Future<void> advanceYear(String groupId) async {
    try {
      final groupRef = _db.collection('groups').doc(groupId);
      final groupDoc = await groupRef.get();
      if (!groupDoc.exists || groupDoc.data() == null) {
        throw Exception('Group not found');
      }

      final groupData = groupDoc.data()!;
      final currentYear = (groupData['currentYear'] as num?)?.toInt() ?? 1990;
      final currentDecadeStart =
          (groupData['currentDecadeStart'] as num?)?.toInt() ?? 1990;
      final oldWeekId = groupData['currentWeekId'] as String?;

      final nextYear = currentYear + 1;
      final newWeekId = 'week_$nextYear';
      final isDecadeRollover = nextYear > currentDecadeStart + 9;
      final newDecadeStart =
          isDecadeRollover ? currentDecadeStart + 10 : currentDecadeStart;

      await _db.runTransaction((transaction) async {
        if (oldWeekId != null) {
          final oldWeekRef = groupRef.collection('weeks').doc(oldWeekId);
          transaction.update(oldWeekRef, {
            'isClosed': true,
            'weekEnd': FieldValue.serverTimestamp(),
          });
        }

        transaction.update(groupRef, {
          'currentYear': nextYear,
          'currentDecadeStart': newDecadeStart,
          'currentWeekId': newWeekId,
          'currentWeekStart': FieldValue.serverTimestamp(),
          'status': 'active',
        });

        final newWeekRef = groupRef.collection('weeks').doc(newWeekId);
        transaction.set(newWeekRef, {
          'year': nextYear,
          'weekStart': FieldValue.serverTimestamp(),
          'weekEnd': null,
          'isClosed': false,
        });
      });

      if (oldWeekId != null) {
        await _awardWeeklyWinners(
          groupId: groupId,
          weekId: oldWeekId,
          decadeStart: currentDecadeStart,
        );
      }

      if (isDecadeRollover) {
        await _finalizeDecadeWinner(
          groupId: groupId,
          decadeStart: currentDecadeStart,
        );
      }

      debugPrint('✅ Year advanced successfully to next year');
    } catch (e) {
      debugPrint('❌ Failed to advance year: $e');
      rethrow;
    }
  }

  Future<void> _awardWeeklyWinners({
    required String groupId,
    required String weekId,
    required int decadeStart,
  }) async {
    final scoresSnapshot = await _db
        .collection('groups')
        .doc(groupId)
        .collection('weeks')
        .doc(weekId)
        .collection('quizScores')
        .get();

    if (scoresSnapshot.docs.isEmpty) return;

    final maxScore = scoresSnapshot.docs
        .map((doc) => (doc.data()['score'] as num?)?.toInt() ?? 0)
        .fold<int>(0, (max, value) => value > max ? value : max);

    final winners = scoresSnapshot.docs.where((doc) {
      final score = (doc.data()['score'] as num?)?.toInt() ?? 0;
      return score == maxScore;
    });

    final batch = _db.batch();
    for (final winner in winners) {
      final uid = winner.id;
      final displayName = winner.data()['displayName'] as String? ?? 'Unknown';
      final decadeRef = _db
          .collection('groups')
          .doc(groupId)
          .collection('decadeScores')
          .doc(uid);
      batch.set(
          decadeRef,
          {
            'uid': uid,
            'displayName': displayName,
            'decadeStart': decadeStart,
            'weeklyWins': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> _finalizeDecadeWinner({
    required String groupId,
    required int decadeStart,
  }) async {
    final scoresSnapshot = await _db
        .collection('groups')
        .doc(groupId)
        .collection('decadeScores')
        .where('decadeStart', isEqualTo: decadeStart)
        .get();

    if (scoresSnapshot.docs.isEmpty) return;

    final scores = scoresSnapshot.docs
        .map((doc) => DecadeScore.fromJson(doc.id, doc.data()))
        .toList()
      ..sort((a, b) {
        final byPoints = b.points.compareTo(a.points);
        if (byPoints != 0) return byPoints;
        final byWins = b.weeklyWins.compareTo(a.weeklyWins);
        if (byWins != 0) return byWins;
        return b.weeksPlayed.compareTo(a.weeksPlayed);
      });

    final winner = scores.first;
    final winnerRef = _db
        .collection('groups')
        .doc(groupId)
        .collection('decadeWinners')
        .doc('decade_$decadeStart');

    await winnerRef.set({
      'uid': winner.uid,
      'displayName': winner.displayName,
      'decadeStart': decadeStart,
      'decadeEnd': decadeStart + 9,
      'points': winner.points,
      'weeklyWins': winner.weeklyWins,
      'weeksPlayed': winner.weeksPlayed,
      'awardedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ============================================================================
  // CHAT MESSAGES
  // ============================================================================

  Future<String> getOrCreateChatSession(String groupId,
      {String? createdByUid}) async {
    try {
      // Use a single default session per group
      const sessionId = 'default';
      final sessionRef = _db
          .collection('groups')
          .doc(groupId)
          .collection('chatSessions')
          .doc(sessionId);

      final sessionDoc = await sessionRef.get();
      if (!sessionDoc.exists) {
        await sessionRef.set({
          'createdAt': FieldValue.serverTimestamp(),
          'createdByUid': createdByUid ?? 'system',
          'title': 'Main Chat',
          'lastMessageAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Chat session created: $sessionId');
      }

      return sessionId;
    } catch (e) {
      debugPrint('❌ Failed to get/create chat session: $e');
      rethrow;
    }
  }

  Future<void> addChatMessage({
    required String groupId,
    required String sessionId,
    required String text,
    required String senderType,
    String? userUid,
    String status = 'sent',
  }) async {
    try {
      // Ensure session exists before adding message
      await _ensureSessionExists(groupId, sessionId, userUid);

      final messageRef = _db
          .collection('groups')
          .doc(groupId)
          .collection('chatSessions')
          .doc(sessionId)
          .collection('messages')
          .doc();

      final message = ChatMessage(
        id: messageRef.id,
        text: text,
        senderType: senderType,
        createdAt: DateTime.now(),
        userUid: userUid,
        status: status,
      );

      await messageRef.set(message.toJson());

      // Update session last message time
      await _db
          .collection('groups')
          .doc(groupId)
          .collection('chatSessions')
          .doc(sessionId)
          .update({'lastMessageAt': FieldValue.serverTimestamp()});

      debugPrint('✅ Chat message added: $senderType');
    } catch (e) {
      debugPrint('❌ Failed to add chat message: $e');
      rethrow;
    }
  }

  Future<void> _ensureSessionExists(
      String groupId, String sessionId, String? userUid) async {
    final sessionRef = _db
        .collection('groups')
        .doc(groupId)
        .collection('chatSessions')
        .doc(sessionId);

    final sessionDoc = await sessionRef.get();
    if (!sessionDoc.exists) {
      await sessionRef.set({
        'createdAt': FieldValue.serverTimestamp(),
        'createdByUid': userUid ?? 'system',
        'title': 'Main Chat',
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Chat session auto-created: $sessionId');
    }
  }

  Stream<List<ChatMessage>> streamChatMessages(
      String groupId, String sessionId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('chatSessions')
        .doc(sessionId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromJson(doc.id, doc.data()))
            .toList());
  }

  Future<List<ChatMessage>> getRecentChatMessages(
    String groupId,
    String sessionId, {
    int limit = 10,
  }) async {
    try {
      final snapshot = await _db
          .collection('groups')
          .doc(groupId)
          .collection('chatSessions')
          .doc(sessionId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final messages = snapshot.docs
          .map((doc) => ChatMessage.fromJson(doc.id, doc.data()))
          .toList();

      return messages.reversed.toList();
    } catch (e) {
      debugPrint('❌ Failed to get recent messages: $e');
      return [];
    }
  }

  // ============================================================================
  // GROUP CHAT (messageBoard)
  // ============================================================================

  Stream<List<GroupMessage>> streamGroupMessages(String groupId,
      {int limit = 50}) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('messageBoard')
        .doc('messages')
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GroupMessage.fromJson(doc.id, doc.data()))
            .toList());
  }

  Future<void> sendGroupMessage(
    String groupId,
    String text,
    String senderUid,
    String senderName,
  ) async {
    try {
      final messageRef = _db
          .collection('groups')
          .doc(groupId)
          .collection('messageBoard')
          .doc('messages')
          .collection('messages')
          .doc();

      final message = GroupMessage(
        id: messageRef.id,
        text: text,
        senderUid: senderUid,
        senderName: senderName,
        createdAt: DateTime.now(),
      );

      await messageRef.set(message.toJson());
      debugPrint('✅ Group message sent');
    } catch (e) {
      debugPrint('❌ Failed to send group message: $e');
      rethrow;
    }
  }

  Future<void> updateGroupSettings(
      String groupId, Map<String, dynamic> settings) async {
    await _db.collection('groups').doc(groupId).set({
      'settings': settings,
    }, SetOptions(merge: true));
    // Optionally: trigger a refresh in provider if needed
    // (UI should update automatically if listening to streamGroup)
  }

  // ============================================================================
  // WEEKLY QUIZ
  // ============================================================================

  Future<List<QuizQuestion>> fetchWeeklyQuiz(
    String groupId,
    String weekId, {
    bool forceRegenerate = false,
  }) async {
    try {
      final year = int.tryParse(weekId.replaceFirst('week_', '')) ?? 1990;
      Object? functionError;
      // Use Cloud Function as source of truth
      try {
        final callable = _functions.httpsCallable('generateWeeklyQuiz');
        final result = await callable.call({
          'groupId': groupId,
          'weekId': weekId,
          'year': year,
          'forceRegenerate': forceRegenerate,
        });

        final payload = result.data as Map<dynamic, dynamic>?;
        final rawFromFunction = payload?['questions'] as List<dynamic>?;
        if (rawFromFunction != null && rawFromFunction.isNotEmpty) {
          return rawFromFunction
              .whereType<Map>()
              .map((q) => QuizQuestion.fromJson(Map<String, dynamic>.from(q)))
              .toList();
        }
      } catch (e, stack) {
        functionError = e;
        if (e is FirebaseFunctionsException) {
          debugPrint(
              '[CFN ERROR] generateWeeklyQuiz: FirebaseFunctionsException code=${e.code}, message=${e.message}, details=${e.details}');
        } else {
          debugPrint('[CFN ERROR] generateWeeklyQuiz: ${e.runtimeType}: $e');
        }
        debugPrint('[CFN ERROR] generateWeeklyQuiz stack: $stack');
      }

      final quizRef = _db
          .collection('groups')
          .doc(groupId)
          .collection('weeks')
          .doc(weekId)
          .collection('quiz')
          .doc('quiz');
      final quizDoc = await quizRef.get();
      final rawQuestions = quizDoc.data()?['questions'] as List<dynamic>?;

      if (rawQuestions == null || rawQuestions.isEmpty) {
        if (functionError != null) {
          throw functionError;
        }
        throw Exception('QUIZ_NOT_AVAILABLE');
      }

      return rawQuestions
          .whereType<Map>()
          .map((q) => QuizQuestion.fromJson(Map<String, dynamic>.from(q)))
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to fetch weekly quiz: $e');
      rethrow;
    }
  }

  Future<void> submitQuizScore({
    required String groupId,
    required String weekId,
    required String userId,
    required int score,
    required String displayName,
  }) async {
    try {
      final groupRef = _db.collection('groups').doc(groupId);
      final scoreRef = _db
          .collection('groups')
          .doc(groupId)
          .collection('weeks')
          .doc(weekId)
          .collection('quizScores')
          .doc(userId);
      final decadeScoreRef = _db
          .collection('groups')
          .doc(groupId)
          .collection('decadeScores')
          .doc(userId);

      await _db.runTransaction((transaction) async {
        final existing = await transaction.get(scoreRef);
        if (existing.exists) {
          throw Exception('QUIZ_ALREADY_TAKEN');
        }
        final groupDoc = await transaction.get(groupRef);
        final currentDecadeStart =
            (groupDoc.data()?['currentDecadeStart'] as num?)?.toInt() ?? 1990;
        final existingDecadeScore = await transaction.get(decadeScoreRef);
        final storedDecadeStart =
            (existingDecadeScore.data()?['decadeStart'] as num?)?.toInt();

        transaction.set(scoreRef, {
          'score': score,
          'displayName': displayName,
          'takenAt': FieldValue.serverTimestamp(),
        });

        if (storedDecadeStart == null ||
            storedDecadeStart != currentDecadeStart) {
          transaction.set(decadeScoreRef, {
            'uid': userId,
            'displayName': displayName,
            'decadeStart': currentDecadeStart,
            'points': score,
            'weeklyWins': 0,
            'weeksPlayed': 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(
              decadeScoreRef,
              {
                'uid': userId,
                'displayName': displayName,
                'decadeStart': currentDecadeStart,
                'points': FieldValue.increment(score),
                'weeksPlayed': FieldValue.increment(1),
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true));
        }
      });
    } catch (e) {
      debugPrint('❌ Failed to submit quiz score: $e');
      rethrow;
    }
  }

  Stream<List<QuizScore>> listenToLeaderboard(String groupId, String weekId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('weeks')
        .doc(weekId)
        .collection('quizScores')
        .orderBy('score', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => QuizScore.fromJson(doc.id, doc.data()))
            .toList());
  }

  Stream<QuizScore?> listenToUserQuizScore(
      String groupId, String weekId, String userId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('weeks')
        .doc(weekId)
        .collection('quizScores')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return QuizScore.fromJson(doc.id, doc.data()!);
    });
  }

  Future<QuizScore?> getUserQuizScore(
      String groupId, String weekId, String userId) async {
    final doc = await _db
        .collection('groups')
        .doc(groupId)
        .collection('weeks')
        .doc(weekId)
        .collection('quizScores')
        .doc(userId)
        .get();

    if (!doc.exists || doc.data() == null) return null;
    return QuizScore.fromJson(doc.id, doc.data()!);
  }

  Stream<List<DecadeScore>> listenToDecadeLeaderboard(
      String groupId, int decadeStart) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('decadeScores')
        .where('decadeStart', isEqualTo: decadeStart)
        .snapshots()
        .map((snapshot) {
      final scores = snapshot.docs
          .map((doc) => DecadeScore.fromJson(doc.id, doc.data()))
          .toList();
      scores.sort((a, b) {
        final byPoints = b.points.compareTo(a.points);
        if (byPoints != 0) return byPoints;
        final byWins = b.weeklyWins.compareTo(a.weeklyWins);
        if (byWins != 0) return byWins;
        return b.weeksPlayed.compareTo(a.weeksPlayed);
      });
      return scores;
    });
  }

  Stream<DecadeWinner?> listenToLatestDecadeWinner(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('decadeWinners')
        .orderBy('decadeEnd', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return DecadeWinner.fromJson(doc.id, doc.data());
    });
  }
}
