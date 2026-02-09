import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:nostalgia_time_machine/services/firestore_service.dart';

class ChatService {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  String _mapCallableError(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'resource-exhausted':
          return 'I am getting a lot of requests right now. Please try again in a moment.';
        case 'deadline-exceeded':
        case 'unavailable':
          return 'I am temporarily unavailable. Please try again.';
        case 'permission-denied':
        case 'unauthenticated':
          return 'I cannot verify access for this group chat right now. Please try again.';
      }
    }
    return 'Sorry, I could not reach the assistant right now. Please try again.';
  }

  Future<void> processUserMessage({
    required String groupId,
    required String sessionId,
    required String userMessage,
    required String userUid,
    required int year,
  }) async {
    try {
      debugPrint('🔄 Processing user message for year: $year');

      // Get recent conversation history
      final recentMessages = await _firestoreService.getRecentChatMessages(
        groupId,
        sessionId,
        limit: 10,
      );

      // Build conversation context
      final conversationHistory = <Map<String, String>>[];
      for (final msg in recentMessages) {
        conversationHistory.add({
          'role': msg.senderType == 'user' ? 'user' : 'assistant',
          'content': msg.text,
        });
      }

      // Add current message
      conversationHistory.add({
        'role': 'user',
        'content': userMessage,
      });

      // TEMP DIAGNOSTIC: Wrap callable in try/catch
      try {
        final callable = _functions.httpsCallable('nostalgiaChat');
        final result = await callable.call({
          'groupId': groupId,
          'message': userMessage,
          'context': {
            'year': year,
            'history': conversationHistory,
          },
        });
        final payload = result.data as Map<dynamic, dynamic>?;
        final aiResponse = (payload?['reply'] as String?)?.trim();
        if (aiResponse == null || aiResponse.isEmpty) {
          throw Exception('EMPTY_AI_REPLY');
        }

        // Write assistant message to Firestore
        await _firestoreService.addChatMessage(
          groupId: groupId,
          sessionId: sessionId,
          text: aiResponse,
          senderType: 'assistant',
          status: 'sent',
        );

        debugPrint('✅ AI response saved to Firestore');
      } catch (e, stack) {
        // TEMP DIAGNOSTIC
        if (e is FirebaseFunctionsException) {
          debugPrint('[CFN ERROR] nostalgiaChat: FirebaseFunctionsException code=${e.code}, message=${e.message}, details=${e.details}');
        } else {
          debugPrint('[CFN ERROR] nostalgiaChat: ${e.runtimeType}: $e');
        }
        debugPrint('[CFN ERROR] nostalgiaChat stack: $stack');
        rethrow;
      }
    } catch (e) {
      debugPrint('❌ Failed to process user message: $e');
      final friendlyMessage = _mapCallableError(e);
      await _firestoreService.addChatMessage(
        groupId: groupId,
        sessionId: sessionId,
        text: friendlyMessage,
        senderType: 'assistant',
        status: 'error',
      );
    }
  }
}
