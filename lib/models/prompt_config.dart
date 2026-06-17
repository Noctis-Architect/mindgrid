class PromptVariable {
  const PromptVariable({required this.key, required this.value});
  final String key;
  final String value;

  Map<String, dynamic> toJson() => {'key': key, 'value': value};

  factory PromptVariable.fromJson(Map<String, dynamic> json) => PromptVariable(
        key: json['key'] as String? ?? '',
        value: json['value'] as String? ?? '',
      );
}

class PromptConfig {
  const PromptConfig({
    this.systemPrompt = '',
    this.variables = const [],
    this.injectUserInfo = true,
    this.injectHistory = true,
    this.injectDateTime = false,
  });

  final String systemPrompt;
  final List<PromptVariable> variables;
  final bool injectUserInfo;
  final bool injectHistory;
  final bool injectDateTime;

  PromptConfig copyWith({
    String? systemPrompt,
    List<PromptVariable>? variables,
    bool? injectUserInfo,
    bool? injectHistory,
    bool? injectDateTime,
  }) {
    return PromptConfig(
      systemPrompt: systemPrompt ?? this.systemPrompt,
      variables: variables ?? this.variables,
      injectUserInfo: injectUserInfo ?? this.injectUserInfo,
      injectHistory: injectHistory ?? this.injectHistory,
      injectDateTime: injectDateTime ?? this.injectDateTime,
    );
  }

  Map<String, dynamic> toJson() => {
        'systemPrompt': systemPrompt,
        'variables': variables.map((v) => v.toJson()).toList(),
        'injectUserInfo': injectUserInfo,
        'injectHistory': injectHistory,
        'injectDateTime': injectDateTime,
      };

  factory PromptConfig.fromJson(Map<String, dynamic> json) {
    final varsRaw = json['variables'];
    final vars = varsRaw is List
        ? varsRaw
            .whereType<Map>()
            .map((e) => PromptVariable.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <PromptVariable>[];

    return PromptConfig(
      systemPrompt: json['systemPrompt'] as String? ?? '',
      variables: vars,
      injectUserInfo: json['injectUserInfo'] as bool? ?? true,
      injectHistory: json['injectHistory'] as bool? ?? true,
      injectDateTime: json['injectDateTime'] as bool? ?? false,
    );
  }
}
