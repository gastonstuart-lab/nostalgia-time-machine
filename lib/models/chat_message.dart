import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String text;
  final String senderType; // "user" or "assistant"
  final DateTime createdAt;
  final String? userUid;
  final String status; // "sent", "processing", "error"

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderType,
    required this.createdAt,
    this.userUid,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'senderType': senderType,
    'createdAt': Timestamp.fromDate(createdAt),
    'userUid': userUid,
    'status': status,
  };

  factory ChatMessage.fromJson(String id, Map<String, dynamic> json) {
    return ChatMessage(
      id: id,
      text: json['text'] as String? ?? '',
      senderType: json['senderType'] as String? ?? 'user',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userUid: json['userUid'] as String?,
      status: json['status'] as String? ?? 'sent',
    );
  }
}
