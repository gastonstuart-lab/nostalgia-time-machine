import 'package:cloud_firestore/cloud_firestore.dart';

class DecadeWinner {
  final String uid;
  final String displayName;
  final int decadeStart;
  final int decadeEnd;
  final int points;
  final int weeklyWins;
  final int weeksPlayed;
  final DateTime awardedAt;

  DecadeWinner({
    required this.uid,
    required this.displayName,
    required this.decadeStart,
    required this.decadeEnd,
    required this.points,
    required this.weeklyWins,
    required this.weeksPlayed,
    required this.awardedAt,
  });

  factory DecadeWinner.fromJson(String uid, Map<String, dynamic> json) {
    return DecadeWinner(
      uid: uid,
      displayName: json['displayName'] as String? ?? 'Unknown',
      decadeStart: (json['decadeStart'] as num?)?.toInt() ?? 1990,
      decadeEnd: (json['decadeEnd'] as num?)?.toInt() ?? 1999,
      points: (json['points'] as num?)?.toInt() ?? 0,
      weeklyWins: (json['weeklyWins'] as num?)?.toInt() ?? 0,
      weeksPlayed: (json['weeksPlayed'] as num?)?.toInt() ?? 0,
      awardedAt: (json['awardedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
