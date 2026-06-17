import 'package:flutter_test/flutter_test.dart';
import 'package:mindgrid/data/welcome_content.dart';
import 'package:mindgrid/services/welcome_suggestions_service.dart';

void main() {
  final service = WelcomeSuggestionsService();

  group('pickRandomWelcomeTitle', () {
    test('returns a title from the pool', () {
      expect(welcomeTitles, contains(pickRandomWelcomeTitle()));
    });
  });

  group('parseResponse', () {
    test('returns null for empty input', () {
      expect(service.parseResponse(null), isNull);
      expect(service.parseResponse(''), isNull);
    });

    test('parses valid JSON with 4 suggestions', () {
      const raw = '''
{"suggestions":[
  {"label":"Flutter state","prompt":"Explain Riverpod vs Provider for Flutter apps"},
  {"label":"کد ریویو","prompt":"کد فلاتر من را بازبینی کن و پیشنهاد بهبود بده"},
  {"label":"API design","prompt":"Design a REST API for a todo app with auth"},
  {"label":"یادگیری","prompt":"یک برنامه ۲ هفته‌ای برای یادگیری Rust بده"}
]}''';
      final items = service.parseResponse(raw);
      expect(items, isNotNull);
      expect(items!.length, 4);
      expect(items.first.label, 'Flutter state');
      expect(items[1].label, 'کد ریویو');
    });

    test('parses fenced JSON', () {
      const raw = '''```json
{"suggestions":[
  {"label":"One","prompt":"First suggestion prompt here"},
  {"label":"Two","prompt":"Second suggestion prompt here"},
  {"label":"Three","prompt":"Third suggestion prompt here"},
  {"label":"Four","prompt":"Fourth suggestion prompt here"}
]}
```''';
      final items = service.parseResponse(raw);
      expect(items, isNotNull);
      expect(items!.length, 4);
    });

    test('rejects too few valid suggestions', () {
      const raw =
          '{"suggestions":[{"label":"Only","prompt":"Just one valid prompt"}]}';
      expect(service.parseResponse(raw), isNull);
    });

    test('filters duplicate prompts', () {
      const raw = '''
{"suggestions":[
  {"label":"A","prompt":"Same prompt text here"},
  {"label":"B","prompt":"Same prompt text here"},
  {"label":"C","prompt":"Third unique prompt here"},
  {"label":"D","prompt":"Fourth unique prompt here"}
]}''';
      expect(service.parseResponse(raw), isNull);
    });
  });
}
