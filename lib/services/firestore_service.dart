import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:nostalgia_time_machine/models/user_profile.dart';
import 'package:nostalgia_time_machine/models/group.dart';
import 'package:nostalgia_time_machine/models/member.dart';
import 'package:nostalgia_time_machine/models/song.dart';
import 'package:nostalgia_time_machine/models/episode.dart';
import 'package:nostalgia_time_machine/models/chat_message.dart';
import 'package:nostalgia_time_machine/models/group_message.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
    int currentYear = 1990,
  }) async {
    try {
      final groupRef = _db.collection('groups').doc();
      final weekId = 'week_$currentYear';
      final group = Group(
        id: groupRef.id,
        code: code,
        createdAt: DateTime.now(),
        createdByUid: createdByUid,
        currentYear: currentYear,
        currentDecadeStart: 1990,
        currentWeekStart: DateTime.now(),
        status: 'active',
        currentWeekId: weekId,
      );
      
      await groupRef.set(group.toJson());
      
      // Create initial week document
      await groupRef.collection('weeks').doc(weekId).set({
        'year': currentYear,
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
        final memberDoc = await groupDoc.reference
            .collection('members')
            .doc(uid)
            .get();
        
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
      final weekRef = _db
          .collection('groups')
          .doc(groupId)
          .collection('weeks')
          .doc(weekId);

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

      // Use count() before transaction for limit check
      final countSnapshot = await songsCollectionRef.count().get();
      final currentCount = countSnapshot.count ?? 0;

      if (currentCount >= 7) {
        throw Exception('LIMIT_REACHED');
      }

      // Now write with transaction safety
      await _db.runTransaction((transaction) async {
        // Re-check count inside transaction for race safety
        final docs = await songsCollectionRef.limit(8).get();
        if (docs.docs.length >= 7) {
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

      // Use count() before transaction for limit check
      final countSnapshot = await episodesCollectionRef.count().get();
      final currentCount = countSnapshot.count ?? 0;

      if (currentCount >= 1) {
        throw Exception('LIMIT_REACHED');
      }

      // Now write with transaction safety
      await _db.runTransaction((transaction) async {
        // Re-check count inside transaction for race safety
        final docs = await episodesCollectionRef.limit(2).get();
        if (docs.docs.length >= 1) {
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

  Future<void> deleteEpisode(String groupId, String weekId, String episodeId) async {
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
      await _db.runTransaction((transaction) async {
        // Read current group state
        final groupRef = _db.collection('groups').doc(groupId);
        final groupDoc = await transaction.get(groupRef);

        if (!groupDoc.exists) {
          throw Exception('Group not found');
        }

        final groupData = groupDoc.data()!;
        final currentYear = groupData['currentYear'] as int;
        final oldWeekId = groupData['currentWeekId'] as String?;

        // Compute next year and week ID
        final nextYear = currentYear + 1;
        final newWeekId = 'week_$nextYear';

        // Close previous week if it exists
        if (oldWeekId != null) {
          final oldWeekRef = groupRef.collection('weeks').doc(oldWeekId);
          transaction.update(oldWeekRef, {
            'isClosed': true,
            'weekEnd': FieldValue.serverTimestamp(),
          });
        }

        // Update group document
        transaction.update(groupRef, {
          'currentYear': nextYear,
          'currentWeekId': newWeekId,
          'currentWeekStart': FieldValue.serverTimestamp(),
          'status': 'active',
        });

        // Create new week document
        final newWeekRef = groupRef.collection('weeks').doc(newWeekId);
        transaction.set(newWeekRef, {
          'year': nextYear,
          'weekStart': FieldValue.serverTimestamp(),
          'weekEnd': null,
          'isClosed': false,
        });
      });

      debugPrint('✅ Year advanced successfully to next year');
    } catch (e) {
      debugPrint('❌ Failed to advance year: $e');
      rethrow;
    }
  }

  // ============================================================================
  // CHAT MESSAGES
  // ============================================================================

  Future<String> getOrCreateChatSession(String groupId, {String? createdByUid}) async {
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

  Future<void> _ensureSessionExists(String groupId, String sessionId, String? userUid) async {
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

  Stream<List<ChatMessage>> streamChatMessages(String groupId, String sessionId) {
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

  Stream<List<GroupMessage>> streamGroupMessages(String groupId, {int limit = 50}) {
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
}
