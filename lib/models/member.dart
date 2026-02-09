import 'package:cloud_firestore/cloud_firestore.dart';

class Member {
  final String uid;
  final String displayName;
  final int avatarColor;
  final String avatarIcon;
  final DateTime joinedAt;

  Member({
    required this.uid,
    required this.displayName,
    required this.avatarColor,
    required this.avatarIcon,
    required this.joinedAt,
  });

  Map<String, dynamic> toJson() => {
    'displayName': displayName,
    'avatarColor': avatarColor,
    'avatarIcon': avatarIcon,
    'joinedAt': Timestamp.fromDate(joinedAt),
  };

  factory Member.fromJson(String uid, Map<String, dynamic> json) => Member(
    uid: uid,
    displayName: json['displayName'] ?? '',
    avatarColor: json['avatarColor'] ?? 0xFF6C5CE7,
    avatarIcon: json['avatarIcon'] ?? 'face_6',
    joinedAt: (json['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}
