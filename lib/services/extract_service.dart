import 'dart:convert';

import 'package:http/http.dart' as http;

import '../l10n/app_strings.dart';
import '../models/app_settings.dart';
import 'llm_client.dart';
import 'ollama_runtime.dart';

const defaultExtractSystem = '''You are a strict user-profile extraction assistant.

Task: read a short conversation excerpt and decide whether the USER revealed NEW, IMPORTANT, LONG-TERM facts worth storing in their permanent profile.

EXTRACT ONLY stable, high-value facts such as:
- identity: name, age, location, native language
- professional: job title, employer, field, seniority, education
- technical: programming languages, frameworks, tools, stack
- active work: long-term projects, products, domains they own
- persistent preferences: answer style, language, constraints, accessibility needs

DO NOT EXTRACT:
- greetings, thanks, small talk, or one-off questions
- temporary states ("today", "right now", "this week")
- facts only inferred by the assistant, not stated by the user
- trivial, vague, or low-confidence details
- anything already obvious from generic chat

OUTPUT RULES (critical):
- If there is at least one truly important fact, respond with ONLY valid JSON — no markdown, no prose:
  {"facts":[{"category":"name|role|skills|project|preference|location|education|other","value":"concise fact in user's language"}]}
- If nothing is important enough to store, respond with exactly: {}
- Maximum 5 facts; never invent information; omit uncertain items
- Empty {} means store nothing — prefer false negatives over noise''';

class ExtractFact {
  const ExtractFact({required this.category, required this.value});
  final String category;
  final String value;
}

class ExtractService {
  ExtractService({OllamaRuntime? runtime, LlmClient? client})
      : _runtime = runtime ?? OllamaRuntime(),
        _client = client ?? LlmClient();

  final OllamaRuntime _runtime;
  final LlmClient _client;

  String buildConversation(String userMsg, String aiMsg) {
    return 'User:\n${userMsg.substring(0, userMsg.length.clamp(0, 600))}\n\nAssistant:\n${aiMsg.substring(0, aiMsg.length.clamp(0, 400))}';
  }

  List<ExtractFact>? parseExtractResponse(String? raw) {
    if (raw == null) return null;
    var text = raw.trim();
    if (text.isEmpty || RegExp(r'^none$', caseSensitive: false).hasMatch(text)) {
      return null;
    }

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

    final facts = data['facts'];
    if (facts is! List) return null;
    const allowed = {
      'name',
      'role',
      'skills',
      'project',
      'preference',
      'location',
      'education',
      'other',
    };

    final cleaned = facts
        .whereType<Map>()
        .map((f) {
          final cat = (f['category'] as String? ?? 'other').trim().toLowerCase();
          final val = (f['value'] as String? ?? '').trim();
          return ExtractFact(
            category: allowed.contains(cat) ? cat : 'other',
            value: val,
          );
        })
        .where((f) => f.value.length >= 6 && f.value.length <= 180)
        .toList();

    return cleaned.isEmpty ? null : cleaned;
  }

  String formatFacts(List<ExtractFact> facts, AppStrings strings) {
    final labels = strings.extractFieldLabels;
    return facts
        .map((f) => '• [${labels[f.category] ?? f.category}] ${f.value}')
        .join('\n');
  }

  String mergeUnique(String prevText, List<ExtractFact> facts, AppStrings strings) {
    final previous = prevText;
    final normalized = previous.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final unique = facts.where((f) {
      final v = f.value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      return !normalized.contains(v);
    }).toList();
    if (unique.isEmpty) return previous;
    final block = formatFacts(unique, strings);
    return previous.isEmpty ? block : '$previous\n$block';
  }

  Future<String?> extractAndMerge({
    required AppSettings settings,
    required String selectedModel,
    required String userInfo,
    required String userMsg,
    required String aiMsg,
    required AppStrings strings,
  }) async {
    if (!settings.autoExtract || userMsg.trim().length < 8) return null;

    final model = settings.extractModelManual.trim().isNotEmpty
        ? settings.extractModelManual.trim()
        : (settings.extractModel.isNotEmpty
            ? settings.extractModel
            : selectedModel);
    if (model.isEmpty) return null;

    final system = settings.extractPrompt.trim().isNotEmpty
        ? settings.extractPrompt.trim()
        : defaultExtractSystem;
    final conversation = buildConversation(userMsg, aiMsg);

    final eProvider = settings.extractProvider;
    late final String eBase;
    late final Map<String, String> eHeaders;
    late final bool eIsOllama;

    if (eProvider == ExtractProvider.same) {
      eBase = _client.baseUrl(settings);
      eHeaders = _client.authHeaders(settings);
      eIsOllama = settings.provider == LlmProvider.ollama;
    } else if (eProvider == ExtractProvider.ollama) {
      eBase = settings.ollamaUrl.replaceAll(RegExp(r'/+$'), '');
      eHeaders = {'Content-Type': 'application/json'};
      eIsOllama = true;
    } else {
      final eKey = settings.extractApiKey.trim();
      eBase = (settings.extractApiBase.isNotEmpty
              ? settings.extractApiBase
              : 'https://api.openai.com/v1')
          .replaceAll(RegExp(r'/+$'), '');
      eHeaders = {
        'Content-Type': 'application/json',
        if (eKey.isNotEmpty) 'Authorization': 'Bearer $eKey',
      };
      eIsOllama = false;
    }

    String raw;
    if (eIsOllama) {
      final prompt = '$system\n\n---\nConversation:\n$conversation\n\nJSON:';
      final result = await _runtime.fetchOllama(
        '/api/generate',
        settings,
        method: 'POST',
        headers: eHeaders,
        body: jsonEncode({
          'model': model,
          'prompt': prompt,
          'stream': false,
          'options': {'num_predict': 256, 'temperature': 0.1},
        }),
        primaryUrl: eBase,
        scanNetwork: false,
        preferKnownBase: true,
      );
      final data = jsonDecode(result.response.body) as Map<String, dynamic>;
      raw = (data['response'] as String? ?? '').trim();
    } else {
      final uri = Uri.parse('$eBase/chat/completions');
      final response = await http.post(
        uri,
        headers: eHeaders,
        body: jsonEncode({
          'model': model,
          'stream': false,
          'temperature': 0.1,
          'max_tokens': 256,
          'messages': [
            {'role': 'system', 'content': system},
            {
              'role': 'user',
              'content':
                  'Analyze this conversation and return JSON per the rules.\n\n$conversation',
            },
          ],
        }),
      );
      if (!response.statusCode.toString().startsWith('2')) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      raw = ((data['choices'] as List?)?.first as Map?)?['message']?['content']
              as String? ??
          '';
      raw = raw.trim();
    }

    final facts = parseExtractResponse(raw);
    if (facts == null) return null;
    final next = mergeUnique(userInfo, facts, strings);
    return next == userInfo ? null : next;
  }
}
