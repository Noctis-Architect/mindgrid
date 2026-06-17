enum LlmProvider { ollama, openai, openrouter, custom }

extension LlmProviderX on LlmProvider {
  String get label => switch (this) {
        LlmProvider.ollama => '🏠 Ollama',
        LlmProvider.openai => '🌐 OpenAI',
        LlmProvider.openrouter => '🔀 OpenRouter',
        LlmProvider.custom => '⚙ Custom',
      };

  static LlmProvider fromString(String? value) {
    return LlmProvider.values.firstWhere(
      (p) => p.name == value,
      orElse: () => LlmProvider.ollama,
    );
  }
}

enum ExtractProvider { same, ollama, openai, openrouter }

extension ExtractProviderX on ExtractProvider {
  static ExtractProvider fromString(String? value) {
    return ExtractProvider.values.firstWhere(
      (p) => p.name == value,
      orElse: () => ExtractProvider.same,
    );
  }
}

class ApiKeyProfile {
  const ApiKeyProfile({
    required this.id,
    required this.name,
    required this.key,
  });

  final String id;
  final String name;
  final String key;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'key': key};

  factory ApiKeyProfile.fromJson(Map<String, dynamic> json) => ApiKeyProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        key: json['key'] as String,
      );
}

class AppSettings {
  const AppSettings({
    this.provider = LlmProvider.ollama,
    this.ollamaUrl = 'http://localhost:11434',
    this.apiBaseUrl = 'https://api.openai.com/v1',
    this.apiKey = '',
    this.apiKeyProfiles = const [],
    this.selectedApiKeyProfileId = '',
    this.selectedModel = '',
    this.temperature = 0.7,
    this.maxTokens = 2048,
    this.contextWindow = 20,
    this.streamingEnabled = true,
    this.thinkEnabled = false,
    this.requestTimeout = 30000,
    this.customHeaders = '{}',
    this.autoExtract = true,
    this.extractModel = '',
    this.extractModelManual = '',
    this.extractProvider = ExtractProvider.same,
    this.extractApiBase = '',
    this.extractApiKey = '',
    this.extractPrompt = '',
  });

  final LlmProvider provider;
  final String ollamaUrl;
  final String apiBaseUrl;
  final String apiKey;
  final List<ApiKeyProfile> apiKeyProfiles;
  final String selectedApiKeyProfileId;
  final String selectedModel;
  final double temperature;
  final int maxTokens;
  final int contextWindow;
  final bool streamingEnabled;
  final bool thinkEnabled;
  final int requestTimeout;
  final String customHeaders;
  final bool autoExtract;
  final String extractModel;
  final String extractModelManual;
  final ExtractProvider extractProvider;
  final String extractApiBase;
  final String extractApiKey;
  final String extractPrompt;

  AppSettings copyWith({
    LlmProvider? provider,
    String? ollamaUrl,
    String? apiBaseUrl,
    String? apiKey,
    List<ApiKeyProfile>? apiKeyProfiles,
    String? selectedApiKeyProfileId,
    String? selectedModel,
    double? temperature,
    int? maxTokens,
    int? contextWindow,
    bool? streamingEnabled,
    bool? thinkEnabled,
    int? requestTimeout,
    String? customHeaders,
    bool? autoExtract,
    String? extractModel,
    String? extractModelManual,
    ExtractProvider? extractProvider,
    String? extractApiBase,
    String? extractApiKey,
    String? extractPrompt,
  }) {
    return AppSettings(
      provider: provider ?? this.provider,
      ollamaUrl: ollamaUrl ?? this.ollamaUrl,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      apiKey: apiKey ?? this.apiKey,
      apiKeyProfiles: apiKeyProfiles ?? this.apiKeyProfiles,
      selectedApiKeyProfileId:
          selectedApiKeyProfileId ?? this.selectedApiKeyProfileId,
      selectedModel: selectedModel ?? this.selectedModel,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      contextWindow: contextWindow ?? this.contextWindow,
      streamingEnabled: streamingEnabled ?? this.streamingEnabled,
      thinkEnabled: thinkEnabled ?? this.thinkEnabled,
      requestTimeout: requestTimeout ?? this.requestTimeout,
      customHeaders: customHeaders ?? this.customHeaders,
      autoExtract: autoExtract ?? this.autoExtract,
      extractModel: extractModel ?? this.extractModel,
      extractModelManual: extractModelManual ?? this.extractModelManual,
      extractProvider: extractProvider ?? this.extractProvider,
      extractApiBase: extractApiBase ?? this.extractApiBase,
      extractApiKey: extractApiKey ?? this.extractApiKey,
      extractPrompt: extractPrompt ?? this.extractPrompt,
    );
  }

  Map<String, dynamic> toMap() => {
        'provider': provider.name,
        'ollamaUrl': ollamaUrl,
        'apiBaseUrl': apiBaseUrl,
        'apiKey': apiKey,
        'apiKeyProfiles': apiKeyProfiles.map((p) => p.toJson()).toList(),
        'selectedApiKeyProfileId': selectedApiKeyProfileId,
        'selectedModel': selectedModel,
        'temperature': temperature,
        'maxTokens': maxTokens,
        'contextWindow': contextWindow,
        'streamingEnabled': streamingEnabled,
        'thinkEnabled': thinkEnabled,
        'requestTimeout': requestTimeout,
        'customHeaders': customHeaders,
        'autoExtract': autoExtract,
        'extractModel': extractModel,
        'extractModelManual': extractModelManual,
        'extractProvider': extractProvider.name,
        'extractApiBase': extractApiBase,
        'extractApiKey': extractApiKey,
        'extractPrompt': extractPrompt,
      };

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    final profilesRaw = map['apiKeyProfiles'];
    final profiles = profilesRaw is List
        ? profilesRaw
            .whereType<Map>()
            .map((e) => ApiKeyProfile.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <ApiKeyProfile>[];

    return AppSettings(
      provider: LlmProviderX.fromString(map['provider'] as String?),
      ollamaUrl: map['ollamaUrl'] as String? ?? 'http://localhost:11434',
      apiBaseUrl:
          map['apiBaseUrl'] as String? ?? 'https://api.openai.com/v1',
      apiKey: map['apiKey'] as String? ?? '',
      apiKeyProfiles: profiles,
      selectedApiKeyProfileId:
          map['selectedApiKeyProfileId'] as String? ?? '',
      selectedModel: map['selectedModel'] as String? ?? '',
      temperature: (map['temperature'] as num?)?.toDouble() ?? 0.7,
      maxTokens: (map['maxTokens'] as num?)?.toInt() ?? 2048,
      contextWindow: (map['contextWindow'] as num?)?.toInt() ?? 20,
      streamingEnabled: map['streamingEnabled'] as bool? ?? true,
      thinkEnabled: map['thinkEnabled'] as bool? ?? false,
      requestTimeout: (map['requestTimeout'] as num?)?.toInt() ?? 30000,
      customHeaders: map['customHeaders'] as String? ?? '{}',
      autoExtract: map['autoExtract'] as bool? ?? true,
      extractModel: map['extractModel'] as String? ?? '',
      extractModelManual: map['extractModelManual'] as String? ?? '',
      extractProvider:
          ExtractProviderX.fromString(map['extractProvider'] as String?),
      extractApiBase: map['extractApiBase'] as String? ?? '',
      extractApiKey: map['extractApiKey'] as String? ?? '',
      extractPrompt: map['extractPrompt'] as String? ?? '',
    );
  }
}
