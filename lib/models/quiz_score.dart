import 'package:cloud_firestore/cloud_firestore.dart';

class QuizScore {
  final String uid;
  final String displayName;
  final int score;
  final DateTime takenAt;

  QuizScore({
    required this.uid,
    required this.displayName,
    required this.score,
    required this.takenAt,
  });

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'score': score,
        'takenAt': Timestamp.fromDate(takenAt),
      };

  factory QuizScore.fromJson(String uid, Map<String, dynamic> json) {
    return QuizScore(
      uid: uid,
      displayName: json['displayName'] as String? ?? 'Unknown',
      score: (json['score'] as num?)?.toInt() ?? 0,
      takenAt: (json['takenAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
