import 'package:flutter_test/flutter_test.dart';
import 'package:mindgrid/models/app_settings.dart';
import 'package:mindgrid/services/network_discovery.dart';
import 'package:mindgrid/services/ollama_runtime.dart';

class _FakeDiscovery extends NetworkDiscoveryService {
  _FakeDiscovery(this.bases);

  final List<String> bases;

  @override
  Future<List<String>> discoverOllamaBases({
    String? primaryUrl,
    Duration timeout = const Duration(milliseconds: 800),
    int maxConcurrent = 48,
  }) async {
    return bases;
  }
}

void main() {
  group('OllamaRuntime listOllamaBases', () {
    test('preferKnownBase includes cached discovery bases as fallback', () async {
      final runtime = OllamaRuntime(
        discovery: _FakeDiscovery(['http://192.168.1.99:11434']),
      );

      await runtime.refreshNetworkBases('http://192.168.1.50:11434', force: true);

      final bases = await runtime.listOllamaBases(
        'http://192.168.1.50:11434',
        scanNetwork: false,
        preferKnownBase: true,
      );

      expect(bases, contains('http://192.168.1.50:11434'));
      expect(bases, contains('http://192.168.1.99:11434'));
    });

    test('scanNetwork false still uses cached bases after discovery', () async {
      final runtime = OllamaRuntime(
        discovery: _FakeDiscovery(['http://10.0.0.5:11434']),
      );

      await runtime.refreshNetworkBases('http://127.0.0.1:11434', force: true);

      final bases = await runtime.listOllamaBases(
        'http://127.0.0.1:11434',
        scanNetwork: false,
      );

      expect(bases, contains('http://10.0.0.5:11434'));
    });
  });

  group('OllamaRuntime prepareChatPayload', () {
    test('moves temperature into options for Ollama', () {
      final runtime = OllamaRuntime();
      const settings = AppSettings(thinkEnabled: false);

      final payload = runtime.prepareChatPayload(
        {
          'model': 'llama3',
          'messages': [
            {'role': 'user', 'content': 'hi'},
          ],
          'temperature': 0.2,
          'max_tokens': 128,
        },
        settings,
        isOllama: true,
      );

      expect(payload.containsKey('temperature'), isFalse);
      expect(
        (payload['options'] as Map)['temperature'],
        0.2,
      );
      expect(
        (payload['options'] as Map)['num_predict'],
        128,
      );
      expect(payload['think'], isFalse);
    });
  });
}
