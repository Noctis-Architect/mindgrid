import 'gguf_reader.dart';

/// A chat format preset: everything Ollama needs besides the weights to run a
/// model the same way its own library builds do.
class ChatProfile {
  const ChatProfile({
    required this.id,
    required this.label,
    this.template,
    this.renderer,
    this.parser,
    this.stops = const [],
    this.parameters = const {},
    this.thinking = false,
    this.tools = false,
    this.minOllama,
  });

  final String id;
  final String label;

  /// Go template; null lets Ollama derive one from the GGUF itself.
  final String? template;

  /// Built-in Ollama renderer/parser pair (newer architectures).
  final String? renderer;
  final String? parser;
  final List<String> stops;
  final Map<String, num> parameters;
  final bool thinking;
  final bool tools;
  final String? minOllama;
}

/// Fully resolved import configuration — the app's equivalent of a Modelfile.
class ModelfileSpec {
  ModelfileSpec({
    required this.name,
    required this.profileId,
    this.template,
    this.renderer,
    this.parser,
    this.system = '',
    List<String>? stops,
    Map<String, num>? parameters,
    this.license,
  })  : stops = stops ?? [],
        parameters = parameters ?? {};

  String name;
  String profileId;
  String? template;
  String? renderer;
  String? parser;
  String system;
  List<String> stops;
  Map<String, num> parameters;
  String? license;

  ModelfileSpec copy() => ModelfileSpec(
        name: name,
        profileId: profileId,
        template: template,
        renderer: renderer,
        parser: parser,
        system: system,
        stops: [...stops],
        parameters: {...parameters},
        license: license,
      );

  /// Body for `POST /api/create`.
  Map<String, dynamic> toCreateJson({
    required String fileName,
    required String digest,
  }) {
    final params = <String, dynamic>{...parameters};
    if (stops.isNotEmpty) params['stop'] = stops;
    return {
      'model': name,
      'files': {fileName: digest},
      if (template != null && template!.trim().isNotEmpty)
        'template': template,
      if (renderer != null && renderer!.trim().isNotEmpty)
        'renderer': renderer!.trim(),
      if (parser != null && parser!.trim().isNotEmpty) 'parser': parser!.trim(),
      if (system.trim().isNotEmpty) 'system': system.trim(),
      if (params.isNotEmpty) 'parameters': params,
      if (license != null && license!.trim().isNotEmpty) 'license': license,
      'stream': true,
    };
  }

  /// Equivalent Modelfile text, for preview and copy.
  String toModelfile({String from = './model.gguf'}) {
    final b = StringBuffer()..writeln('FROM $from');
    if (template != null && template!.trim().isNotEmpty) {
      b.writeln('TEMPLATE """${template!}"""');
    }
    if (renderer != null && renderer!.trim().isNotEmpty) {
      b.writeln('RENDERER ${renderer!.trim()}');
    }
    if (parser != null && parser!.trim().isNotEmpty) {
      b.writeln('PARSER ${parser!.trim()}');
    }
    if (system.trim().isNotEmpty) {
      b.writeln('SYSTEM """${system.trim()}"""');
    }
    final keys = parameters.keys.toList()..sort();
    for (final k in keys) {
      b.writeln('PARAMETER $k ${_fmtNum(parameters[k]!)}');
    }
    for (final s in stops) {
      b.writeln('PARAMETER stop ${_quoteStop(s)}');
    }
    if (license != null && license!.trim().isNotEmpty) {
      b.writeln('LICENSE """${license!.trim()}"""');
    }
    return b.toString().trimRight();
  }

