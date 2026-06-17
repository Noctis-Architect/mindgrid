import 'dart:math';

import 'package:flutter/material.dart';

/// Mixed Persian/English welcome titles — one is picked at random on each app open.
const welcomeTitles = [
  'چطور می‌تونم کمکت کنم؟',
  'How can I help you today?',
  'امروز روی چی کار می‌کنی؟',
  'What would you like to explore?',
  'بیا یه چیز جالب بسازیم',
  'Ready when you are.',
  'سوال داری؟ من اینجام.',
  'Ask me anything — seriously.',
  'از کجا شروع کنیم؟',
  'Let\'s build something great.',
  'یه ایده داری یا دنبال الهام می‌گردی؟',
  'Your ideas, my full attention.',
];

String pickRandomWelcomeTitle([Random? random]) {
  final rng = random ?? Random();
  return welcomeTitles[rng.nextInt(welcomeTitles.length)];
}

/// Icons assigned to suggestion cards (LLM output has no icon field).
const welcomeSuggestionIcons = [
  Icons.lightbulb_outline_rounded,
  Icons.code_rounded,
  Icons.psychology_outlined,
  Icons.auto_awesome_outlined,
  Icons.compare_arrows_rounded,
  Icons.rate_review_outlined,
  Icons.edit_note_outlined,
  Icons.terminal_rounded,
  Icons.language_outlined,
  Icons.science_outlined,
];

IconData welcomeSuggestionIconAt(int index) {
  return welcomeSuggestionIcons[index % welcomeSuggestionIcons.length];
}
