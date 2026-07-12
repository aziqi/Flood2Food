import 'package:uuid/uuid.dart';

class AiChatSession {
  final String id;
  String title;
  List<Map<String, String>> messages;
  final DateTime createdAt;

  AiChatSession({
    String? id,
    this.title = 'Obrolan Baru',
    List<Map<String, String>>? messages,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'messages': messages,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AiChatSession.fromJson(Map<String, dynamic> json) {
    return AiChatSession(
      id: json['id'] as String,
      title: json['title'] as String,
      messages: (json['messages'] as List).map((e) => Map<String, String>.from(e)).toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