  static String _fmtNum(num v) {
    if (v is int || v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  static String _quoteStop(String s) {
    if (s.contains(' ') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\n', '\\n')}"';
    }
    return s;
  }
}

class ProfileDetection {
  const ProfileDetection(this.profile, {required this.confident, this.reason});
  final ChatProfile profile;
  final bool confident;
  final String? reason;
}

class ModelTemplates {
  ModelTemplates._();

  static const autoId = 'auto';

  // ── Go templates ──────────────────────────────────────────────────────────
  // All templates read the system prompt from `.System` and skip system-role
  // entries in `.Messages`, matching how Ollama collates conversations. They
  // support assistant prefill: a trailing assistant message is left open.

  static const _toolsBlock = r'''
{{- if .Tools }}

# Tools

You may call one or more functions to assist with the user query.

You are provided with function signatures within <tools></tools> XML tags:
<tools>
{{- range .Tools }}
{"type": "function", "function": {{ .Function }}}
{{- end }}
</tools>

For each function call, return a json object with function name and arguments within <tool_call></tool_call> XML tags:
<tool_call>
{"name": <function-name>, "arguments": <args-json-object>}
</tool_call>
{{- end }}''';

  static const _chatml = '''
{{- if or .System .Tools }}<|im_start|>system
{{- if .System }}
{{ .System }}
{{- end }}$_toolsBlock<|im_end|>
{{ end }}
{{- range \$i, \$_ := .Messages }}
{{- \$last := eq (len (slice \$.Messages \$i)) 1 -}}
{{- if eq .Role "user" }}<|im_start|>user
{{ .Content }}<|im_end|>
{{ else if eq .Role "assistant" }}<|im_start|>assistant
{{ if .Content }}{{ .Content }}
{{- else if .ToolCalls }}<tool_call>
{{ range .ToolCalls }}{"name": "{{ .Function.Name }}", "arguments": {{ .Function.Arguments }}}
{{ end }}</tool_call>
{{- end }}{{ if not \$last }}<|im_end|>
{{ end }}
{{- else if eq .Role "tool" }}<|im_start|>user
<tool_response>
{{ .Content }}
</tool_response><|im_end|>
{{ end }}
{{- if and (ne .Role "assistant") \$last }}<|im_start|>assistant
{{ end }}
{{- end }}''';

  static const _chatmlThink = '''
{{- if or .System .Tools }}<|im_start|>system
{{- if .System }}
{{ .System }}
{{- end }}$_toolsBlock<|im_end|>
{{ end }}
{{- range \$i, \$_ := .Messages }}
{{- \$last := eq (len (slice \$.Messages \$i)) 1 -}}
{{- if eq .Role "user" }}<|im_start|>user
{{ .Content }}<|im_end|>
{{ else if eq .Role "assistant" }}<|im_start|>assistant
{{ if and .Thinking \$last -}}
<think>{{ .Thinking }}</think>
{{ end -}}
{{ if .Content }}{{ .Content }}
{{- else if .ToolCalls }}<tool_call>
{{ range .ToolCalls }}{"name": "{{ .Function.Name }}", "arguments": {{ .Function.Arguments }}}
{{ end }}</tool_call>
{{- end }}{{ if not \$last }}<|im_end|>
{{ end }}
{{- else if eq .Role "tool" }}<|im_start|>user
<tool_response>
{{ .Content }}
</tool_response><|im_end|>
{{ end }}
{{- if and (ne .Role "assistant") \$last }}<|im_start|>assistant
{{ if and \$.IsThinkSet (not \$.Think) -}}
<think>

</think>

{{ end -}}
{{ end }}
{{- end }}''';

  static const _llama3 = r'''
{{- if .System }}<|start_header_id|>system<|end_header_id|>

{{ .System }}<|eot_id|>
{{- end }}
{{- range $i, $_ := .Messages }}
{{- $last := eq (len (slice $.Messages $i)) 1 }}
{{- if eq .Role "user" }}<|start_header_id|>user<|end_header_id|>

{{ .Content }}<|eot_id|>
{{- else if eq .Role "assistant" }}<|start_header_id|>assistant<|end_header_id|>

{{ .Content }}{{ if not $last }}<|eot_id|>{{ end }}
{{- else if eq .Role "tool" }}<|start_header_id|>ipython<|end_header_id|>

{{ .Content }}<|eot_id|>
{{- end }}
{{- if and $last (ne .Role "assistant") }}<|start_header_id|>assistant<|end_header_id|>

{{ end }}
{{- end }}''';

  static const _gemma = r'''
{{- $system := .System }}
{{- range $i, $_ := .Messages }}
{{- $last := eq (len (slice $.Messages $i)) 1 }}
{{- if eq .Role "user" }}<start_of_turn>user
{{ if $system }}{{ $system }}

{{ end }}{{ $system = "" }}{{ .Content }}<end_of_turn>
{{ if $last }}<start_of_turn>model
{{ end }}
{{- else if eq .Role "assistant" }}<start_of_turn>model
{{ .Content }}{{ if not $last }}<end_of_turn>
{{ end }}
{{- end }}
{{- end }}''';

  static const _mistral = r'''
{{- $system := .System }}
{{- range $i, $_ := .Messages }}
{{- if eq .Role "user" }}[INST] {{ if $system }}{{ $system }}

{{ end }}{{ $system = "" }}{{ .Content }} [/INST]
{{- else if eq .Role "assistant" }} {{ .Content }}{{ if ne (len (slice $.Messages $i)) 1 }}</s>{{ end }}
{{- end }}
{{- end }}''';

  static const _llama2 = r'''
{{- $system := .System }}
{{- range $i, $_ := .Messages }}
{{- if eq .Role "user" }}[INST] {{ if $system }}<<SYS>>
{{ $system }}
<</SYS>>

{{ end }}{{ $system = "" }}{{ .Content }} [/INST]
{{- else if eq .Role "assistant" }} {{ .Content }}{{ if ne (len (slice $.Messages $i)) 1 }} </s><s>{{ end }}
{{- end }}
{{- end }}''';

  static const _phi3 = r'''
{{- if .System }}<|system|>
{{ .System }}<|end|>
{{ end }}
{{- range $i, $_ := .Messages }}
{{- $last := eq (len (slice $.Messages $i)) 1 }}
{{- if eq .Role "user" }}<|user|>
{{ .Content }}<|end|>
{{ if $last }}<|assistant|>
{{ end }}
{{- else if eq .Role "assistant" }}<|assistant|>
{{ .Content }}{{ if not $last }}<|end|>
{{ end }}
{{- end }}
{{- end }}''';

  static const _phi4 = r'''
{{- if .System }}<|im_start|>system<|im_sep|>{{ .System }}<|im_end|>{{ end }}
{{- range $i, $_ := .Messages }}
{{- $last := eq (len (slice $.Messages $i)) 1 }}
{{- if eq .Role "user" }}<|im_start|>user<|im_sep|>{{ .Content }}<|im_end|>
{{- if $last }}<|im_start|>assistant<|im_sep|>{{ end }}
{{- else if eq .Role "assistant" }}<|im_start|>assistant<|im_sep|>{{ .Content }}{{ if not $last }}<|im_end|>{{ end }}
{{- end }}
{{- end }}''';

  static const _deepseek = r'''
{{- if .System }}{{ .System }}{{ end }}
{{- range $i, $_ := .Messages }}
{{- $last := eq (len (slice $.Messages $i)) 1 }}
{{- if eq .Role "user" }}<｜User｜>{{ .Content }}
{{- else if eq .Role "assistant" }}<｜Assistant｜>
{{- if and .Thinking $last }}<think>{{ .Thinking }}</think>{{ end }}
{{- .Content }}{{ if not $last }}<｜end▁of▁sentence｜>{{ end }}
{{- end }}
{{- if and $last (ne .Role "assistant") }}<｜Assistant｜>
{{- if and $.IsThinkSet (not $.Think) }}<think>

</think>

{{ end }}
{{- end }}
{{- end }}''';

  static const _zephyr = r'''
{{- if .System }}<|system|>
{{ .System }}</s>
{{ end }}
{{- range $i, $_ := .Messages }}
{{- $last := eq (len (slice $.Messages $i)) 1 }}
{{- if eq .Role "user" }}<|user|>
{{ .Content }}</s>
{{ if $last }}<|assistant|>
{{ end }}
{{- else if eq .Role "assistant" }}<|assistant|>
{{ .Content }}{{ if not $last }}</s>
{{ end }}
{{- end }}
{{- end }}''';

  static const _alpaca = r'''
{{- if .System }}{{ .System }}

{{ end }}
{{- range $i, $_ := .Messages }}
{{- $last := eq (len (slice $.Messages $i)) 1 }}
{{- if eq .Role "user" }}### Instruction:
{{ .Content }}

{{ if $last }}### Response:
{{ end }}
{{- else if eq .Role "assistant" }}### Response:
{{ .Content }}{{ if not $last }}

{{ end }}
{{- end }}
{{- end }}''';

  static const _vicuna = r'''
{{- if .System }}{{ .System }}

{{ end }}
{{- range $i, $_ := .Messages }}
{{- $last := eq (len (slice $.Messages $i)) 1 }}
{{- if eq .Role "user" }}USER: {{ .Content }}
{{ if $last }}ASSISTANT:{{ end }}
{{- else if eq .Role "assistant" }}ASSISTANT: {{ .Content }}{{ if not $last }}</s>
{{ end }}
{{- end }}
{{- end }}''';

  static const _granite = r'''
{{- if .System }}<|start_of_role|>system<|end_of_role|>{{ .System }}<|end_of_text|>
{{ end }}
{{- range $i, $_ := .Messages }}
{{- $last := eq (len (slice $.Messages $i)) 1 }}
{{- if eq .Role "user" }}<|start_of_role|>user<|end_of_role|>{{ .Content }}<|end_of_text|>
{{ if $last }}<|start_of_role|>assistant<|end_of_role|>{{ end }}
{{- else if eq .Role "assistant" }}<|start_of_role|>assistant<|end_of_role|>{{ .Content }}{{ if not $last }}<|end_of_text|>
{{ end }}
{{- end }}
{{- end }}''';

  static const _commandR = r'''
{{- if .System }}<|START_OF_TURN_TOKEN|><|SYSTEM_TOKEN|>{{ .System }}<|END_OF_TURN_TOKEN|>{{ end }}
{{- range $i, $_ := .Messages }}
{{- $last := eq (len (slice $.Messages $i)) 1 }}
{{- if eq .Role "user" }}<|START_OF_TURN_TOKEN|><|USER_TOKEN|>{{ .Content }}<|END_OF_TURN_TOKEN|>
{{- if $last }}<|START_OF_TURN_TOKEN|><|CHATBOT_TOKEN|>{{ end }}
{{- else if eq .Role "assistant" }}<|START_OF_TURN_TOKEN|><|CHATBOT_TOKEN|>{{ .Content }}{{ if not $last }}<|END_OF_TURN_TOKEN|>{{ end }}
{{- end }}
{{- end }}''';

  static final List<ChatProfile> profiles = [
    const ChatProfile(
      id: autoId,
      label: 'Auto (let Ollama read the GGUF chat template)',
    ),
    ChatProfile(
      id: 'chatml',
      label: 'ChatML — Qwen, Hermes, Dolphin, SmolLM, Yi',
      template: _chatml.trimLeft(),
      stops: const ['<|im_start|>', '<|im_end|>', '<|endoftext|>'],
      tools: true,
    ),
    ChatProfile(
      id: 'chatml-think',
      label: 'ChatML + reasoning — Qwen3, QwQ, <think> finetunes',
      template: _chatmlThink.trimLeft(),
      stops: const ['<|im_start|>', '<|im_end|>', '<|endoftext|>'],
      parameters: const {
        'temperature': 0.6,
        'top_k': 20,
        'top_p': 0.95,
        'repeat_penalty': 1,
      },
      thinking: true,
      tools: true,
    ),
    ChatProfile(
      id: 'llama3',
      label: 'Llama 3 / 3.1 / 3.2 / 3.3',
      template: _llama3.trimLeft(),
      stops: const ['<|start_header_id|>', '<|end_header_id|>', '<|eot_id|>'],
    ),
    const ChatProfile(
      id: 'gemma4',
      label: 'Gemma 4 — native Ollama renderer',
      renderer: 'gemma4',
      parser: 'gemma4',
      parameters: {'temperature': 1, 'top_k': 64, 'top_p': 0.95},
      thinking: true,
      tools: true,
      minOllama: '0.20.0',
    ),
    ChatProfile(
      id: 'gemma',
      label: 'Gemma 2 / 3 / 3n',
      template: _gemma.trimLeft(),
      stops: const ['<end_of_turn>'],
      parameters: const {'temperature': 1, 'top_k': 64, 'top_p': 0.95},
    ),
    ChatProfile(
      id: 'deepseek',
      label: 'DeepSeek R1 / V3 (reasoning)',
      template: _deepseek.trimLeft(),
      stops: const [
        '<｜begin▁of▁sentence｜>',
        '<｜end▁of▁sentence｜>',
        '<｜User｜>',
        '<｜Assistant｜>',
      ],
      parameters: const {'temperature': 0.6},
      thinking: true,
    ),
    ChatProfile(
      id: 'mistral',
      label: 'Mistral / Mixtral — [INST]',
      template: _mistral.trimLeft(),
      stops: const ['[INST]', '[/INST]'],
    ),
    ChatProfile(
      id: 'llama2',
      label: 'Llama 2 / CodeLlama — [INST] <<SYS>>',
      template: _llama2.trimLeft(),
      stops: const ['[INST]', '[/INST]', '<<SYS>>', '<</SYS>>'],
    ),
    ChatProfile(
      id: 'phi3',
      label: 'Phi-3 / Phi-3.5',
      template: _phi3.trimLeft(),
      stops: const ['<|end|>', '<|user|>', '<|assistant|>', '<|system|>'],
    ),
    ChatProfile(
      id: 'phi4',
      label: 'Phi-4',
      template: _phi4.trimLeft(),
      stops: const ['<|im_start|>', '<|im_end|>', '<|im_sep|>'],
    ),
    ChatProfile(
      id: 'zephyr',
      label: 'Zephyr / TinyLlama / StableLM',
      template: _zephyr.trimLeft(),
      stops: const ['<|system|>', '<|user|>', '<|assistant|>', '</s>'],
    ),
    ChatProfile(
      id: 'granite',
      label: 'IBM Granite',
      template: _granite.trimLeft(),
      stops: const ['<|start_of_role|>', '<|end_of_role|>', '<|end_of_text|>'],
    ),
    ChatProfile(
      id: 'command-r',
      label: 'Cohere Command-R / Aya',
      template: _commandR.trimLeft(),
      stops: const ['<|START_OF_TURN_TOKEN|>', '<|END_OF_TURN_TOKEN|>'],
    ),
    ChatProfile(
      id: 'alpaca',
      label: 'Alpaca — ### Instruction',
      template: _alpaca.trimLeft(),
      stops: const ['### Instruction:', '### Response:'],
    ),
    ChatProfile(
      id: 'vicuna',
      label: 'Vicuna — USER / ASSISTANT',
      template: _vicuna.trimLeft(),
      stops: const ['USER:', 'ASSISTANT:', '</s>'],
    ),
  ];

  static ChatProfile byId(String id) =>
      profiles.firstWhere((p) => p.id == id, orElse: () => profiles.first);

  /// Picks the chat format for a GGUF: architecture first, then the embedded
  /// Jinja chat template, then vocabulary control tokens, then the file name.
  static ProfileDetection detect(GgufMetadata? meta, {String fileName = ''}) {
    ProfileDetection hit(String id, String reason, {bool confident = true}) =>
        ProfileDetection(byId(id), confident: confident, reason: reason);

    final arch = meta?.architecture?.toLowerCase() ?? '';
    final tpl = meta?.chatTemplate ?? '';
    final tokens = meta?.specialTokens ?? const <String>{};
    final hint = [
      fileName,
      meta?.name ?? '',
      meta?.basename ?? '',
      meta?.baseModelName ?? '',
    ].join(' ').toLowerCase();

    if (arch == 'gemma4' || tpl.contains('<|turn>')) {
      return hit('gemma4', 'architecture gemma4');
    }

    bool has(String marker) => tpl.contains(marker);
    final thinks = has('<think>') ||
        has('enable_thinking') ||
        has('reasoning_content') ||
        tokens.contains('<think>');

    if (tpl.isNotEmpty) {
      const via = 'embedded chat template';
      if (has('<start_of_turn>')) return hit('gemma', via);
      if (has('<|start_header_id|>')) return hit('llama3', via);
      if (has('<｜User｜>') || has('<｜Assistant｜>')) return hit('deepseek', via);
      if (has('<|im_sep|>')) return hit('phi4', via);
      if (has('<|im_start|>')) {
        return hit(thinks ? 'chatml-think' : 'chatml', via);
      }
      if (has('<|start_of_role|>')) return hit('granite', via);
      if (has('<|START_OF_TURN_TOKEN|>')) return hit('command-r', via);
      if (has('<|start|>') && has('<|channel|>')) {
        return hit(autoId, 'Harmony format — handled natively by Ollama');
      }
      if (has('<|user|>') && has('<|end|>')) return hit('phi3', via);
      if (has('<|user|>')) return hit('zephyr', via);
      if (has('<<SYS>>')) return hit('llama2', via);
      if (has('[INST]')) return hit('mistral', via);
      if (has('### Instruction')) return hit('alpaca', via);
      if (has('USER:') && has('ASSISTANT:')) return hit('vicuna', via);
    }

    if (tokens.isNotEmpty) {
      const via = 'vocabulary control tokens';
      if (tokens.contains('<|turn>')) return hit('gemma4', via);
      if (tokens.contains('<start_of_turn>')) return hit('gemma', via);
      if (tokens.contains('<|start_header_id|>')) return hit('llama3', via);
      if (tokens.contains('<｜User｜>')) return hit('deepseek', via);
      if (tokens.contains('<|im_sep|>')) return hit('phi4', via);
      if (tokens.contains('<|im_start|>')) {
        return hit(thinks ? 'chatml-think' : 'chatml', via);
      }
      if (tokens.contains('<|start_of_role|>')) return hit('granite', via);
      if (tokens.contains('<|START_OF_TURN_TOKEN|>')) {
        return hit('command-r', via);
      }
      if (tokens.contains('<|end|>') && tokens.contains('<|user|>')) {
        return hit('phi3', via);
      }
    }

    const via = 'model name';
    bool named(String pattern) => RegExp(pattern).hasMatch(hint);
    if (named(r'gemma[-_ ]?4')) return hit('gemma4', via, confident: false);
    if (named(r'gemma')) return hit('gemma', via, confident: false);
    if (named(r'deepseek[-_ ]?r1')) return hit('deepseek', via, confident: false);
    if (named(r'qwen[-_ ]?3|qwq')) return hit('chatml-think', via, confident: false);
    if (named(r'llama[-_ ]?3')) return hit('llama3', via, confident: false);
    if (named(r'phi[-_ ]?4')) return hit('phi4', via, confident: false);
    if (named(r'phi[-_ ]?3')) return hit('phi3', via, confident: false);
    if (named(r'qwen|hermes|dolphin|smollm|chatml|yi-')) {
      return hit('chatml', via, confident: false);
    }
    if (named(r'mistral|mixtral')) return hit('mistral', via, confident: false);
    if (named(r'zephyr|tinyllama')) return hit('zephyr', via, confident: false);

    return const ProfileDetection(
      ChatProfile(
        id: autoId,
        label: 'Auto (let Ollama read the GGUF chat template)',
      ),
      confident: false,
    );
  }

  /// Builds the default import spec for a file.
  static ModelfileSpec buildSpec({
    required String name,
    required ChatProfile profile,
    GgufMetadata? meta,
    String system = '',
  }) {
    final stops = [...profile.stops];
    final eot = meta?.eotToken;
    if (profile.template != null &&
        eot != null &&
        eot.startsWith('<') &&
        eot.endsWith('>') &&
        !stops.contains(eot)) {
      stops.add(eot);
    }
    return ModelfileSpec(
      name: name,
      profileId: profile.id,
      template: profile.template,
      renderer: profile.renderer,
      parser: profile.parser,
      system: system,
      stops: stops,
      parameters: {...profile.parameters},
      license: meta?.license,
    );
  }

  /// Parses the Modelfile text returned by `/api/show` so an installed model
  /// can be used as the configuration source for a new import.
  static ModelfileSpec fromModelfileText(String text, {required String name}) {
    final spec = ModelfileSpec(name: name, profileId: 'installed');
    final lines = text.split('\n');
    var i = 0;

    String readValue(String first) {
      var v = first.trim();
      if (v.startsWith('"""')) {
        final buf = StringBuffer();
        var rest = v.substring(3);
        while (true) {
          final end = rest.indexOf('"""');
          if (end >= 0) {
            buf.write(rest.substring(0, end));
            break;
          }
          buf.writeln(rest);
          i++;
          if (i >= lines.length) break;
          rest = lines[i];
        }
        return buf.toString();
      }
      if (v.startsWith('"')) {
        final buf = StringBuffer();
        var rest = v.substring(1);
        while (true) {
          final end = _closingQuote(rest);
          if (end >= 0) {
            buf.write(rest.substring(0, end));
            break;
          }
          buf.writeln(rest);
          i++;
          if (i >= lines.length) break;
          rest = lines[i];
        }
        return buf
            .toString()
            .replaceAll(r'\"', '"')
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\\', r'\');
      }
      return v;
    }

    for (; i < lines.length; i++) {
      final line = lines[i];
      final m = RegExp(r'^\s*([A-Za-z]+)\s+(.*)$').firstMatch(line);
      if (m == null || line.trimLeft().startsWith('#')) continue;
      final cmd = m.group(1)!.toUpperCase();
      final rest = m.group(2)!;
      switch (cmd) {
        case 'TEMPLATE':
          spec.template = readValue(rest);
        case 'SYSTEM':
          spec.system = readValue(rest).trim();
        case 'RENDERER':
          spec.renderer = rest.trim();
        case 'PARSER':
          spec.parser = rest.trim();
        case 'LICENSE':
          readValue(rest); // skipped: belongs to the source model
        case 'PARAMETER':
          final pm = RegExp(r'^(\S+)\s+(.*)$').firstMatch(rest.trim());
          if (pm == null) break;
          final key = pm.group(1)!;
          final value = readValue(pm.group(2)!);
          if (key == 'stop') {
            if (value.isNotEmpty) spec.stops.add(value);
          } else {
            final n = num.tryParse(value.trim());
            if (n != null) spec.parameters[key] = n;
          }
      }
    }

    // A bare passthrough template with a renderer means "renderer only".
    if (spec.renderer != null &&
        spec.renderer!.isNotEmpty &&
        spec.template?.trim() == '{{ .Prompt }}') {
      spec.template = null;
    }
    return spec;
  }

  static int _closingQuote(String s) {
    for (var i = 0; i < s.length; i++) {
      if (s[i] == r'\') {
        i++;
        continue;
      }
      if (s[i] == '"') return i;
    }
    return -1;
  }
}

/// Ollama-style `name:tag` handling.
class ModelNaming {
  ModelNaming._();

  static final _valid = RegExp(
    r'^[a-z0-9][a-z0-9._-]*(/[a-z0-9][a-z0-9._-]*)?(:[a-z0-9][a-z0-9._-]*)?$',
  );

  static bool isValid(String name) =>
      name.length <= 120 && _valid.hasMatch(name);

  static String slug(String input) {
    var s = input.toLowerCase().trim();
    s = s.replaceAll(RegExp(r'[\s/\\]+'), '-');
    s = s.replaceAll(RegExp(r'[^a-z0-9._-]'), '');
    s = s.replaceAll(RegExp(r'-{2,}'), '-');
    s = s.replaceAll(RegExp(r'^[._-]+|[._-]+$'), '');
    return s;
  }

  static final _quantRe = RegExp(
    r'(?:^|[-._])((?:i?q\d+(?:_[a-z0-9]+)*)|f16|f32|bf16|fp16)(?=$|[-._])',
    caseSensitive: false,
  );
  static final _sizeRe = RegExp(
    r'(?:^|[-._])(\d+(?:\.\d+)?[bm]|e\d+b)(?=$|[-._])',
    caseSensitive: false,
  );

  /// Quantization label found in a file name, e.g. `Q4_K_M`.
  static String? quantFromFileName(String fileName) {
    final base = fileName.replaceAll(RegExp(r'\.gguf$', caseSensitive: false), '');
    final matches = _quantRe.allMatches(base).toList();
    return matches.isEmpty ? null : matches.last.group(1)!.toUpperCase();
  }

  /// Suggests `family-variant:size-quant` the way Ollama library tags read.
  static String suggest({GgufMetadata? meta, required String fileName}) {
    var stem = fileName
        .split(RegExp(r'[/\\]'))
        .last
        .replaceAll(RegExp(r'\.gguf$', caseSensitive: false), '');

    final quant =
        (meta?.quantization ?? quantFromFileName(stem))?.toLowerCase();
    var size = meta?.sizeLabel?.toLowerCase();

    // Strip quant from the stem so it only appears in the tag.
    final qm = _quantRe.allMatches(stem).toList();
    if (qm.isNotEmpty) {
      stem = stem.substring(0, qm.last.start) + stem.substring(qm.last.end);
    }

    var base = meta?.basename ?? '';
    if (base.isEmpty) {
      base = stem;
      final sm = _sizeRe.firstMatch(base);
      if (sm != null) {
        size ??= sm.group(1)!.toLowerCase();
        base = base.substring(0, sm.start) + base.substring(sm.end);
      }
    }
    base = slug(base);
    if (base.isEmpty) base = slug(stem);
    if (base.isEmpty) base = 'model';

    final fine = meta?.finetune == null ? '' : slug(meta!.finetune!);
    final tagParts = <String>[
      if (size != null && size.isNotEmpty) slug(size),
      if (fine.isNotEmpty && fine.length <= 24 && !base.contains(fine)) fine,
      if (quant != null && quant.isNotEmpty) slug(quant),
    ];
    final tag = tagParts.isEmpty ? 'latest' : tagParts.join('-');
    return '$base:$tag';
  }
}
