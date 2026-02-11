class YearTimelineEvent {
  final int year;
  final int month;
  final int day;
  final String title;
  final String summary;
  final String? articleUrl;
  final String? imageUrl;
  final String sourceLabel;

  const YearTimelineEvent({
    required this.year,
    required this.month,
    required this.day,
    required this.title,
    required this.summary,
    required this.sourceLabel,
    this.articleUrl,
    this.imageUrl,
  });
}

class YearTimelineMonth {
  final int month;
  final List<YearTimelineEvent> events;

  const YearTimelineMonth({
    required this.month,
    required this.events,
  });
}
