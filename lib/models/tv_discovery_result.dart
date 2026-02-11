class TvDiscoveryResult {
  final String title;
  final int? premieredYear;
  final int? endedYear;
  final String posterUrl;
  final String summary;
  final List<String> genres;

  const TvDiscoveryResult({
    required this.title,
    required this.premieredYear,
    required this.endedYear,
    required this.posterUrl,
    required this.summary,
    required this.genres,
  });

  String get genresText {
    if (genres.isEmpty) return '';
    return genres.take(2).join(', ');
  }

  bool isRunningInYear(int year) {
    if (premieredYear == null) return false;
    if (premieredYear! > year) return false;
    if (endedYear != null && endedYear! < year) return false;
    return true;
  }

  String get runRangeText {
    if (premieredYear == null) return 'Unknown run';
    if (endedYear == null) return '$premieredYear-present';
    return '$premieredYear-$endedYear';
  }
}
