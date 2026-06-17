import '../l10n/app_strings.dart';
import '../models/app_settings.dart';
import '../models/chat_models.dart';
import '../models/prompt_config.dart';

class PromptBuilder {
  String applyVariables(String text, List<PromptVariable> variables) {
    var result = text;
    for (final v in variables) {
      if (v.key.isEmpty) continue;
      result = result.replaceAll('{{${v.key}}}', v.value);
    }
    return result;
  }

  String buildSystemPrompt({
    required PromptConfig config,
    required String userInfo,
    required AppStrings strings,
  }) {
    final parts = <String>[];
    final raw = applyVariables(config.systemPrompt.trim(), config.variables);
    if (raw.isNotEmpty) parts.add(raw);

    if (config.injectDateTime) {
      final now = DateTime.now();
      parts.add(
        strings.dateTimeLabel(now.toLocal().toString().split('.').first),
      );
    }

    if (config.injectUserInfo && userInfo.trim().isNotEmpty) {
      parts.add(strings.userInfoLabel(userInfo.trim()));
    }

    return parts.join('\n\n');
  }

  List<Map<String, dynamic>> buildMessages({
    required PromptConfig config,
    required String userInfo,
    required List<ChatMessage> chatMessages,
    required AppSettings settings,
    required AppStrings strings,
  }) {
    final msgs = <Map<String, dynamic>>[];
    final sys = buildSystemPrompt(
      config: config,
      userInfo: userInfo,
      strings: strings,
    );
    if (sys.isNotEmpty) {
      msgs.add({'role': 'system', 'content': sys});
    }

    if (config.injectHistory && chatMessages.isNotEmpty) {
      final ctx = settings.contextWindow;
      final slice = chatMessages.length > ctx
          ? chatMessages.sublist(chatMessages.length - ctx)
          : chatMessages;
      for (final m in slice) {
        if (m.role == 'assistant' &&
            m.thinking != null &&
            m.thinking!.isNotEmpty &&
            settings.thinkEnabled) {
          msgs.add({
            'role': m.role,
            'content': m.content,
            'thinking': m.thinking,
          });
        } else {
          msgs.add({'role': m.role, 'content': m.content});
        }
      }
    }
    return msgs;
  }

  Map<String, dynamic> buildPayload({
    required PromptConfig config,
    required String userInfo,
    required List<ChatMessage> chatMessages,
    required AppSettings settings,
    required String model,
    required AppStrings strings,
  }) {
    return {
      'model': model,
      'messages': buildMessages(
        config: config,
        userInfo: userInfo,
        chatMessages: chatMessages,
        settings: settings,
        strings: strings,
      ),
      'stream': settings.streamingEnabled,
      'temperature': settings.temperature,
      'max_tokens': settings.maxTokens,
    };
  }
}
