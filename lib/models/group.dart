import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  final String id;
  final String code;
  final DateTime createdAt;
  final String createdByUid;
  final int currentYear;
  final int currentDecadeStart;
  final DateTime currentWeekStart;
  final String status; // "active" or "decade_vote"
  final String? currentWeekId;

  final String adminUid;
  final Map<String, dynamic>? settings;

  int get songCapPerUser {
    final raw = settings?['songCapPerUser'];
    if (raw is int) return raw < 1 ? 1 : (raw > 10 ? 10 : raw);
    if (raw is num) {
      final value = raw.toInt();
      return value < 1 ? 1 : (value > 10 ? 10 : value);
    }
    return 7;
  }

  int get episodeCapPerUser {
    final raw = settings?['episodeCapPerUser'];
    if (raw is int) return raw < 1 ? 1 : (raw > 3 ? 3 : raw);
    if (raw is num) {
      final value = raw.toInt();
      return value < 1 ? 1 : (value > 3 ? 3 : value);
    }
    return 1;
  }

  String get quizDifficulty {
    final raw = settings?['quizDifficulty'];
    if (raw == 'easy' || raw == 'medium' || raw == 'hard') return raw as String;
    return 'medium';
  }

  Group({
    required this.id,
    required this.code,
    required this.createdAt,
    required this.createdByUid,
    required this.currentYear,
    required this.currentDecadeStart,
    required this.currentWeekStart,
    this.status = 'active',
    this.currentWeekId,
    this.adminUid = '',
    this.settings,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'createdAt': Timestamp.fromDate(createdAt),
        'createdByUid': createdByUid,
        'currentYear': currentYear,
        'currentDecadeStart': currentDecadeStart,
        'currentWeekStart': Timestamp.fromDate(currentWeekStart),
        'status': status,
        if (currentWeekId != null) 'currentWeekId': currentWeekId,
        'adminUid': adminUid,
        if (settings != null) 'settings': settings,
      };

  factory Group.fromJson(String id, Map<String, dynamic> json) {
    final settingsRaw = json['settings'];
    final settings = settingsRaw is Map<String, dynamic> ? settingsRaw : null;
    return Group(
      id: id,
      code: json['code'] ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdByUid: json['createdByUid'] ?? '',
      currentYear: json['currentYear'] ?? 1990,
      currentDecadeStart: json['currentDecadeStart'] ?? 1990,
      currentWeekStart:
          (json['currentWeekStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: json['status'] ?? 'active',
      currentWeekId: json['currentWeekId'] as String?,
      adminUid: json['adminUid'] ?? (json['createdByUid'] ?? ''),
      settings: settings,
    );
  }
}
