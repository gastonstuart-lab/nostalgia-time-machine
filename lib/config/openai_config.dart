import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class OpenAIConfig {
  static const apiKey = String.fromEnvironment('OPENAI_PROXY_API_KEY');
  static const endpoint = String.fromEnvironment('OPENAI_PROXY_ENDPOINT');

  static Future<String> generateChatResponse({
    required List<Map<String, String>> messages,
    required int year,
  }) async {
    if (apiKey.isEmpty || endpoint.isEmpty) {
      debugPrint('❌ OpenAI configuration missing');
      return 'AI configuration error. Please contact support.';
    }

    try {
      debugPrint('🤖 Generating AI response for year: $year');
      
      final systemPrompt = '''You are a nostalgic AI assistant specialized in music and TV from the year $year. 
You help users discover and remember songs, TV shows, movies, and cultural moments from $year.

Guidelines:
- Be enthusiastic and conversational
- Focus on popular music, TV shows, and cultural events from $year
- Provide specific recommendations with artist/show names
- Keep responses concise (2-3 sentences or short bullet lists)
- Use period-appropriate slang and references when appropriate
- If asked about content outside $year, gently redirect to $year content''';

      final requestMessages = [
        {'role': 'system', 'content': systemPrompt},
        ...messages,
      ];

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: utf8.encode(jsonEncode({
          'model': 'gpt-4o',
          'messages': requestMessages,
          'temperature': 0.8,
          'max_tokens': 300,
        })),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices']?[0]?['message']?['content'] as String?;
        
        if (content != null && content.isNotEmpty) {
          debugPrint('✅ AI response generated');
          return content;
        }
        
        debugPrint('⚠️ Empty AI response');
        return 'Sorry, I couldn\'t generate a response. Try again!';
      } else {
        debugPrint('❌ OpenAI API error: ${response.statusCode}');
        return 'AI service temporarily unavailable. Try again in a moment.';
      }
    } catch (e) {
      debugPrint('❌ Failed to generate AI response: $e');
      return 'Connection error. Please check your internet and try again.';
    }
  }
}
