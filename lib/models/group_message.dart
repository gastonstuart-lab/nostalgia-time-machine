import 'package:cloud_firestore/cloud_firestore.dart';

class GroupMessage {
  final String id;
  final String text;
  final String senderUid;
  final String senderName;
  final DateTime createdAt;

  GroupMessage({
    required this.id,
    required this.text,
    required this.senderUid,
    required this.senderName,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'senderUid': senderUid,
    'senderName': senderName,
    'createdAt': FieldValue.serverTimestamp(),
  };

  factory GroupMessage.fromJson(String id, Map<String, dynamic> json) => GroupMessage(
    id: id,
    text: json['text'] ?? '',
    senderUid: json['senderUid'] ?? '',
    senderName: json['senderName'] ?? '',
    createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}
