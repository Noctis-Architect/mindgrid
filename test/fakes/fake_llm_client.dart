import 'dart:async';

import 'package:mindgrid/models/app_settings.dart';
import 'package:mindgrid/models/chat_models.dart';
import 'package:mindgrid/services/llm_client.dart';

class FakeLlmClient extends LlmClient {
  FakeLlmClient({
    this.models = const [LlmModel('test-model')],
    this.chunks = const [StreamChunk(content: 'سلام دنیا')],
    this.fetchError,
    this.streamError,
    this.delay = Duration.zero,
  });

  List<LlmModel> models;
  List<StreamChunk> chunks;
  final Object? fetchError;
  final Object? streamError;
  final Duration delay;

  String? lastResolvedBase;
  List<Map<String, dynamic>>? lastApiMessages;
  Map<String, dynamic>? lastPayload;

  @override
  Future<FetchModelsResult> fetchModels(
    AppSettings settings, {
    bool scanNetwork = true,
  }) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (fetchError != null) throw fetchError!;
    return FetchModelsResult(
      models: models,
      resolvedOllamaBase: settings.ollamaUrl,
    );
  }

  @override
  Stream<StreamChunk> streamChat({
    required AppSettings settings,
    required Map<String, dynamic> payload,
    String? editedPayloadJson,
    required List<Map<String, dynamic>> apiMessages,
    bool injectHistory = true,
    client,
    bool disableThink = false,
    void Function(String base)? onOllamaBaseResolved,
  }) async* {
    lastPayload = payload;
    lastApiMessages = apiMessages;
    if (streamError != null) throw streamError!;
    for (var i = 0; i < chunks.length; i++) {
      if (i > 0 && delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      yield chunks[i];
    }
    onOllamaBaseResolved?.call('http://127.0.0.1:11434');
  }
}
