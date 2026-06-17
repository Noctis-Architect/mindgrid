import 'package:flutter_test/flutter_test.dart';
import 'package:mindgrid/core/markdown_sanitize.dart';

void main() {
  group('sanitizeMarkdownForRender', () {
    test('closes unclosed fenced code block', () {
      const input = '```json\n{"note": "test"';
      expect(sanitizeMarkdownForRender(input), endsWith('```'));
    });

    test('closes unclosed inline backtick', () {
      expect(sanitizeMarkdownForRender('use `foo'), endsWith('`'));
    });

    test('closes unclosed bold markers', () {
      expect(sanitizeMarkdownForRender('**bold text'), endsWith('**'));
    });

    test('strips streaming cursor before sanitizing', () {
      expect(
        sanitizeMarkdownForRender('```json\n{'),
        '```json\n{\n```',
      );
    });

    test('leaves balanced markdown unchanged', () {
      const input = '```json\n{"a": 1}\n```';
      expect(sanitizeMarkdownForRender(input), input);
    });
  });
}
