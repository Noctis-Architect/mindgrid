import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_settings.dart';
import '../models/chat_models.dart';
import 'local_http_client.dart';
import 'ollama_runtime.dart';

class StreamChunk {
  const StreamChunk({required this.content, this.thinking = ''});
  final String content;
  final String thinking;
}

class FetchModelsResult {
  const FetchModelsResult({required this.models, this.resolvedOllamaBase});
  final List<LlmModel> models;
  final String? resolvedOllamaBase;
}

class LlmClient {
  LlmClient({OllamaRuntime? runtime}) : _runtime = runtime ?? OllamaRuntime();

  final OllamaRuntime _runtime;

  String baseUrl(AppSettings settings) {
    if (settings.provider == LlmProvider.ollama) {
      return OllamaRuntime.normalizeOllamaBase(settings.ollamaUrl);
    }
    return settings.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
  }

  Map<String, String> authHeaders(AppSettings settings) {
    if (settings.provider == LlmProvider.ollama) {
      return _runtime.jsonAuthHeaders(settings);
    }
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final key = settings.apiKey.trim();
    if (key.isNotEmpty) headers['Authorization'] = 'Bearer $key';
    try {
      final extra = jsonDecode(settings.customHeaders);
      if (extra is Map) {
        for (final e in extra.entries) {
          headers[e.key.toString()] = e.value.toString();
        }
      }
    } catch (_) {}
    return headers;
  }

