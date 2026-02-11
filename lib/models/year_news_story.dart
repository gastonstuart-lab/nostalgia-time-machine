class YearNewsStory {
  final String storyKey;
  final int year;
  final int month;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String source;
  final String referenceUrl;
  final List<String> bodyParagraphs;

  const YearNewsStory({
    required this.storyKey,
    required this.year,
    required this.month,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.source,
    required this.referenceUrl,
    required this.bodyParagraphs,
  });

  factory YearNewsStory.fromJson(Map<String, dynamic> json) {
    return YearNewsStory(
      storyKey: (json['storyKey'] as String? ?? '').trim(),
      year: (json['year'] as num?)?.toInt() ?? 0,
      month: (json['month'] as num?)?.toInt() ?? 1,
      title: (json['title'] as String? ?? '').trim(),
      subtitle: (json['subtitle'] as String? ?? '').trim(),
      imageUrl: (json['imageUrl'] as String? ?? '').trim(),
      source: (json['source'] as String? ?? '').trim(),
      referenceUrl: (json['referenceUrl'] as String? ?? '').trim(),
      bodyParagraphs: ((json['bodyParagraphs'] as List<dynamic>?) ?? const [])
          .map((entry) => '$entry'.trim())
          .where((entry) => entry.isNotEmpty)
          .toList(),
    );
  }
}
