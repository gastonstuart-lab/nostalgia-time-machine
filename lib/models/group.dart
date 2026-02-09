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
  };

  factory Group.fromJson(String id, Map<String, dynamic> json) => Group(
    id: id,
    code: json['code'] ?? '',
    createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    createdByUid: json['createdByUid'] ?? '',
    currentYear: json['currentYear'] ?? 1990,
    currentDecadeStart: json['currentDecadeStart'] ?? 1990,
    currentWeekStart: (json['currentWeekStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
    status: json['status'] ?? 'active',
    currentWeekId: json['currentWeekId'] as String?,
  );
}
