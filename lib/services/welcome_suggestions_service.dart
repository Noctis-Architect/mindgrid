import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/welcome_content.dart';
import '../l10n/app_strings.dart';
import '../models/app_settings.dart';
import '../models/welcome_suggestion.dart';
import 'llm_client.dart';
import 'ollama_runtime.dart';

const _cacheKey = 'welcome_suggestions_cache_v1';
const _lastRefreshKey = 'welcome_suggestions_last_refresh_v1';
const refreshInterval = Duration(days: 3);
const suggestionCount = 4;

const defaultSuggestionSystem = '''You generate personalized chat starter suggestions for an AI assistant app.

Given the user's profile and recent messages, output EXACTLY 4 suggestion cards tailored to them.

Rules:
- Match the user's language (Persian, English, or mixed as they typically write)
- label: max 40 characters — short topic name shown on a button
- prompt: max 140 characters — the full message they would send to the assistant
- Personalize from their interests, work, skills, and past topics when available
- If little context exists, suggest useful prompts for developers and creators
- Never repeat the same suggestion twice
- Output ONLY valid JSON with no markdown or extra text:
{"suggestions":[{"label":"...","prompt":"..."},{"label":"...","prompt":"..."},{"label":"...","prompt":"..."},{"label":"...","prompt":"..."}]}''';

class WelcomeSuggestionsService {
  WelcomeSuggestionsService({OllamaRuntime? runtime, LlmClient? client})
      : _runtime = runtime ?? OllamaRuntime(),
        _client = client ?? LlmClient();

  final OllamaRuntime _runtime;
  final LlmClient _client;

  List<WelcomeSuggestionItem> defaultsFromStrings(AppStrings strings) {
    return strings.welcomeSuggestions
        .map(
          (item) => WelcomeSuggestionItem(
            label: item.label,
            icon: item.icon,
            prompt: item.prompt,
          ),
        )
        .toList();
  }

  Future<List<WelcomeSuggestionItem>> loadCachedOrDefaults(
    AppStrings strings,
  ) async {
    try {
      final cached = await _loadCache();
      if (cached != null && cached.isNotEmpty) return cached;
    } catch (_) {}
    return defaultsFromStrings(strings);
  }

