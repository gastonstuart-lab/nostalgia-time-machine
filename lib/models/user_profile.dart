import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final int avatarColor;
  final String avatarIcon;
  final DateTime createdAt;
  final DateTime lastSeenAt;

  UserProfile({
    required this.uid,
    required this.displayName,
    required this.avatarColor,
    required this.avatarIcon,
    required this.createdAt,
    required this.lastSeenAt,
  });

  Map<String, dynamic> toJson() => {
    'displayName': displayName,
    'avatarColor': avatarColor,
    'avatarIcon': avatarIcon,
    'createdAt': Timestamp.fromDate(createdAt),
    'lastSeenAt': Timestamp.fromDate(lastSeenAt),
  };

  factory UserProfile.fromJson(String uid, Map<String, dynamic> json) => UserProfile(
    uid: uid,
    displayName: json['displayName'] ?? '',
    avatarColor: json['avatarColor'] ?? 0xFF6C5CE7,
    avatarIcon: json['avatarIcon'] ?? 'face_6',
    createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    lastSeenAt: (json['lastSeenAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );

  UserProfile copyWith({
    String? displayName,
    int? avatarColor,
    String? avatarIcon,
    DateTime? lastSeenAt,
  }) => UserProfile(
    uid: uid,
    displayName: displayName ?? this.displayName,
    avatarColor: avatarColor ?? this.avatarColor,
    avatarIcon: avatarIcon ?? this.avatarIcon,
    createdAt: createdAt,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
  );
}
