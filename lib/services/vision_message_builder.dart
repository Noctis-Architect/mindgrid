import '../models/chat_models.dart';

/// Builds API message payloads with optional vision images for Ollama and OpenAI-compatible APIs.
class VisionMessageBuilder {
  VisionMessageBuilder._();

  static Map<String, dynamic> buildApiMessage(
    ChatMessage message, {
    required bool isOllama,
    required bool thinkEnabled,
  }) {
    if (message.role == 'assistant' &&
        message.thinking != null &&
        message.thinking!.isNotEmpty &&
        thinkEnabled) {
      return {
        'role': message.role,
        'content': message.content,
        'thinking': message.thinking,
      };
    }

    if (message.role == 'user' && message.images.isNotEmpty) {
      return buildUserMessage(
        text: message.content,
        images: message.images,
        isOllama: isOllama,
      );
    }

    return {'role': message.role, 'content': message.content};
  }

  static Map<String, dynamic> buildUserMessage({
    required String text,
    required List<MessageImage> images,
    required bool isOllama,
  }) {
    if (images.isEmpty) {
      return {'role': 'user', 'content': text};
    }

    if (isOllama) {
      return {
        'role': 'user',
        'content': text,
        'images': images.map((i) => i.base64).toList(),
      };
    }

    final parts = <Map<String, dynamic>>[];
    if (text.isNotEmpty) {
      parts.add({'type': 'text', 'text': text});
    }
    for (final img in images) {
      parts.add({
        'type': 'image_url',
        'image_url': {
          'url': 'data:${img.mimeType};base64,${img.base64}',
          'detail': 'auto',
        },
      });
    }
    if (parts.isEmpty) {
      return {'role': 'user', 'content': text};
    }
    return {'role': 'user', 'content': parts};
  }
}
