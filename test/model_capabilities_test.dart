import 'package:flutter_test/flutter_test.dart';
import 'package:mindgrid/services/model_capabilities.dart';
import 'package:mindgrid/services/vision_message_builder.dart';
import 'package:mindgrid/models/chat_models.dart';

void main() {
  group('ModelCapabilities', () {
    test('detects gemma3 and gemma4 as vision models', () {
      expect(ModelCapabilities.supportsVision('gemma3:12b'), isTrue);
      expect(ModelCapabilities.supportsVision('gemma4:e2b'), isTrue);
      expect(ModelCapabilities.supportsVision('llava:latest'), isTrue);
      expect(ModelCapabilities.supportsVision('llama3.2:3b'), isFalse);
    });

    test('uses Ollama capabilities when available', () {
      expect(
        ModelCapabilities.supportsVision(
          'custom-model',
          capabilities: const ['completion', 'vision'],
        ),
        isTrue,
      );
      expect(
        ModelCapabilities.supportsAudio(
          'custom-model',
          capabilities: const ['audio'],
        ),
        isTrue,
      );
    });

    test('detects image generation from output modalities and names', () {
      expect(
        ModelCapabilities.supportsImageGeneration(
          'custom-model',
          outputModalities: const ['image', 'text'],
        ),
        isTrue,
      );
      expect(
        ModelCapabilities.supportsImageGeneration('openai/gpt-5-image'),
        isTrue,
      );
      expect(
        ModelCapabilities.supportsImageGeneration('google/gemini-2.5-flash-image'),
        isTrue,
      );
      expect(
        ModelCapabilities.supportsImageGeneration('llama3.2:3b'),
        isFalse,
      );
    });
  });

  group('VisionMessageBuilder', () {
    test('includes base64 images in Ollama payload', () {
      final message = ChatMessage(
        id: '1',
        chatId: 'c1',
        role: 'user',
        content: 'Describe this image.',
        images: const [
          MessageImage(name: 'a.png', mimeType: 'image/png', base64: 'abc123'),
        ],
        createdAt: 0,
      );

      final payload = VisionMessageBuilder.buildApiMessage(
        message,
        isOllama: true,
        thinkEnabled: false,
      );

      expect(payload['images'], ['abc123']);
      expect(payload['content'], 'Describe this image.');
    });

    test('uses OpenAI image_url parts for online providers', () {
      final message = ChatMessage(
        id: '1',
        chatId: 'c1',
        role: 'user',
        content: 'Describe this image.',
        images: const [
          MessageImage(name: 'a.png', mimeType: 'image/png', base64: 'abc123'),
        ],
        createdAt: 0,
      );

      final payload = VisionMessageBuilder.buildApiMessage(
        message,
        isOllama: false,
        thinkEnabled: false,
      );

      expect(payload['content'], isA<List>());
      final parts = payload['content'] as List;
      expect(parts.length, 2);
      expect(parts[0], {'type': 'text', 'text': 'Describe this image.'});
      expect(parts[1]['type'], 'image_url');
      expect(
        parts[1]['image_url']['url'],
        'data:image/png;base64,abc123',
      );
      expect(parts[1]['image_url']['detail'], 'auto');
    });
  });
}
