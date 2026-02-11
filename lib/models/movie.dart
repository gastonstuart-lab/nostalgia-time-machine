import 'package:cloud_firestore/cloud_firestore.dart';

class Movie {
  final String id;
  final String title;
  final int? year;
  final String? posterUrl;
  final String? overview;
  final String? genre;
  final String? trailerYoutubeId;
  final String? trailerYoutubeUrl;
  final String addedByUid;
  final String addedByName;
  final DateTime addedAt;

  Movie({
    required this.id,
    required this.title,
    this.year,
    this.posterUrl,
    this.overview,
    this.genre,
    this.trailerYoutubeId,
    this.trailerYoutubeUrl,
    required this.addedByUid,
    required this.addedByName,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        if (year != null) 'year': year,
        if (posterUrl != null && posterUrl!.isNotEmpty) 'posterUrl': posterUrl,
        if (overview != null && overview!.isNotEmpty) 'overview': overview,
        if (genre != null && genre!.isNotEmpty) 'genre': genre,
        if (trailerYoutubeId != null && trailerYoutubeId!.isNotEmpty)
          'trailerYoutubeId': trailerYoutubeId,
        if (trailerYoutubeUrl != null && trailerYoutubeUrl!.isNotEmpty)
          'trailerYoutubeUrl': trailerYoutubeUrl,
        'addedByUid': addedByUid,
        'addedByName': addedByName,
        'addedAt': Timestamp.fromDate(addedAt),
      };

  factory Movie.fromJson(String id, Map<String, dynamic> json) => Movie(
        id: id,
        title: json['title'] as String? ?? '',
        year: (json['year'] as num?)?.toInt(),
        posterUrl: json['posterUrl'] as String?,
        overview: json['overview'] as String?,
        genre: json['genre'] as String?,
        trailerYoutubeId: json['trailerYoutubeId'] as String?,
        trailerYoutubeUrl: json['trailerYoutubeUrl'] as String?,
        addedByUid: json['addedByUid'] as String? ?? '',
        addedByName: json['addedByName'] as String? ?? '',
        addedAt: (json['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}
