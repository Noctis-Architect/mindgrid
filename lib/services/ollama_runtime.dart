import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_settings.dart';
import 'local_http_client.dart';
import 'network_discovery.dart';

class OllamaRuntime {
  OllamaRuntime({NetworkDiscoveryService? discovery})
      : _discovery = discovery ?? NetworkDiscoveryService();

  final NetworkDiscoveryService _discovery;
  List<String> _cachedBases = [];
  String? _lastReachableBase;
  DateTime? _basesCacheTime;
  static const _basesCacheTtl = Duration(minutes: 2);

  /// Prefer IPv4 loopback — many Ollama installs do not listen on [::1].
  static String normalizeOllamaBase(String url) {
    final trimmed = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.isEmpty) return 'http://127.0.0.1:11434';
    try {
      final uri = Uri.parse(trimmed);
      final host = uri.host.toLowerCase();
      if (host == 'localhost' || host == '::1') {
        return uri
            .replace(host: '127.0.0.1')
            .toString()
            .replaceAll(RegExp(r'/+$'), '');
      }
    } catch (_) {}
    return trimmed;
  }

  static bool isLocalOllamaHost(String base) {
    try {
      final host = Uri.parse(base).host.toLowerCase();
      return host == '127.0.0.1' || host == 'localhost' || host == '::1';
    } catch (_) {
      return false;
    }
  }

  bool modelLikelySupportsThinking(String? modelName) {
    if (modelName == null || modelName.isEmpty) return false;
    final n = modelName.toLowerCase();
    return RegExp(r'(?:^|[-_:])gemma[34]').hasMatch(n) ||
        RegExp(r'deepseek[-_]?r1').hasMatch(n) ||
        RegExp(r'\bqwq\b').hasMatch(n) ||
        RegExp(r'qwen3').hasMatch(n) ||
        RegExp(r'(?:^|[-_:])(?:o1|o3)(?:[-_:]|$)').hasMatch(n);
  }

  bool isThinkingUnsupportedError(int status, String body) {
    return status == 400 && RegExp(r'does not support thinking', caseSensitive: false).hasMatch(body);
  }

  String formatFetchError(int status, String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['error'] != null) {
        final err = j['error'];
        if (err is Map && err['message'] != null) {
          return 'HTTP $status: ${err['message']}';
        }
        return 'HTTP $status: $err';
      }
    } catch (_) {}
    final t = body.trim();
    if (t.startsWith('<!DOCTYPE') ||
        t.startsWith('<html') ||
        t.contains('/_next/static/')) {
      return 'HTTP $status: API endpoint not found — check Base URL and provider settings';
    }
    return t.isNotEmpty
        ? 'HTTP $status: ${t.substring(0, t.length.clamp(0, 280))}'
        : 'HTTP $status';
  }

  Map<String, String> discoveryHeaders(AppSettings settings) {
    final headers = <String, String>{'Accept': 'application/json'};
    final key = settings.apiKey.trim();
    if (key.isNotEmpty) headers['Authorization'] = 'Bearer $key';
    try {
      final extra = jsonDecode(settings.customHeaders);
      if (extra is Map) {
        for (final entry in extra.entries) {
          if (entry.key.toString().toLowerCase() == 'content-type') continue;
          headers[entry.key.toString()] = entry.value.toString();
        }
      }
    } catch (_) {}
    return headers;
  }

  Map<String, String> jsonAuthHeaders(AppSettings settings) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final key = settings.apiKey.trim();
    if (key.isNotEmpty) headers['Authorization'] = 'Bearer $key';
    try {
      final extra = jsonDecode(settings.customHeaders);
      if (extra is Map) {
        for (final entry in extra.entries) {
          headers[entry.key.toString()] = entry.value.toString();
        }
      }
    } catch (_) {}
    return headers;
  }

  Future<List<String>> listOllamaBases(
    String primary, {
    bool scanNetwork = true,
    bool preferKnownBase = false,
  }) async {
    final normalizedPrimary = normalizeOllamaBase(primary);

    if (preferKnownBase) {
      final fast = <String>[];
      void addFast(String? s) {
        if (s == null || s.trim().isEmpty) return;
        final n = normalizeOllamaBase(s.trim());
        if (!fast.contains(n)) fast.add(n);
      }

      addFast(_lastReachableBase);
      addFast(normalizedPrimary);
      for (final b in _cachedBases) {
        addFast(b);
      }
      if (isLocalOllamaHost(normalizedPrimary)) {
        addFast('http://127.0.0.1:11434');
      }
      if (fast.isNotEmpty) return fast;
    }

    if (scanNetwork && _cachedBases.isEmpty) {
      _cachedBases = await _discovery.discoverOllamaBases(
        primaryUrl: normalizedPrimary,
      );
    }

    final bases = <String>[];
    void add(String? s) {
      if (s == null || s.trim().isEmpty) return;
      final n = normalizeOllamaBase(s.trim());
      if (!bases.contains(n)) bases.add(n);
    }

    add(_lastReachableBase);
    add(normalizedPrimary);
    for (final b in _cachedBases) {
      add(b);
    }
    if (isLocalOllamaHost(normalizedPrimary)) {
      add('http://127.0.0.1:11434');
    }
    return bases;
  }

  Future<void> refreshNetworkBases(String primary, {bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _cachedBases.isNotEmpty &&
        _basesCacheTime != null &&
        now.difference(_basesCacheTime!) < _basesCacheTtl) {
      return;
    }
    _cachedBases = await _discovery.discoverOllamaBases(
      primaryUrl: normalizeOllamaBase(primary),
    );
    _basesCacheTime = now;
  }

  void rememberReachableBase(String base) {
    _lastReachableBase = normalizeOllamaBase(base);
  }

  Map<String, dynamic> prepareChatPayload(
    Map<String, dynamic> payload,
    AppSettings settings, {
    required bool isOllama,
    bool disableThink = false,
  }) {
    final p = Map<String, dynamic>.from(payload);
    p.remove('_endpoint');
    if (!isOllama) return p;

    final maxTok = p.remove('max_tokens');
    p['options'] = Map<String, dynamic>.from(p['options'] as Map? ?? {});
    final options = p['options'] as Map<String, dynamic>;
    if (p['temperature'] != null && options['temperature'] == null) {
      options['temperature'] = p['temperature'];
    }
    if (maxTok != null && options['num_predict'] == null) {
      options['num_predict'] = maxTok;
    }
    p.remove('temperature');
    if (settings.thinkEnabled && !disableThink) {
      p['think'] = true;
    } else {
      // Ollama thinking-capable models still reason when "think" is omitted;
      // an explicit false is required to disable it.
      p['think'] = false;
    }
    return p;
  }

  Map<String, dynamic> stripThinkPayload(Map<String, dynamic> payload) {
    final p = Map<String, dynamic>.from(payload);
    p['think'] = false;
    if (p['messages'] is List) {
      p['messages'] = (p['messages'] as List).map((m) {
        if (m is Map && m['thinking'] != null) {
          final copy = Map<String, dynamic>.from(m);
          copy.remove('thinking');
          return copy;
        }
        return m;
      }).toList();
    }
    return p;
  }

  Future<({http.Response response, String base})> fetchOllama(
    String path,
    AppSettings settings, {
    required String method,
    String? body,
    Map<String, String>? headers,
    String? primaryUrl,
    Duration timeout = const Duration(seconds: 30),
    bool scanNetwork = true,
    bool preferKnownBase = false,
  }) async {
    final bases = await listOllamaBases(
      primaryUrl ?? settings.ollamaUrl,
      scanNetwork: scanNetwork,
      preferKnownBase: preferKnownBase,
    );
    Object? lastErr;
    for (final base in bases) {
      try {
        final uri = Uri.parse('$base$path');
        final client = createClientForBase(base);
        try {
          final request = http.Request(method, uri)
            ..headers.addAll(headers ?? jsonAuthHeaders(settings));
          if (body != null && body.isNotEmpty && method.toUpperCase() != 'GET') {
            request.body = body;
          }
          final response = await client
              .send(request)
              .timeout(timeout)
              .then(http.Response.fromStream);
          if (!response.statusCode.toString().startsWith('2')) {
            throw HttpExceptionLike(response.statusCode, base);
          }
          rememberReachableBase(base);
          return (response: response, base: base);
        } finally {
          client.close();
        }
      } catch (e) {
        lastErr = e;
      }
    }
    throw lastErr ?? Exception('Ollama unreachable');
  }
}

class HttpExceptionLike implements Exception {
  HttpExceptionLike(this.statusCode, this.base);
  final int statusCode;
  final String base;

  @override
  String toString() => 'HTTP $statusCode @ $base';
}
