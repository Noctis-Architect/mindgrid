import 'package:flutter/material.dart';

import '../l10n/app_locale.dart';

final _rtlRe = RegExp(
  r'[\u0590-\u05FF\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
);
final _ltrRe = RegExp(
  r'[a-zA-Z0-9\u00C0-\u00FF\u0100-\u017F\u0180-\u024F\u0250-\u02AF\u02B0-\u02FF\u0370-\u03FF]',
);
final _cjkRe = RegExp(
  r'[\u3000-\u303F\u3040-\u30FF\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF\uAC00-\uD7AF\uFF00-\uFFEF]',
);

bool containsRtl(String text) => _rtlRe.hasMatch(text);
bool containsCjk(String text) => _cjkRe.hasMatch(text);

TextDirection detectTextDirection(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return TextDirection.ltr;

  var rtl = 0;
  var ltr = 0;
  for (final rune in trimmed.runes) {
    final ch = String.fromCharCode(rune);
    if (_rtlRe.hasMatch(ch)) {
      rtl++;
    } else if (_ltrRe.hasMatch(ch) || _cjkRe.hasMatch(ch)) {
      ltr++;
    }
  }

  if (rtl > 0 && rtl >= ltr) return TextDirection.rtl;
  return TextDirection.ltr;
}

TextDirection localeTextDirection(AppLocale locale) {
  return locale == AppLocale.fa ? TextDirection.rtl : TextDirection.ltr;
}

TextDirection textDirectionFor(
  String text, {
  TextDirection localeDefault = TextDirection.ltr,
}) {
  if (text.trim().isEmpty) return localeDefault;
  return detectTextDirection(text);
}

TextAlign textAlignFor(
  String text, {
  TextDirection localeDefault = TextDirection.ltr,
}) {
  return textDirectionFor(text, localeDefault: localeDefault) ==
          TextDirection.rtl
      ? TextAlign.right
      : TextAlign.left;
}

/// Alignment direction for a message; falls back when content is empty (e.g. streaming).
TextDirection alignDirectionFor(
  String content, {
  String? fallback,
  TextDirection defaultDirection = TextDirection.ltr,
}) {
  if (content.trim().isNotEmpty) return detectTextDirection(content);
  if (fallback != null && fallback.trim().isNotEmpty) {
    return detectTextDirection(fallback);
  }
  return defaultDirection;
}
