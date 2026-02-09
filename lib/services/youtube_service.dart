import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/youtube_search_result.dart';

class YouTubeService {
  static const String _baseUrl = 'https://www.googleapis.com/youtube/v3';
  
  // API key should be set via environment or config
  // For development, you can set it here temporarily
  static String? _apiKey;
  
  /// Set the YouTube API key
  static void setApiKey(String key) {
    _apiKey = key;
  }
  
  /// Get the configured API key
  static String? get apiKey => _apiKey;
  
  /// Search for YouTube videos
  Future<List<YouTubeSearchResult>> searchVideos(String query, {int maxResults = 10}) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      debugPrint('YouTube API key not configured');
      throw Exception('YouTube API key not configured. Please set it using YouTubeService.setApiKey()');
    }
    
    try {
      final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
        'part': 'snippet',
        'q': query,
        'type': 'video',
        'maxResults': maxResults.toString(),
        'key': _apiKey!,
        'videoCategoryId': '10', // Music category
      });
      
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>? ?? [];
        
        return items
            .map((item) => YouTubeSearchResult.fromJson(item as Map<String, dynamic>))
            .where((result) => result.videoId.isNotEmpty)
            .toList();
      } else {
        debugPrint('YouTube API error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to search YouTube: ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      debugPrint('YouTube request timed out: $e');
      throw Exception('YouTube request timed out. Please try again.');
    } catch (e) {
      debugPrint('YouTube search error: $e');
      rethrow;
    }
  }
}
