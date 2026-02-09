import 'package:cloud_firestore/cloud_firestore.dart';

class DecadeScore {
  final String uid;
  final String displayName;
  final int decadeStart;
  final int points;
  final int weeklyWins;
  final int weeksPlayed;
  final DateTime updatedAt;

  DecadeScore({
    required this.uid,
    required this.displayName,
    required this.decadeStart,
    required this.points,
    required this.weeklyWins,
    required this.weeksPlayed,
    required this.updatedAt,
  });

  factory DecadeScore.fromJson(String uid, Map<String, dynamic> json) {
    return DecadeScore(
      uid: uid,
      displayName: json['displayName'] as String? ?? 'Unknown',
      decadeStart: (json['decadeStart'] as num?)?.toInt() ?? 1990,
      points: (json['points'] as num?)?.toInt() ?? 0,
      weeklyWins: (json['weeklyWins'] as num?)?.toInt() ?? 0,
      weeksPlayed: (json['weeksPlayed'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
