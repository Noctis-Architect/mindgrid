import 'package:flutter_test/flutter_test.dart';
import 'package:mindgrid/models/ollama_models.dart';

void main() {
  group('OllamaPullProgress.fromPullJson', () {
    test('parses numeric completed/total from JSON numbers', () {
      final progress = OllamaPullProgress.fromPullJson(
        {
          'status': 'downloading sha256:abc',
          'completed': 512,
          'total': 2048,
        },
        model: 'llama3.2',
      );

      expect(progress.completed, 512);
      expect(progress.total, 2048);
      expect(progress.percent, 25);
    });

    test('parses completed/total when encoded as doubles', () {
      final progress = OllamaPullProgress.fromPullJson(
        {
          'status': 'downloading sha256:abc',
          'completed': 512.0,
          'total': 2048.0,
        },
        model: 'llama3.2',
      );

      expect(progress.completed, 512);
      expect(progress.total, 2048);
    });

    test('carries forward previous byte counts between layers', () {
      final first = OllamaPullProgress.fromPullJson(
        {
          'status': 'downloading sha256:abc',
          'completed': 100,
          'total': 1000,
        },
        model: 'llama3.2',
      );

      final second = OllamaPullProgress.fromPullJson(
        {'status': 'verifying sha256:abc'},
        model: 'llama3.2',
        lastCompleted: first.completed,
        lastTotal: first.total,
      );

      expect(second.completed, 100);
      expect(second.total, 1000);
    });
  });
}
