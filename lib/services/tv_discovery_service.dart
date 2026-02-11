import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/tv_discovery_result.dart';
import 'youtube_service.dart';

class TvDiscoveryService {
  static const String _tvMazeSearchUrl = 'https://api.tvmaze.com/search/shows';
  final YouTubeService _youtubeService = YouTubeService();

  Future<List<TvDiscoveryResult>> searchShows(
    String query, {
    int maxResults = 20,
    int? yearHint,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      final uri = Uri.parse(_tvMazeSearchUrl).replace(queryParameters: {
        'q': query.trim(),
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('TV search failed: ${response.statusCode}');
      }

      final decoded = json.decode(response.body) as List<dynamic>;
      final results = decoded
          .cast<Map<String, dynamic>>()
          .map((item) => item['show'] as Map<String, dynamic>?)
          .whereType<Map<String, dynamic>>()
          .map(_fromTvMaze)
          .where((r) => r.title.isNotEmpty)
          .toList();

      final unique = <String, TvDiscoveryResult>{};
      for (final show in results) {
        final key = '${show.title.toLowerCase()}_${show.premieredYear ?? 0}';
        unique.putIfAbsent(key, () => show);
      }
      final deduped = unique.values.take(maxResults).toList();
      deduped.sort((a, b) {
        final scoreA = _yearScore(a.premieredYear, yearHint);
        final scoreB = _yearScore(b.premieredYear, yearHint);
        if (scoreA != scoreB) return scoreB.compareTo(scoreA);
        return a.title.compareTo(b.title);
      });
      return deduped;
    } on TimeoutException {
      throw Exception('TV search timed out. Please try again.');
    } catch (e) {
      debugPrint('❌ TV search failed: $e');
      rethrow;
    }
  }

  int _yearScore(int? candidate, int? hint) {
    if (candidate == null || hint == null) return 0;
    if (candidate == hint) return 100;
    final delta = (candidate - hint).abs();
    if (delta == 1) return 70;
    if (delta <= 3) return 45;
    if (delta <= 10) return 20;
    return 0;
  }

  TvDiscoveryResult _fromTvMaze(Map<String, dynamic> json) {
    final title = (json['name'] as String? ?? '').trim();
    final premieredRaw = (json['premiered'] as String? ?? '').trim();
    final premieredYear =
        int.tryParse(RegExp(r'\d{4}').stringMatch(premieredRaw) ?? '');
    final endedRaw = (json['ended'] as String? ?? '').trim();
    final endedYear = int.tryParse(RegExp(r'\d{4}').stringMatch(endedRaw) ?? '');
    final image = json['image'] as Map<String, dynamic>?;
    final poster =
        (image?['medium'] as String? ?? image?['original'] as String? ?? '')
            .trim();
    final summaryRaw = (json['summary'] as String? ?? '').trim();
    final summary = summaryRaw.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    final genres = (json['genres'] as List<dynamic>? ?? [])
        .map((g) => g.toString().trim())
        .where((g) => g.isNotEmpty)
        .toList();

    return TvDiscoveryResult(
      title: title,
      premieredYear: premieredYear,
      endedYear: endedYear,
      posterUrl: poster,
      summary: summary,
      genres: genres,
    );
  }

  Future<String?> findTrailerVideoId({
    required String showTitle,
    required int year,
  }) async {
    final query = '$showTitle $year official trailer';
    final results = await _youtubeService.searchVideos(
      query,
      maxResults: 5,
    );
    if (results.isEmpty) return null;
    return results.first.videoId;
  }
}
