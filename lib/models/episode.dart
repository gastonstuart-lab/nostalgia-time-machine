import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/text_sanitizer.dart';

class Episode {
  final String id;
  final String showTitle;
  final String episodeTitle;
  final String youtubeId;
  final String youtubeUrl;
  final int decadeTag;
  final String addedByUid;
  final String addedByName;
  final DateTime addedAt;

  Episode({
    required this.id,
    required this.showTitle,
    required this.episodeTitle,
    required this.youtubeId,
    required this.youtubeUrl,
    required this.decadeTag,
    required this.addedByUid,
    required this.addedByName,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
    'showTitle': showTitle,
    'episodeTitle': episodeTitle,
    'youtubeId': youtubeId,
    'youtubeUrl': youtubeUrl,
    'decadeTag': decadeTag,
    'addedByUid': addedByUid,
    'addedByName': addedByName,
    'addedAt': Timestamp.fromDate(addedAt),
  };

  factory Episode.fromJson(String id, Map<String, dynamic> json) => Episode(
    id: id,
    showTitle: decodeHtmlEntities((json['showTitle'] ?? '').toString()),
    episodeTitle: decodeHtmlEntities((json['episodeTitle'] ?? '').toString()),
    youtubeId: json['youtubeId'] ?? '',
    youtubeUrl: json['youtubeUrl'] ?? '',
    decadeTag: json['decadeTag'] ?? 1990,
    addedByUid: json['addedByUid'] ?? '',
    addedByName: json['addedByName'] ?? '',
    addedAt: (json['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}
