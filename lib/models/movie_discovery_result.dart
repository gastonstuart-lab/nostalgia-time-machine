class MovieDiscoveryResult {
  final String title;
  final int? year;
  final String posterUrl;
  final String overview;
  final String genre;

  const MovieDiscoveryResult({
    required this.title,
    required this.year,
    required this.posterUrl,
    required this.overview,
    required this.genre,
  });
}
