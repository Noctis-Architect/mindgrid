import 'dart:convert';

class Chat {
  const Chat({
    required this.id,
    required this.title,
    required this.model,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String model;
  final int createdAt;
  final int updatedAt;

  Chat copyWith({
    String? title,
    String? model,
    int? updatedAt,
  }) {
    return Chat(
      id: id,
      title: title ?? this.title,
      model: model ?? this.model,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'model': model,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Chat.fromMap(Map<String, dynamic> map) => Chat(
        id: map['id'] as String,
        title: map['title'] as String? ?? 'New chat',
        model: map['model'] as String? ?? '',
        createdAt: map['createdAt'] as int,
        updatedAt: map['updatedAt'] as int,
      );
}

class MessageFile {
  const MessageFile({required this.name});
  final String name;

  Map<String, dynamic> toMap() => {'name': name};

  factory MessageFile.fromMap(Map<String, dynamic> map) =>
      MessageFile(name: map['name'] as String);
}

class MessageImage {
  const MessageImage({
    required this.name,
    required this.mimeType,
    required this.base64,
  });

  final String name;
  final String mimeType;
  final String base64;

  Map<String, dynamic> toMap() => {
        'name': name,
        'mimeType': mimeType,
        'base64': base64,
      };

  factory MessageImage.fromMap(Map<String, dynamic> map) => MessageImage(
        name: map['name'] as String? ?? 'image.png',
        mimeType: map['mimeType'] as String? ?? 'image/png',
        base64: map['base64'] as String,
      );
}

class AttachedImage {
  const AttachedImage({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final List<int> bytes;

  String get base64 => base64Encode(bytes);

  bool get isAudio => mimeType.startsWith('audio/');

  MessageImage toMessageImage() => MessageImage(
        name: name,
        mimeType: mimeType,
        base64: base64,
      );
}

class AttachedAudio {
  const AttachedAudio({
    required this.name,
    required this.bytes,
    this.durationMs,
  });

  final String name;
  final List<int> bytes;
  final int? durationMs;

  MessageImage toMessageImage() => MessageImage(
        name: name,
        mimeType: 'audio/wav',
        base64: base64Encode(bytes),
      );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.role,
    required this.content,
    this.thinking,
    this.model,
    this.files = const [],
    this.images = const [],
    required this.createdAt,
  });

  final String id;
  final String chatId;
  final String role;
  final String content;
  final String? thinking;
  final String? model;
  final List<MessageFile> files;
  final List<MessageImage> images;
  final int createdAt;

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  ChatMessage copyWith({
    String? content,
    String? thinking,
    String? model,
  }) {
    return ChatMessage(
      id: id,
      chatId: chatId,
      role: role,
      content: content ?? this.content,
      thinking: thinking ?? this.thinking,
      model: model ?? this.model,
      files: files,
      images: images,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'chatId': chatId,
        'role': role,
        'content': content,
        'thinking': thinking,
        'model': model,
        'files': files.map((f) => f.toMap()).toList(),
        'images': images.map((i) => i.toMap()).toList(),
        'createdAt': createdAt,
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    final filesRaw = map['files'];
    final files = filesRaw is List
        ? filesRaw
            .whereType<Map>()
            .map((e) => MessageFile.fromMap(Map<String, dynamic>.from(e)))
            .toList()
        : <MessageFile>[];

    final imagesRaw = map['images'];
    final images = imagesRaw is List
        ? imagesRaw
            .whereType<Map>()
            .map((e) => MessageImage.fromMap(Map<String, dynamic>.from(e)))
            .toList()
        : <MessageImage>[];

    return ChatMessage(
      id: map['id'] as String,
      chatId: map['chatId'] as String,
      role: map['role'] as String,
      content: map['content'] as String? ?? '',
      thinking: map['thinking'] as String?,
      model: map['model'] as String?,
      files: files,
      images: images,
      createdAt: map['createdAt'] as int,
    );
  }
}

class LlmModel {
  const LlmModel(
    this.name, {
    this.capabilities = const [],
    this.outputModalities = const [],
  });

  final String name;
  final List<String> capabilities;
  final List<String> outputModalities;
}

class AttachedFile {
  const AttachedFile({required this.name, required this.content});
  final String name;
  final String content;
}
