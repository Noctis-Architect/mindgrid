/// Stabilizes markdown so [flutter_markdown] does not crash on partial or
/// unbalanced syntax (e.g. while streaming, or JSON with stray markers).
String sanitizeMarkdownForRender(String input) {
  var text = input.replaceAll(RegExp(r' ▍$'), '');

  text = _closeFencedCodeBlocks(text);
  text = _closeInlineMarkers(text, '**');
  text = _closeInlineMarkers(text, '__');
  text = _closeInlineBackticks(text);

  return text;
}

String _closeFencedCodeBlocks(String text) {
  final count = RegExp(r'^```[^\n]*', multiLine: true).allMatches(text).length;
  if (count.isOdd) return '$text\n```';
  return text;
}

String _closeInlineBackticks(String text) {
  final withoutFences = text.replaceAllMapped(
    RegExp(r'```[\s\S]*?```'),
    (_) => '',
  );
  if (withoutFences.split('`').length.isOdd) return '$text`';
  return text;
}

String _closeInlineMarkers(String text, String marker) {
  final withoutFences = text.replaceAllMapped(
    RegExp(r'```[\s\S]*?```'),
    (_) => '',
  );
  if (_countUnescaped(withoutFences, marker).isOdd) return '$text$marker';
  return text;
}

int _countUnescaped(String text, String marker) {
  var count = 0;
  var i = 0;
  while (i <= text.length - marker.length) {
    if (text.startsWith(marker, i)) {
      count++;
      i += marker.length;
    } else {
      i++;
    }
  }
  return count;
}
