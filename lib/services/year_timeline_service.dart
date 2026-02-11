import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/year_timeline_event.dart';

class YearTimelineService {
  static final Map<int, Future<List<YearTimelineMonth>>> _cache = {};
  final Map<String, Future<_SummaryData?>> _summaryCache = {};

  Future<List<YearTimelineMonth>> loadYear(int year) {
    return _cache.putIfAbsent(year, () => _fetchYear(year));
  }

  Future<List<YearTimelineMonth>> _fetchYear(int year) async {
    final monthIndexes = await _fetchMonthSectionIndexes(year);
    final months = <YearTimelineMonth>[];

    for (var month = 1; month <= 12; month++) {
      final sectionIndex = monthIndexes[month];
      if (sectionIndex == null) {
        months.add(YearTimelineMonth(month: month, events: const []));
        continue;
      }
      final events = await _fetchMonthEvents(
        year: year,
        month: month,
        sectionIndex: sectionIndex,
      );
      months.add(YearTimelineMonth(month: month, events: events));
    }
    return months;
  }

  Future<Map<int, int>> _fetchMonthSectionIndexes(int year) async {
    final uri = Uri.parse(
      'https://en.wikipedia.org/w/api.php'
      '?action=parse'
      '&page=$year'
      '&prop=sections'
      '&format=json'
      '&origin=*',
    );

    final out = <int, int>{};
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return out;

      final decoded = json.decode(response.body) as Map<String, dynamic>;
      final parse = decoded['parse'] as Map<String, dynamic>?;
      final sections = parse?['sections'] as List<dynamic>? ?? const [];

      for (final raw in sections) {
        if (raw is! Map<String, dynamic>) continue;
        final line = (raw['line'] ?? '').toString().trim().toLowerCase();
        final index = int.tryParse((raw['index'] ?? '').toString());
        if (index == null) continue;
        final month = _monthFromName(line);
        if (month != null) out[month] = index;
      }
    } catch (_) {
      return out;
    }
    return out;
  }

  Future<List<YearTimelineEvent>> _fetchMonthEvents({
    required int year,
    required int month,
    required int sectionIndex,
  }) async {
    final uri = Uri.parse(
      'https://en.wikipedia.org/w/api.php'
      '?action=parse'
      '&page=$year'
      '&prop=text'
      '&section=$sectionIndex'
      '&format=json'
      '&origin=*',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return const [];

      final decoded = json.decode(response.body) as Map<String, dynamic>;
      final parse = decoded['parse'] as Map<String, dynamic>?;
      final text = parse?['text'] as Map<String, dynamic>?;
      final html = (text?['*'] ?? '').toString();
      if (html.isEmpty) return const [];

      final liRegex = RegExp(r'<li[^>]*>(.*?)<\/li>', dotAll: true);
      final matches = liRegex.allMatches(html).toList();
      if (matches.isEmpty) return const [];

      final events = <YearTimelineEvent>[];
      final seen = <String>{};
      var fallbackDay = 1;
      for (final m in matches) {
        if (events.length >= 120) break;
        final rawLi = m.group(1) ?? '';
        final clean = _stripHtml(rawLi);
        if (clean.isEmpty) continue;

        // Remove citation fragments like [1], [12].
        final noCitations = clean.replaceAll(RegExp(r'\[\d+\]'), '').trim();
        if (noCitations.isEmpty) continue;

        final dayMatch = RegExp(r'^(\d{1,2})\s*[–-]\s*').firstMatch(noCitations);
        final day = int.tryParse(dayMatch?.group(1) ?? '') ?? fallbackDay;
        fallbackDay = (fallbackDay % 28) + 1;

        final title = noCitations;
        final dedupeKey = title.toLowerCase();
        if (!seen.add(dedupeKey)) continue;
        final linkedTitle = _firstWikiLinkTitle(rawLi);
        final summaryData = linkedTitle == null
            ? null
            : await _summaryCache.putIfAbsent(
                linkedTitle,
                () => _fetchSummary(linkedTitle),
              );

        events.add(
          YearTimelineEvent(
            year: year,
            month: month,
            day: day.clamp(1, 31),
            title: title,
            summary: title,
            sourceLabel: summaryData?.sourceLabel ?? 'Wikipedia',
            articleUrl: summaryData?.articleUrl,
            imageUrl: summaryData?.imageUrl,
          ),
        );
      }
      events.sort((a, b) {
        final dayCmp = a.day.compareTo(b.day);
        if (dayCmp != 0) return dayCmp;
        return a.title.compareTo(b.title);
      });
      return events;
    } catch (_) {
      return const [];
    }
  }

  Future<_SummaryData?> _fetchSummary(String pageTitle) async {
    final encoded = Uri.encodeComponent(pageTitle.replaceAll(' ', '_'));
    final uri = Uri.parse(
      'https://en.wikipedia.org/api/rest_v1/page/summary/$encoded',
    );
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final decoded = json.decode(response.body) as Map<String, dynamic>;

      String? articleUrl;
      String? imageUrl;
      final contentUrls = decoded['content_urls'];
      if (contentUrls is Map<String, dynamic>) {
        final desktop = contentUrls['desktop'];
        if (desktop is Map<String, dynamic>) {
          final page = (desktop['page'] ?? '').toString();
          if (page.isNotEmpty) {
            articleUrl = page;
          }
        }
      }
      final thumb = decoded['thumbnail'];
      if (thumb is Map<String, dynamic>) {
        final source = (thumb['source'] ?? '').toString();
        if (source.isNotEmpty) {
          imageUrl = source;
        }
      }
      final title = (decoded['title'] ?? '').toString();
      return _SummaryData(
        sourceLabel: title.isEmpty ? 'Wikipedia' : 'Wikipedia · $title',
        articleUrl: articleUrl,
        imageUrl: imageUrl,
      );
    } catch (_) {
      return null;
    }
  }

  String _stripHtml(String input) {
    var out = input
        .replaceAll(RegExp(r'<\/?b[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<\/?i[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<\/?span[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<\/?a[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<\/?sup[^>]*>.*?<\/sup>', dotAll: true), '')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
    out = out.replaceAll(RegExp(r'\s+'), ' ');
    return out;
  }

  String? _firstWikiLinkTitle(String liHtml) {
    final match = RegExp(r'href="\/wiki\/([^"#?]+)"').firstMatch(liHtml);
    if (match == null) return null;
    final raw = match.group(1);
    if (raw == null || raw.isEmpty) return null;
    return Uri.decodeComponent(raw).replaceAll('_', ' ');
  }

  int? _monthFromName(String line) {
    switch (line) {
      case 'january':
        return 1;
      case 'february':
        return 2;
      case 'march':
        return 3;
      case 'april':
        return 4;
      case 'may':
        return 5;
      case 'june':
        return 6;
      case 'july':
        return 7;
      case 'august':
        return 8;
      case 'september':
        return 9;
      case 'october':
        return 10;
      case 'november':
        return 11;
      case 'december':
        return 12;
      default:
        return null;
    }
  }
}

class _SummaryData {
  final String sourceLabel;
  final String? articleUrl;
  final String? imageUrl;

  const _SummaryData({
    required this.sourceLabel,
    required this.articleUrl,
    required this.imageUrl,
  });
}
