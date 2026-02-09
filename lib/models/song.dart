import 'package:cloud_firestore/cloud_firestore.dart';

class Song {
  final String id;
  final String title;
  final String artist;
  final String youtubeId;
  final String youtubeUrl;
  final int yearTag;
  final String addedByUid;
  final String addedByName;
  final DateTime addedAt;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.youtubeId,
    required this.youtubeUrl,
    required this.yearTag,
    required this.addedByUid,
    required this.addedByName,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'artist': artist,
    'youtubeId': youtubeId,
    'youtubeUrl': youtubeUrl,
    'yearTag': yearTag,
    'addedByUid': addedByUid,
    'addedByName': addedByName,
    'addedAt': Timestamp.fromDate(addedAt),
  };

  factory Song.fromJson(String id, Map<String, dynamic> json) => Song(
    id: id,
    title: json['title'] ?? '',
    artist: json['artist'] ?? '',
    youtubeId: json['youtubeId'] ?? '',
    youtubeUrl: json['youtubeUrl'] ?? '',
    yearTag: json['yearTag'] ?? 1990,
    addedByUid: json['addedByUid'] ?? '',
    addedByName: json['addedByName'] ?? '',
    addedAt: (json['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}
