import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../l10n/app_strings.dart';
import '../models/app_settings.dart';
import 'llm_client.dart';
import 'ollama_runtime.dart';

class ImageGenerationResult {
  const ImageGenerationResult({
    required this.bytes,
    this.revisedPrompt,
  });

  final Uint8List bytes;
  final String? revisedPrompt;
}

class ImageGenerationService {
  ImageGenerationService({
    LlmClient? llmClient,
    OllamaRuntime? runtime,
  })  : _llm = llmClient ?? LlmClient(),
        _runtime = runtime ?? OllamaRuntime();

  final LlmClient _llm;
  final OllamaRuntime _runtime;

  Future<ImageGenerationResult> generate({
    required AppSettings settings,
    required String model,
    required String prompt,
    required AppStrings strings,
    String? sourceImageBase64,
    List<String> outputModalities = const [],
    http.Client? client,
  }) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty && sourceImageBase64 == null) {
      throw Exception(strings.promptOrImageRequired);
    }

    final isOllama = settings.provider == LlmProvider.ollama;
    if (isOllama) {
      return _generateOllama(
        settings: settings,
        model: model,
        prompt: trimmed,
        strings: strings,
        sourceImageBase64: sourceImageBase64,
        client: client,
      );
    }
    if (_usesChatImageApi(settings)) {
      return _generateViaChatCompletions(
        settings: settings,
        model: model,
        prompt: trimmed,
        strings: strings,
        sourceImageBase64: sourceImageBase64,
        outputModalities: outputModalities,
        client: client,
      );
    }
    return _generateOpenAiCompatible(
      settings: settings,
      model: model,
      prompt: trimmed,
      strings: strings,
      sourceImageBase64: sourceImageBase64,
      client: client,
    );
  }

  static bool _usesChatImageApi(AppSettings settings) {
    if (settings.provider == LlmProvider.openrouter) return true;
    return settings.apiBaseUrl.toLowerCase().contains('openrouter.ai');
  }

  Future<ImageGenerationResult> _generateOllama({
    required AppSettings settings,
    required String model,
    required String prompt,
    required AppStrings strings,
    String? sourceImageBase64,
    http.Client? client,
  }) async {
    final body = <String, dynamic>{
      'model': model,
      'prompt': prompt.isNotEmpty ? prompt : 'enhance this image',
      'stream': false,
    };
    if (sourceImageBase64 != null && sourceImageBase64.isNotEmpty) {
      body['images'] = [sourceImageBase64];
    }

    final httpClient = client ?? http.Client();
    final ownsClient = client == null;
    try {
      final result = await _runtime.fetchOllama(
        '/api/generate',
        settings,
        method: 'POST',
        body: jsonEncode(body),
        headers: _runtime.jsonAuthHeaders(settings),
        primaryUrl: settings.ollamaUrl,
        timeout: Duration(milliseconds: settings.requestTimeout),
      );

      final data = jsonDecode(result.response.body) as Map<String, dynamic>;
      final images = data['images'] as List?;
      if (images == null || images.isEmpty) {
        final err = data['error'] ?? data['response'] ?? strings.noImageReturned;
        throw Exception(err.toString());
      }

      final b64 = images.first as String;
      return ImageGenerationResult(
        bytes: base64Decode(b64),
        revisedPrompt: data['response'] as String?,
      );
    } finally {
      if (ownsClient) httpClient.close();
    }
  }

  Future<ImageGenerationResult> _generateViaChatCompletions({
    required AppSettings settings,
    required String model,
    required String prompt,
    required AppStrings strings,
    String? sourceImageBase64,
    List<String> outputModalities = const [],
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    final ownsClient = client == null;
    try {
      final base = _llm.baseUrl(settings);
      final headers = _llm.authHeaders(settings);
      final uri = Uri.parse('$base/chat/completions');
      final timeoutMs =
          settings.requestTimeout < 120000 ? 120000 : settings.requestTimeout;

      final modalities = _modalitiesForImageModel(model, outputModalities);
      final effectivePrompt =
          prompt.isNotEmpty ? prompt : 'enhance this image';

      dynamic content;
      if (sourceImageBase64 != null && sourceImageBase64.isNotEmpty) {
        content = [
          if (effectivePrompt.isNotEmpty)
            {'type': 'text', 'text': effectivePrompt},
          {
            'type': 'image_url',
            'image_url': {
              'url': 'data:image/png;base64,$sourceImageBase64',
            },
          },
        ];
      } else {
        content = effectivePrompt;
      }

      final response = await httpClient
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'model': model,
              'messages': [
                {'role': 'user', 'content': content},
              ],
              'modalities': modalities,
              'stream': false,
            }),
          )
          .timeout(Duration(milliseconds: timeoutMs));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          _runtime.formatFetchError(response.statusCode, response.body),
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw Exception(strings.noImageReturned);
      }
      final message =
          (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>?;
      if (message == null) {
        throw Exception(strings.noImageReturned);
      }

      final images = message['images'] as List?;
      if (images == null || images.isEmpty) {
        throw Exception(strings.noImageReturned);
      }

      final imageObj = images.first as Map<String, dynamic>;
      final imageUrl =
          (imageObj['image_url'] as Map<String, dynamic>?)?['url'] as String?;
      if (imageUrl == null || imageUrl.isEmpty) {
        throw Exception(strings.imageFormatUnsupported);
      }

      return ImageGenerationResult(
        bytes: await _decodeImageReference(imageUrl, httpClient, timeoutMs, strings),
        revisedPrompt: message['content'] as String?,
      );
    } finally {
      if (ownsClient) httpClient.close();
    }
  }

  Future<ImageGenerationResult> _generateOpenAiCompatible({
    required AppSettings settings,
    required String model,
    required String prompt,
    required AppStrings strings,
    String? sourceImageBase64,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    final ownsClient = client == null;
    try {
      final base = _llm.baseUrl(settings);
      final headers = _llm.authHeaders(settings);

      if (sourceImageBase64 != null && sourceImageBase64.isNotEmpty) {
        return _generateOpenAiEdit(
          base: base,
          headers: headers,
          model: model,
          prompt: prompt,
          strings: strings,
          sourceImageBase64: sourceImageBase64,
          client: httpClient,
          timeout: settings.requestTimeout,
        );
      }

      final uri = Uri.parse('$base/images/generations');
      final timeoutMs =
          settings.requestTimeout < 120000 ? 120000 : settings.requestTimeout;
      final response = await httpClient
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'model': model,
              'prompt': prompt,
              'n': 1,
              'size': '1024x1024',
              if (!_urlOnlyImageModel(model)) 'response_format': 'b64_json',
            }),
          )
          .timeout(Duration(milliseconds: timeoutMs));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_runtime.formatFetchError(response.statusCode, response.body));
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = data['data'] as List?;
      if (items == null || items.isEmpty) {
        throw Exception(strings.noImageReturned);
      }
      final item = items.first as Map<String, dynamic>;
      final b64 = item['b64_json'] as String?;
      if (b64 != null && b64.isNotEmpty) {
        return ImageGenerationResult(
          bytes: base64Decode(b64),
          revisedPrompt: item['revised_prompt'] as String?,
        );
      }
      final url = item['url'] as String?;
      if (url != null && url.isNotEmpty) {
        final imgRes = await httpClient
            .get(Uri.parse(url))
            .timeout(Duration(milliseconds: timeoutMs));
        if (imgRes.statusCode < 200 || imgRes.statusCode >= 300) {
          throw Exception(strings.imageDownloadFailed);
        }
        return ImageGenerationResult(
          bytes: imgRes.bodyBytes,
          revisedPrompt: item['revised_prompt'] as String?,
        );
      }
      throw Exception(strings.imageFormatUnsupported);
    } finally {
      if (ownsClient) httpClient.close();
    }
  }

  Future<ImageGenerationResult> _generateOpenAiEdit({
    required String base,
    required Map<String, String> headers,
    required String model,
    required String prompt,
    required AppStrings strings,
    required String sourceImageBase64,
    required http.Client client,
    required int timeout,
  }) async {
    final uri = Uri.parse('$base/images/edits');
    final bytes = base64Decode(sourceImageBase64);
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(headers)
      ..fields['model'] = model
      ..fields['prompt'] = prompt.isNotEmpty ? prompt : 'enhance this image'
      ..fields['n'] = '1'
      ..fields['size'] = '1024x1024'
      ..fields['response_format'] = 'b64_json'
      ..files.add(http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: 'source.png',
      ));

    final streamed = await client.send(request).timeout(Duration(milliseconds: timeout));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_runtime.formatFetchError(response.statusCode, response.body));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = data['data'] as List?;
    if (items == null || items.isEmpty) {
      throw Exception(strings.noImageReturned);
    }
    final item = items.first as Map<String, dynamic>;
    final b64 = item['b64_json'] as String?;
    if (b64 == null || b64.isEmpty) {
      throw Exception(strings.imageFormatUnsupported);
    }
    return ImageGenerationResult(
      bytes: base64Decode(b64),
      revisedPrompt: item['revised_prompt'] as String?,
    );
  }

  static List<String> _modalitiesForImageModel(
    String model,
    List<String> outputModalities,
  ) {
    if (outputModalities.contains('text') &&
        outputModalities.contains('image')) {
      return const ['image', 'text'];
    }
    if (outputModalities.contains('image') &&
        !outputModalities.contains('text')) {
      return const ['image'];
    }
    final lower = model.toLowerCase();
    if (RegExp(
      r'flux|dall[-_.]?e|riverflow|mai[-_.]?image|stable[-_.]?diffusion|sdxl|imagen|playground|sourceful|recraft',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return const ['image'];
    }
    return const ['image', 'text'];
  }

  Future<Uint8List> _decodeImageReference(
    String url,
    http.Client client,
    int timeoutMs,
    AppStrings strings,
  ) async {
    if (url.startsWith('data:')) {
      final comma = url.indexOf(',');
      if (comma < 0) throw Exception(strings.imageFormatUnsupported);
      return base64Decode(url.substring(comma + 1));
    }
    final imgRes = await client
        .get(Uri.parse(url))
        .timeout(Duration(milliseconds: timeoutMs));
    if (imgRes.statusCode < 200 || imgRes.statusCode >= 300) {
      throw Exception(strings.imageDownloadFailed);
    }
    return imgRes.bodyBytes;
  }

  static bool _urlOnlyImageModel(String model) {
    final lower = model.toLowerCase();
    return lower.contains('dall-e-3') || lower.contains('dalle-3');
  }
}
