import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Syntax-highlight JSON preview (role colors like web prompt.js).
TextSpan highlightJson(String json) {
  final spans = <TextSpan>[];
  final pattern = RegExp(
    r'"(?:\\u[a-fA-F0-9]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(?:true|false|null)\b|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?',
  );

  var last = 0;
  for (final match in pattern.allMatches(json)) {
    if (match.start > last) {
      spans.add(TextSpan(text: json.substring(last, match.start)));
    }
    final m = match.group(0)!;
    TextStyle style;
    if (m.startsWith('"')) {
      if (m.endsWith(':')) {
        style = const TextStyle(color: AppColors.purple);
      } else {
        final v = m.replaceAll('"', '');
        style = switch (v) {
          'system' => const TextStyle(color: AppColors.accent),
          'user' => const TextStyle(color: Color(0xFF60A5FA)),
          'assistant' => const TextStyle(color: AppColors.yellow),
          _ => const TextStyle(color: Color(0xFF86EFAC)),
        };
      }
    } else if (m == 'true' || m == 'false') {
      style = const TextStyle(color: Color(0xFFF472B6));
    } else if (m == 'null') {
      style = const TextStyle(color: AppColors.text3);
    } else {
      style = const TextStyle(color: Color(0xFFFB923C));
    }
    spans.add(TextSpan(text: m, style: style));
    last = match.end;
  }
  if (last < json.length) {
    spans.add(TextSpan(text: json.substring(last)));
  }

  return TextSpan(
    children: spans,
    style: const TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      color: Color(0xFF9DA3C4),
      height: 1.45,
    ),
  );
}
