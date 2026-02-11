class YearNewsItem {
  final String title;
  final String subtitle;
  final String imageUrl;
  final String imageQuery;
  final String source;
  final String url;
  final int month;

  const YearNewsItem({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.imageQuery,
    required this.source,
    required this.url,
    required this.month,
  });

  factory YearNewsItem.fromJson(Map<String, dynamic> json) {
    return YearNewsItem(
      title: (json['title'] as String? ?? '').trim(),
      subtitle: (json['subtitle'] as String? ?? '').trim(),
      imageUrl: (json['imageUrl'] as String? ?? '').trim(),
      imageQuery: (json['imageQuery'] as String? ?? '').trim(),
      source: (json['source'] as String? ?? '').trim(),
      url: (json['url'] as String? ?? '').trim(),
      month: (json['month'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'imageQuery': imageQuery,
      'source': source,
      'url': url,
      'month': month,
    };
  }
}

class YearNewsPackage {
  final int year;
  final List<YearNewsItem> hero;
  final Map<int, List<YearNewsItem>> byMonth;
  final List<String> ticker;

  const YearNewsPackage({
    required this.year,
    required this.hero,
    required this.byMonth,
    required this.ticker,
  });

  List<YearNewsItem> storiesForMonth(int month) {
    return byMonth[month] ?? const <YearNewsItem>[];
  }

  factory YearNewsPackage.fromJson(Map<String, dynamic> json) {
    final heroRaw = json['hero'] as List<dynamic>? ?? const <dynamic>[];
    final hero = heroRaw
        .whereType<Map>()
        .map((item) => YearNewsItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    final byMonthRaw = json['byMonth'] as Map<dynamic, dynamic>? ?? {};
    final byMonth = <int, List<YearNewsItem>>{};
    byMonthRaw.forEach((key, value) {
      final month = _parseMonthKey('$key');
      if (month == null) return;
      final stories = (value as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map((item) => YearNewsItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      byMonth[month] = stories;
    });

    final tickerRaw = json['ticker'] as List<dynamic>? ?? const <dynamic>[];
    final ticker = tickerRaw
        .map((entry) => '$entry'.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();

    return YearNewsPackage(
      year: (json['year'] as num?)?.toInt() ?? 0,
      hero: hero,
      byMonth: byMonth,
      ticker: ticker,
    );
  }

  static int? _parseMonthKey(String raw) {
    final numeric = int.tryParse(raw.trim());
    if (numeric != null && numeric >= 1 && numeric <= 12) {
      return numeric;
    }

    const months = <String>[
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec',
    ];
    final short = raw.trim().toLowerCase();
    final index = months.indexOf(short.length >= 3 ? short.substring(0, 3) : short);
    if (index == -1) return null;
    return index + 1;
  }

  Map<String, dynamic> toJson() {
    final byMonthJson = <String, dynamic>{};
    byMonth.forEach((month, stories) {
      byMonthJson['$month'] = stories.map((story) => story.toJson()).toList();
    });

    return {
      'year': year,
      'hero': hero.map((story) => story.toJson()).toList(),
      'byMonth': byMonthJson,
      'ticker': ticker,
    };
  }
}
