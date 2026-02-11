import '../utils/text_sanitizer.dart';

class YouTubeSearchResult {
  final String videoId;
  final String title;
  final String channelTitle;
  final String thumbnailUrl;

  YouTubeSearchResult({
    required this.videoId,
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
  });

  factory YouTubeSearchResult.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final videoId = id is String ? id : (id['videoId'] ?? '');
    final snippet = json['snippet'] ?? {};
    
    final thumbnails = snippet['thumbnails'] ?? {};
    final thumbnail = thumbnails['medium'] ?? thumbnails['default'] ?? {};
    
    return YouTubeSearchResult(
      videoId: videoId,
      title: decodeHtmlEntities((snippet['title'] ?? '').toString()),
      channelTitle:
          decodeHtmlEntities((snippet['channelTitle'] ?? '').toString()),
      thumbnailUrl: thumbnail['url'] ?? '',
    );
  }
}
