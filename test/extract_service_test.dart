import 'package:flutter_test/flutter_test.dart';
import 'package:mindgrid/l10n/strings_en.dart';
import 'package:mindgrid/services/extract_service.dart';

void main() {
  final service = ExtractService();
  final strings = StringsEn();

  group('parseExtractResponse', () {
    test('returns null for empty input', () {
      expect(service.parseExtractResponse(null), isNull);
      expect(service.parseExtractResponse(''), isNull);
      expect(service.parseExtractResponse('none'), isNull);
    });

    test('parses fenced JSON', () {
      const raw = '''```json
{"facts":[{"category":"name","value":"علی رضایی"}]}
```''';
      final facts = service.parseExtractResponse(raw);
      expect(facts, isNotNull);
      expect(facts!.length, 1);
      expect(facts.first.category, 'name');
      expect(facts.first.value, 'علی رضایی');
    });

    test('filters short values and invalid categories', () {
      const raw =
          '{"facts":[{"category":"name","value":"abc"},{"category":"bogus","value":"valid long value here"}]}';
      final facts = service.parseExtractResponse(raw);
      expect(facts, isNotNull);
      expect(facts!.length, 1);
      expect(facts.first.category, 'other');
    });

    test('returns null when facts list empty after filtering', () {
      const raw = '{"facts":[{"category":"name","value":"short"}]}';
      expect(service.parseExtractResponse(raw), isNull);
    });
  });

  group('mergeUnique', () {
    test('appends only new facts', () {
      const prev = '• [نام] علی رضایی';
      final merged = service.mergeUnique(prev, const [
        ExtractFact(category: 'name', value: 'علی رضایی'),
        ExtractFact(category: 'role', value: 'توسعه‌دهنده فلاتر'),
      ], strings);
      expect(merged, contains('توسعه‌دهنده فلاتر'));
      expect(merged.split('\n').length, 2);
    });
  });
}
