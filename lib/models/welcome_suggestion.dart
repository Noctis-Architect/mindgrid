import 'package:flutter/material.dart';

class WelcomeSuggestionItem {
  const WelcomeSuggestionItem({
    required this.label,
    required this.icon,
    required this.prompt,
  });

  final String label;
  final IconData icon;
  final String prompt;

  Map<String, dynamic> toJson() => {
        'label': label,
        'prompt': prompt,
      };

  factory WelcomeSuggestionItem.fromJson(
    Map<String, dynamic> json,
    IconData icon,
  ) {
    return WelcomeSuggestionItem(
      label: (json['label'] as String? ?? '').trim(),
      icon: icon,
      prompt: (json['prompt'] as String? ?? '').trim(),
    );
  }
}