  Future<FetchModelsResult> fetchModels(
    AppSettings settings, {
    bool scanNetwork = true,
  }) async {
    if (settings.provider == LlmProvider.ollama) {
      if (scanNetwork) {
        await _runtime.refreshNetworkBases(settings.ollamaUrl);
      }
      final result = await _runtime.fetchOllama(
        '/api/tags',
        settings,
        method: 'GET',
        headers: _runtime.discoveryHeaders(settings),
        timeout: Duration(milliseconds: settings.requestTimeout),
        scanNetwork: scanNetwork,
      );
      final data = jsonDecode(result.response.body) as Map<String, dynamic>;
      final names = (data['models'] as List? ?? [])
          .map((m) => (m as Map)['name'] as String)
          .toList();
      final capabilities = scanNetwork
          ? await Future.wait(
              names.map(
                (name) => _fetchOllamaCapabilities(result.base, name, settings),
              ),
            )
          : names.map((_) => const <String>[]).toList();
      final models = <LlmModel>[
        for (var i = 0; i < names.length; i++)
          LlmModel(names[i], capabilities: capabilities[i]),
      ]..sort((a, b) => a.name.compareTo(b.name));
      return FetchModelsResult(
        models: models,
        resolvedOllamaBase: result.base,
      );
    }

    final uri = Uri.parse('${baseUrl(settings)}/models');
    final response = await http
        .get(uri, headers: authHeaders(settings))
        .timeout(Duration(milliseconds: settings.requestTimeout));
    if (!response.statusCode.toString().startsWith('2')) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final models = (data['data'] as List? ?? []).map((raw) {
      final m = raw as Map;
      final id = m['id'] as String;
      final arch = m['architecture'];
      final outputModalities = arch is Map
          ? (arch['output_modalities'] as List? ?? [])
              .map((e) => e.toString())
              .toList()
          : const <String>[];
      return LlmModel(id, outputModalities: outputModalities);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return FetchModelsResult(models: models);
  }

  Future<List<String>> _fetchOllamaCapabilities(
    String base,
    String modelName,
    AppSettings settings,
  ) async {
    try {
      final result = await _runtime.fetchOllama(
        '/api/show',
        settings,
        method: 'POST',
        body: jsonEncode({'name': modelName}),
        headers: _runtime.jsonAuthHeaders(settings),
        primaryUrl: base,
        timeout: Duration(milliseconds: settings.requestTimeout),
        scanNetwork: false,
        preferKnownBase: true,
      );
      final data = jsonDecode(result.response.body) as Map<String, dynamic>;
      return (data['capabilities'] as List? ?? [])
          .map((c) => c.toString())
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Stream<StreamChunk> streamChat({
    required AppSettings settings,
    required Map<String, dynamic> payload,
    String? editedPayloadJson,
    required List<Map<String, dynamic>> apiMessages,
    bool injectHistory = true,
    http.Client? client,
    bool disableThink = false,
    void Function(String base)? onOllamaBaseResolved,
  }) async* {
    final isOllama = settings.provider == LlmProvider.ollama;
    Map<String, dynamic> body;

    if (editedPayloadJson != null && editedPayloadJson.isNotEmpty) {
      try {
        body = Map<String, dynamic>.from(
          jsonDecode(editedPayloadJson) as Map<String, dynamic>,
        );
        final sys = _safeMessageMaps(body['messages'] as List?)
            .where((m) => m['role'] == 'system')
            .toList();
        body['messages'] = _mergeMessages(sys, apiMessages, injectHistory);
      } catch (_) {
        body = _mergeApiMessages(payload, apiMessages, injectHistory: injectHistory);
      }
    } else {
      body = _mergeApiMessages(payload, apiMessages, injectHistory: injectHistory);
    }

    body = _runtime.prepareChatPayload(
      body,
      settings,
      isOllama: isOllama,
      disableThink: disableThink,
    );
    final streaming = body['stream'] != false;

    final httpClient = client ??
        (isOllama
            ? createClientForBase(settings.ollamaUrl)
            : http.Client());
    var full = '';
    var thinking = '';
    var disposed = false;

    try {
      late final http.StreamedResponse response;
      late final String usedBase;

      if (isOllama) {
        final bases = await _runtime.listOllamaBases(settings.ollamaUrl);
        Object? lastErr;
        http.StreamedResponse? res;
        String? chatBase;
        for (final base in bases) {
          try {
            res = await _postChat(httpClient, base, body, settings, isOllama: true);
            if (res.statusCode >= 200 && res.statusCode < 300) {
              chatBase = base;
              break;
            }
            final errBody = await res.stream.bytesToString();
            if (_runtime.isThinkingUnsupportedError(res.statusCode, errBody)) {
              body = _runtime.stripThinkPayload(body);
              res = await _postChat(httpClient, base, body, settings, isOllama: true);
              if (res.statusCode >= 200 && res.statusCode < 300) {
                chatBase = base;
                break;
              }
              final retryBody = await res.stream.bytesToString();
              throw Exception(_runtime.formatFetchError(res.statusCode, retryBody));
            }
            throw Exception(_runtime.formatFetchError(res.statusCode, errBody));
          } catch (e) {
            lastErr = e;
          }
        }
        if (res == null || chatBase == null) {
          throw lastErr ?? Exception('Ollama unreachable');
        }
        response = res;
        usedBase = chatBase;
        _runtime.rememberReachableBase(usedBase);
      } else {
        response = await _postChat(
          httpClient,
          baseUrl(settings),
          body,
          settings,
          isOllama: false,
        );
        usedBase = baseUrl(settings);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          final errBody = await response.stream.bytesToString();
          throw Exception(_runtime.formatFetchError(response.statusCode, errBody));
        }
      }

      if (isOllama &&
          usedBase.replaceAll(RegExp(r'/+$'), '') !=
              settings.ollamaUrl.replaceAll(RegExp(r'/+$'), '')) {
        onOllamaBaseResolved?.call(usedBase);
      }

      if (!streaming) {
        final bodyText = await response.stream.bytesToString();
        final chunk = _parseNonStreamingBody(bodyText, settings.thinkEnabled);
        yield chunk;
        return;
      }

      final collectThinking = settings.thinkEnabled;
      var buf = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buf += chunk;
        if (buf.length > 100000) buf = buf.substring(buf.length - 50000);
        final lines = buf.split('\n');
        buf = lines.removeLast();

        for (final raw in lines) {
          final line = raw.trim();
          if (line.isEmpty) continue;

          final jsonStr =
              line.startsWith('data: ') ? line.substring(6) : line;
          if (jsonStr == '[DONE]') {
            yield StreamChunk(content: full, thinking: thinking);
            return;
          }

          Map<String, dynamic>? obj;
          try {
            obj = jsonDecode(jsonStr) as Map<String, dynamic>;
          } catch (_) {
            continue;
          }

          var changed = false;
          if (obj.containsKey('message')) {
            final msg = obj['message'] as Map<String, dynamic>?;
            if (collectThinking && msg?['thinking'] is String && (msg!['thinking'] as String).isNotEmpty) {
              thinking += msg['thinking'] as String;
              changed = true;
            }
            if (msg?['content'] is String && (msg!['content'] as String).isNotEmpty) {
              full += msg['content'] as String;
              changed = true;
            }
            if (changed) yield StreamChunk(content: full, thinking: thinking);
            if (obj['done'] == true) {
              yield StreamChunk(content: full, thinking: thinking);
              return;
            }
            continue;
          }

          final delta = (obj['choices'] as List?)?.first as Map<String, dynamic>?;
          final deltaMap = delta?['delta'] as Map<String, dynamic>?;
          if (deltaMap != null) {
            final reasoning =
                deltaMap['reasoning_content'] ?? deltaMap['reasoning'];
            if (collectThinking && reasoning is String && reasoning.isNotEmpty) {
              thinking += reasoning;
              changed = true;
            }
            if (deltaMap['content'] is String && (deltaMap['content'] as String).isNotEmpty) {
              full += deltaMap['content'] as String;
              changed = true;
            }
            if (changed) yield StreamChunk(content: full, thinking: thinking);
          }

          final finish = delta?['finish_reason'];
          if (finish != null && finish != 'null') {
            yield StreamChunk(content: full, thinking: thinking);
            return;
          }
        }
      }
      yield StreamChunk(content: full, thinking: thinking);
    } finally {
      if (!disposed && client == null) {
        httpClient.close();
      }
    }
  }

  StreamChunk _parseNonStreamingBody(String bodyText, bool collectThinking) {
    var content = '';
    var thinking = '';
    try {
      final obj = jsonDecode(bodyText) as Map<String, dynamic>;
      if (obj.containsKey('message')) {
        final msg = obj['message'] as Map<String, dynamic>?;
        content = msg?['content'] as String? ?? '';
        if (collectThinking) {
          thinking = msg?['thinking'] as String? ?? '';
        }
      } else {
        final choice = (obj['choices'] as List?)?.first as Map<String, dynamic>?;
        final msg = choice?['message'] as Map<String, dynamic>?;
        content = msg?['content'] as String? ?? '';
        if (collectThinking) {
          thinking = (msg?['reasoning_content'] ?? msg?['reasoning']) as String? ?? '';
        }
      }
    } catch (_) {
      content = bodyText;
    }
    return StreamChunk(content: content, thinking: thinking);
  }

  Future<http.StreamedResponse> _postChat(
    http.Client client,
    String base,
    Map<String, dynamic> body,
    AppSettings settings, {
    required bool isOllama,
  }) {
    final url = isOllama
        ? Uri.parse('$base/api/chat')
        : Uri.parse('$base/chat/completions');
    final request = http.Request('POST', url)
      ..headers.addAll(authHeaders(settings))
      ..body = jsonEncode(body);
    final sent = client.send(request);
    final timeout = _chatTimeout(settings, body, isOllama: isOllama);
    if (timeout == null) return sent;
    return sent.timeout(timeout);
  }

  Duration? _chatTimeout(
    AppSettings settings,
    Map<String, dynamic> body, {
    required bool isOllama,
  }) {
    if (_payloadHasImages(body)) return null;
    var ms = settings.requestTimeout;
    // Ollama may load a model into memory before the first response byte.
    if (isOllama && ms < 120000) ms = 120000;
    return Duration(milliseconds: ms);
  }

  bool _payloadHasImages(Map<String, dynamic> body) {
    final messages = body['messages'];
    if (messages is! List) return false;
    for (final raw in messages) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final images = m['images'];
      if (images is List && images.isNotEmpty) return true;
      final content = m['content'];
      if (content is List) {
        for (final part in content) {
          if (part is Map && part['type'] == 'image_url') return true;
        }
      }
    }
    return false;
  }

  Map<String, dynamic> _mergeApiMessages(
    Map<String, dynamic> payload,
    List<Map<String, dynamic>> apiMessages, {
    bool injectHistory = true,
  }) {
    final body = Map<String, dynamic>.from(payload);
    final sys = _safeMessageMaps(body['messages'] as List?)
        .where((m) => m['role'] == 'system')
        .toList();
    body['messages'] = _mergeMessages(sys, apiMessages, injectHistory);
    return body;
  }

  List<Map<String, dynamic>> _safeMessageMaps(List? raw) {
    if (raw == null) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<Map<String, dynamic>> _mergeMessages(
    List<Map<String, dynamic>> systemMessages,
    List<Map<String, dynamic>> apiMessages,
    bool injectHistory,
  ) {
    if (injectHistory) {
      return [...systemMessages, ...apiMessages];
    }
    final lastUser = apiMessages.lastWhere(
      (m) => m['role'] == 'user',
      orElse: () => apiMessages.isNotEmpty ? apiMessages.last : {},
    );
    if (lastUser.isEmpty) return [...systemMessages];
    return [...systemMessages, lastUser];
  }
}
