import 'package:flutter/foundation.dart';
import 'package:nostalgia_time_machine/config/openai_config.dart';
import 'package:nostalgia_time_machine/services/firestore_service.dart';
import 'package:nostalgia_time_machine/models/chat_message.dart';

class ChatService {
  final FirestoreService _firestoreService = FirestoreService();

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

      // Generate AI response
      final aiResponse = await OpenAIConfig.generateChatResponse(
        messages: conversationHistory,
        year: year,
      );

      // Write assistant message to Firestore
      await _firestoreService.addChatMessage(
        groupId: groupId,
        sessionId: sessionId,
        text: aiResponse,
        senderType: 'assistant',
        status: 'sent',
      );

      debugPrint('✅ AI response saved to Firestore');
    } catch (e) {
      debugPrint('❌ Failed to process user message: $e');
      
      // Write error message
      await _firestoreService.addChatMessage(
        groupId: groupId,
        sessionId: sessionId,
        text: 'Sorry, I encountered an error. Please try again.',
        senderType: 'assistant',
        status: 'error',
      );
    }
  }
}
