import 'package:flutter_test/flutter_test.dart';
import 'package:mindgrid/services/network_discovery.dart';
import 'package:mindgrid/services/ollama_runtime.dart';

void main() {
  group('OllamaRuntime', () {
    test('normalizeOllamaBase prefers IPv4 loopback', () {
      expect(
        OllamaRuntime.normalizeOllamaBase('http://localhost:11434'),
        'http://127.0.0.1:11434',
      );
      expect(
        OllamaRuntime.normalizeOllamaBase('http://[::1]:11434'),
        'http://127.0.0.1:11434',
      );
    });
  });

  group('NetworkDiscoveryService', () {
    test('findFirstReachableBase returns null for empty list', () async {
      final svc = NetworkDiscoveryService();
      final result = await svc.findFirstReachableBase([]);
      expect(result, isNull);
    });

    test('discoverOllamaBases always includes localhost candidates', () async {
      final svc = NetworkDiscoveryService();
      final bases = await svc.discoverOllamaBases(
        primaryUrl: 'http://192.168.1.50:11434',
        timeout: const Duration(milliseconds: 50),
      );
      expect(
        bases,
        containsAll([
          'http://192.168.1.50:11434',
          'http://127.0.0.1:11434',
        ]),
      );
      expect(bases, isNot(contains('http://[::1]:11434')));
    });
  });
}
