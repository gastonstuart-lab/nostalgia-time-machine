import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/movie_discovery_result.dart';
import 'youtube_service.dart';

class MovieDiscoveryService {
  static const String _itunesSearchUrl = 'https://itunes.apple.com/search';
  static const String _omdbUrl = 'https://www.omdbapi.com/';
  static const String _omdbApiKey =
      String.fromEnvironment('OMDB_API_KEY', defaultValue: '564727fa');
  final YouTubeService _youtubeService = YouTubeService();

  Future<List<MovieDiscoveryResult>> searchMovies(
    String query, {
    int maxResults = 20,
    int? yearHint,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      final omdbResults = await _searchOmdbMovies(
        query,
        maxResults: maxResults,
        yearHint: yearHint,
      );
      if (omdbResults.isNotEmpty) {
        return omdbResults;
      }

      // Fallback source if OMDb returns nothing.
      final uri = Uri.parse(_itunesSearchUrl).replace(queryParameters: {
        'term': query.trim(),
        'entity': 'movie',
        'country': 'us',
        'limit': maxResults.toString(),
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('Movie search failed: ${response.statusCode}');
      }

      final decoded = json.decode(response.body) as Map<String, dynamic>;
      final results = (decoded['results'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(_fromItunesJson)
          .where((r) => r.title.isNotEmpty)
          .toList();

      final unique = <String, MovieDiscoveryResult>{};
      for (final movie in results) {
        final key = '${movie.title.toLowerCase()}_${movie.year ?? 0}';
        unique.putIfAbsent(key, () => movie);
      }
      final deduped = unique.values.toList();

      deduped.sort((a, b) {
        final scoreA = _yearScore(a.year, yearHint);
        final scoreB = _yearScore(b.year, yearHint);
        if (scoreA != scoreB) return scoreB.compareTo(scoreA);
        return a.title.compareTo(b.title);
      });

      return deduped;
    } on TimeoutException {
      throw Exception('Movie search timed out. Please try again.');
    } catch (e) {
      debugPrint('❌ Movie search failed: $e');
      rethrow;
    }
  }

  Future<List<MovieDiscoveryResult>> _searchOmdbMovies(
    String query, {
    required int maxResults,
    int? yearHint,
  }) async {
    final uri = Uri.parse(_omdbUrl).replace(queryParameters: {
      'apikey': _omdbApiKey,
      's': query.trim(),
      'type': 'movie',
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      return [];
    }
    final decoded = json.decode(response.body) as Map<String, dynamic>;
    if ((decoded['Response'] as String?) != 'True') {
      return [];
    }

    final searchItems = (decoded['Search'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .take(maxResults)
        .toList();
    if (searchItems.isEmpty) return [];

    final details = await Future.wait(searchItems.map((item) async {
      final imdbId = item['imdbID'] as String? ?? '';
      if (imdbId.isEmpty) return null;
      return _fetchOmdbDetails(imdbId);
    }));

    final results = details.whereType<MovieDiscoveryResult>().toList();
    results.sort((a, b) {
      final scoreA = _yearScore(a.year, yearHint);
      final scoreB = _yearScore(b.year, yearHint);
      if (scoreA != scoreB) return scoreB.compareTo(scoreA);
      return a.title.compareTo(b.title);
    });
    return results;
  }

  Future<MovieDiscoveryResult?> _fetchOmdbDetails(String imdbId) async {
    try {
      final uri = Uri.parse(_omdbUrl).replace(queryParameters: {
        'apikey': _omdbApiKey,
        'i': imdbId,
        'plot': 'short',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>;
      if ((data['Response'] as String?) != 'True') return null;

      final title = (data['Title'] as String? ?? '').trim();
      final yearRaw = (data['Year'] as String? ?? '').trim();
      final year = int.tryParse(RegExp(r'\d{4}').stringMatch(yearRaw) ?? '');
      final posterRaw = (data['Poster'] as String? ?? '').trim();
      final poster = posterRaw == 'N/A' ? '' : posterRaw;
      final overview = (data['Plot'] as String? ?? '').trim();
      final genre = (data['Genre'] as String? ?? '').trim();
      if (title.isEmpty) return null;

      return MovieDiscoveryResult(
        title: title,
        year: year,
        posterUrl: poster,
        overview: overview == 'N/A' ? '' : overview,
        genre: genre == 'N/A' ? '' : genre,
      );
    } catch (_) {
      return null;
    }
  }

  int _yearScore(int? candidate, int? hint) {
    if (candidate == null || hint == null) return 0;
    if (candidate == hint) return 100;
    final delta = (candidate - hint).abs();
    if (delta == 1) return 80;
    if (delta <= 3) return 50;
    if (delta <= 10) return 20;
    return 0;
  }

  MovieDiscoveryResult _fromItunesJson(Map<String, dynamic> json) {
    final title = (json['trackName'] as String? ?? '').trim();
    final releaseDate = (json['releaseDate'] as String? ?? '').trim();
    final year = releaseDate.length >= 4 ? int.tryParse(releaseDate.substring(0, 4)) : null;
    final artwork100 = (json['artworkUrl100'] as String? ?? '').trim();
    final poster = artwork100.replaceAll('100x100bb', '600x600bb');
    final overview = (json['longDescription'] as String? ??
            json['shortDescription'] as String? ??
            '')
        .trim();
    final genre = (json['primaryGenreName'] as String? ?? '').trim();

    return MovieDiscoveryResult(
      title: title,
      year: year,
      posterUrl: poster,
      overview: overview,
      genre: genre,
    );
  }

  Future<String?> findTrailerVideoId({
    required String title,
    required int year,
  }) async {
    final query = '$title $year official trailer';
    final results = await _youtubeService.searchVideos(
      query,
      maxResults: 5,
    );
    if (results.isEmpty) return null;
    return results.first.videoId;
  }
}
