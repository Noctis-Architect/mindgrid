import 'chat_models.dart';

/// JSON backup format for chats (version 1).
class ChatExportBundle {
  const ChatExportBundle({
    required this.version,
    required this.exportedAt,
    required this.chats,
  });

  static const int currentVersion = 1;

  final int version;
  final int exportedAt;
  final List<ChatExportEntry> chats;

  Map<String, dynamic> toJson() => {
        'version': version,
        'exportedAt': exportedAt,
        'app': 'mindgrid',
        'chats': chats.map((c) => c.toJson()).toList(),
      };

  factory ChatExportBundle.fromJson(Map<String, dynamic> json) {
    final rawChats = json['chats'];
    final entries = rawChats is List
        ? rawChats
            .whereType<Map>()
            .map((e) => ChatExportEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <ChatExportEntry>[];

    return ChatExportBundle(
      version: json['version'] as int? ?? 1,
      exportedAt: json['exportedAt'] as int? ??
          DateTime.now().millisecondsSinceEpoch,
      chats: entries,
    );
  }
}

class ChatExportEntry {
  const ChatExportEntry({required this.chat, required this.messages});

  final Chat chat;
  final List<ChatMessage> messages;

  Map<String, dynamic> toJson() => {
        'chat': chat.toMap(),
        'messages': messages.map((m) => m.toMap()).toList(),
      };

  factory ChatExportEntry.fromJson(Map<String, dynamic> json) {
    final chatMap = json['chat'];
    final msgList = json['messages'];
    return ChatExportEntry(
      chat: Chat.fromMap(Map<String, dynamic>.from(chatMap as Map)),
      messages: msgList is List
          ? msgList
              .whereType<Map>()
              .map((m) => ChatMessage.fromMap(Map<String, dynamic>.from(m)))
              .toList()
          : [],
    );
  }
}