  Future<bool> shouldRefresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt(_lastRefreshKey);
      if (lastMs == null) return true;
      final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
      return DateTime.now().difference(last) >= refreshInterval;
    } catch (_) {
      return false;
    }
  }

  Future<List<WelcomeSuggestionItem>?> refreshIfNeeded({
    required AppSettings settings,
    required String selectedModel,
    required List<String> availableModels,
    required String userInfo,
    required List<String> recentUserMessages,
    required AppStrings strings,
  }) async {
    try {
      if (!await shouldRefresh()) return null;

      final model = _pickModel(selectedModel, availableModels);
      if (model == null) return null;

      final generated = await _generate(
        settings: settings,
        model: model,
        userInfo: userInfo,
        recentUserMessages: recentUserMessages,
      );
      if (generated == null || generated.isEmpty) return null;

      await _saveCache(generated);
      return generated;
    } catch (_) {
      return null;
    }
  }

  List<WelcomeSuggestionItem>? parseResponse(String? raw) {
    if (raw == null) return null;
    var text = raw.trim();
    if (text.isEmpty) return null;

    final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false)
        .firstMatch(text);
    if (fenced != null) text = fenced.group(1)!.trim();

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end <= start) return null;

    Map<String, dynamic> data;
    try {
      data = jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }

    final items = data['suggestions'];
    if (items is! List) return null;

    final seen = <String>{};
    final result = <WelcomeSuggestionItem>[];
    for (var i = 0; i < items.length && result.length < suggestionCount; i++) {
      final entry = items[i];
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final item = WelcomeSuggestionItem.fromJson(
        map,
        welcomeSuggestionIconAt(result.length),
      );
      if (item.label.length < 2 || item.prompt.length < 8) continue;
      if (item.label.length > 60 || item.prompt.length > 200) continue;
      final key = item.prompt.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      result.add(item);
    }

    return result.length >= suggestionCount ? result : null;
  }

  String? _pickModel(String selectedModel, List<String> availableModels) {
    final selected = selectedModel.trim();
    if (selected.isNotEmpty && availableModels.contains(selected)) {
      return selected;
    }
    if (availableModels.isEmpty) return null;
    return availableModels.first;
  }

  Future<List<WelcomeSuggestionItem>?> _generate({
    required AppSettings settings,
    required String model,
    required String userInfo,
    required List<String> recentUserMessages,
  }) async {
    final context = _buildContext(userInfo, recentUserMessages);
    final isOllama = settings.provider == LlmProvider.ollama;

    String raw;
    try {
      if (isOllama) {
        final prompt =
            '$defaultSuggestionSystem\n\n---\nUser context:\n$context\n\nJSON:';
        final result = await _runtime.fetchOllama(
          '/api/generate',
          settings,
          method: 'POST',
          headers: _client.authHeaders(settings),
          body: jsonEncode({
            'model': model,
            'prompt': prompt,
            'stream': false,
            'options': {'num_predict': 512, 'temperature': 0.7},
          }),
          scanNetwork: false,
          preferKnownBase: true,
        );
        if (!result.response.statusCode.toString().startsWith('2')) {
          return null;
        }
        final data = jsonDecode(result.response.body) as Map<String, dynamic>;
        raw = (data['response'] as String? ?? '').trim();
      } else {
        final base = _client.baseUrl(settings);
        final uri = Uri.parse('$base/chat/completions');
        final response = await http
            .post(
              uri,
              headers: _client.authHeaders(settings),
              body: jsonEncode({
                'model': model,
                'stream': false,
                'temperature': 0.7,
                'max_tokens': 512,
                'messages': [
                  {'role': 'system', 'content': defaultSuggestionSystem},
                  {
                    'role': 'user',
                    'content':
                        'Generate 4 personalized suggestions based on this context:\n\n$context',
                  },
                ],
              }),
            )
            .timeout(Duration(milliseconds: settings.requestTimeout));
        if (!response.statusCode.toString().startsWith('2')) return null;
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        raw = ((data['choices'] as List?)?.first as Map?)?['message']?['content']
                as String? ??
            '';
        raw = raw.trim();
      }
    } catch (_) {
      return null;
    }

    return parseResponse(raw);
  }

  String _buildContext(String userInfo, List<String> recentUserMessages) {
    final parts = <String>[];
    final profile = userInfo.trim();
    if (profile.isNotEmpty) {
      parts.add('Profile:\n$profile');
    }
    if (recentUserMessages.isNotEmpty) {
      final lines = recentUserMessages
          .take(15)
          .map((m) => '- ${m.substring(0, m.length.clamp(0, 200))}')
          .join('\n');
      parts.add('Recent user messages:\n$lines');
    }
    if (parts.isEmpty) {
      parts.add('No profile or message history yet — suggest broadly useful starters.');
    }
    return parts.join('\n\n');
  }

  Future<List<WelcomeSuggestionItem>?> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! List) return null;

    final items = <WelcomeSuggestionItem>[];
    for (var i = 0; i < decoded.length && i < suggestionCount; i++) {
      final entry = decoded[i];
      if (entry is! Map) continue;
      final item = WelcomeSuggestionItem.fromJson(
        Map<String, dynamic>.from(entry),
        welcomeSuggestionIconAt(i),
      );
      if (item.label.isEmpty || item.prompt.isEmpty) continue;
      items.add(item);
    }
    return items.length >= suggestionCount ? items : null;
  }

  Future<void> _saveCache(List<WelcomeSuggestionItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_cacheKey, payload);
    await prefs.setInt(_lastRefreshKey, DateTime.now().millisecondsSinceEpoch);
  }
}
