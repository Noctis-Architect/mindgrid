import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindgrid/services/gguf_reader.dart';
import 'package:mindgrid/services/hf_service.dart';
import 'package:mindgrid/services/model_templates.dart';

/// Builds a tiny but valid GGUF v3 header (no tensors).
Uint8List buildGguf({
  String arch = 'qwen2',
  String? chatTemplate,
  List<String> tokens = const ['<unk>', '<|im_start|>', '<|im_end|>'],
  int fileType = 15,
}) {
  final b = BytesBuilder();
  void u32(int v) => b.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void u64(int v) => b.add((ByteData(8)..setUint64(0, v, Endian.little)).buffer.asUint8List());
  void str(String s) {
    final bytes = utf8.encode(s);
    u64(bytes.length);
    b.add(bytes);
  }

  final kvs = <void Function()>[
    () { str('general.architecture'); u32(8); str(arch); },
    () { str('general.name'); u32(8); str('Test Model'); },
    () { str('general.basename'); u32(8); str('Test-Model'); },
    () { str('general.size_label'); u32(8); str('7B'); },
    () { str('general.file_type'); u32(4); u32(fileType); },
    () { str('$arch.context_length'); u32(4); u32(32768); },
    () {
      str('tokenizer.ggml.tokens'); u32(9); u32(8); u64(tokens.length);
      tokens.forEach(str);
    },
    () {
      str('tokenizer.ggml.scores'); u32(9); u32(6); u64(tokens.length);
      for (var i = 0; i < tokens.length; i++) { u32(0); }
    },
    () { str('tokenizer.ggml.eos_token_id'); u32(4); u32(tokens.length - 1); },
    if (chatTemplate != null)
      () { str('tokenizer.chat_template'); u32(8); str(chatTemplate); },
  ];

  b.add(utf8.encode('GGUF'));
  u32(3);
  u64(0);
  u64(kvs.length);
  for (final kv in kvs) {
    kv();
  }
  return b.toBytes();
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('mg_gguf'));
  tearDown(() => tmp.deleteSync(recursive: true));

  File write(String name, Uint8List bytes) =>
      File('${tmp.path}/$name')..writeAsBytesSync(bytes);

  group('GgufReader', () {
    test('reads metadata, tokens and derived fields', () {
      final f = write('m.gguf', buildGguf(chatTemplate: '<|im_start|>x'));
      final meta = GgufReader.readSync(f.path);
      expect(meta.version, 3);
      expect(meta.architecture, 'qwen2');
      expect(meta.sizeLabel, '7B');
      expect(meta.quantization, 'Q4_K_M');
      expect(meta.contextLength, 32768);
      expect(meta.chatTemplate, '<|im_start|>x');
      expect(meta.eosToken, '<|im_end|>');
      expect(meta.specialTokens, containsAll(['<|im_start|>', '<|im_end|>']));
      expect(meta.vocabSize, 3);
    });

    test('rejects non-GGUF files', () {
      final f = write('x.gguf', Uint8List.fromList(utf8.encode('not a model')));
      expect(
        () => GgufReader.readSync(f.path),
        throwsA(isA<GgufFormatException>()
            .having((e) => e.truncated, 'truncated', isFalse)),
      );
    });

    test('flags a truncated header so partial downloads can fetch more', () {
      final bytes = buildGguf(chatTemplate: 'x' * 500);
      final f = write('p.gguf', Uint8List.sublistView(bytes, 0, bytes.length - 100));
      expect(
        () => GgufReader.readSync(f.path),
        throwsA(isA<GgufFormatException>()
            .having((e) => e.truncated, 'truncated', isTrue)),
      );
    });
  });

  group('ModelTemplates.detect', () {
    GgufMetadata meta({
      String arch = 'llama',
      String? tpl,
      List<String> tokens = const ['<unk>', '</s>'],
    }) {
      final f = write(
        'd.gguf',
        buildGguf(arch: arch, chatTemplate: tpl, tokens: tokens),
      );
      return GgufReader.readSync(f.path);
    }

    test('maps embedded chat templates to formats', () {
      final cases = {
        '<|im_start|>user': 'chatml',
        '<|im_start|>assistant\n<think>': 'chatml-think',
        '<start_of_turn>user': 'gemma',
        '<|start_header_id|>user<|end_header_id|>': 'llama3',
        '<｜User｜>hi<｜Assistant｜>': 'deepseek',
        '<|im_start|>user<|im_sep|>': 'phi4',
        '<|user|>\nhi<|end|>': 'phi3',
        '[INST] <<SYS>>': 'llama2',
        '[INST] hi [/INST]': 'mistral',
        '<|start_of_role|>user': 'granite',
      };
      cases.forEach((tpl, id) {
        final d = ModelTemplates.detect(meta(tpl: tpl));
        expect(d.profile.id, id, reason: tpl);
        expect(d.confident, isTrue);
      });
    });

    test('gemma4 architecture uses the native renderer', () {
      final d = ModelTemplates.detect(meta(arch: 'gemma4'));
      expect(d.profile.id, 'gemma4');
      expect(d.profile.renderer, 'gemma4');
      expect(d.profile.template, isNull);
    });

    test('falls back to vocabulary tokens, then to auto', () {
      final byTokens = ModelTemplates.detect(
        meta(tokens: ['<unk>', '<|im_start|>', '<|im_end|>']),
      );
      expect(byTokens.profile.id, 'chatml');

      final unknown = ModelTemplates.detect(meta(), fileName: 'mystery.gguf');
      expect(unknown.profile.id, ModelTemplates.autoId);
      expect(unknown.confident, isFalse);
    });
  });

  group('ModelfileSpec', () {
    test('create payload carries template, stops and parameters', () {
      final spec = ModelTemplates.buildSpec(
        name: 'qwen:7b-q4_k_m',
        profile: ModelTemplates.byId('chatml-think'),
        system: 'Be brief.',
      );
      final json = spec.toCreateJson(fileName: 'm.gguf', digest: 'sha256:abc');
      expect(json['model'], 'qwen:7b-q4_k_m');
      expect(json['files'], {'m.gguf': 'sha256:abc'});
      expect(json['template'], contains('<think>'));
      expect(json['system'], 'Be brief.');
      expect((json['parameters'] as Map)['stop'], contains('<|im_end|>'));
      expect((json['parameters'] as Map)['temperature'], 0.6);
      expect(json.containsKey('renderer'), isFalse);
    });

    test('round-trips an `ollama show` modelfile', () {
      const text = '''
# Modelfile generated by "ollama show"
FROM /usr/share/ollama/blobs/sha256-abc
TEMPLATE {{ .Prompt }}
SYSTEM "
You are helpful.
"
RENDERER gemma4
PARSER gemma4
PARAMETER temperature 0.72
PARAMETER top_k 40
PARAMETER stop <turn|>
PARAMETER stop "a b"
LICENSE """Apache
PARAMETER stop not-a-real-stop
"""
''';
      final spec = ModelTemplates.fromModelfileText(text, name: 'x:y');
      expect(spec.renderer, 'gemma4');
      expect(spec.parser, 'gemma4');
      expect(spec.template, isNull);
      expect(spec.system, 'You are helpful.');
      expect(spec.parameters, {'temperature': 0.72, 'top_k': 40});
      expect(spec.stops, ['<turn|>', 'a b']);
    });

    test('multi-line TEMPLATE blocks are preserved', () {
      const text = 'FROM x\nTEMPLATE """{{ if .System }}<s>\n{{ .System }}{{ end }}"""\nPARAMETER stop </s>\n';
      final spec = ModelTemplates.fromModelfileText(text, name: 'x');
      expect(spec.template, '{{ if .System }}<s>\n{{ .System }}{{ end }}');
      expect(spec.stops, ['</s>']);
    });
  });

  group('ModelNaming', () {
    test('suggests ollama-style name:tag', () {
      expect(
        ModelNaming.suggest(fileName: 'Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf'),
        'qwen2.5-coder-instruct:7b-q4_k_m',
      );
      expect(
        ModelNaming.suggest(fileName: 'mystery.gguf'),
        'mystery:latest',
      );
      final meta = GgufReader.readSync(write('n.gguf', buildGguf()).path);
      expect(
        ModelNaming.suggest(meta: meta, fileName: 'whatever-Q8_0.gguf'),
        'test-model:7b-q4_k_m',
      );
    });

    test('validates names', () {
      expect(ModelNaming.isValid('gemma3:4b-it-q4_k_m'), isTrue);
      expect(ModelNaming.isValid('user/model:latest'), isTrue);
      expect(ModelNaming.isValid('Bad Name'), isFalse);
      expect(ModelNaming.isValid(':tag'), isFalse);
      expect(ModelNaming.isValid(''), isFalse);
    });
  });

  group('HfRef.parse', () {
    test('accepts the common link shapes', () {
      final a = HfRef.parse('https://huggingface.co/bartowski/Foo-GGUF')!;
      expect(a.repo, 'bartowski/Foo-GGUF');
      expect(a.filePath, isNull);

      final b = HfRef.parse(
        'https://huggingface.co/bartowski/Foo-GGUF/resolve/main/sub/Foo-Q4_K_M.gguf?download=true',
      )!;
      expect(b.repo, 'bartowski/Foo-GGUF');
      expect(b.revision, 'main');
      expect(b.filePath, 'sub/Foo-Q4_K_M.gguf');

      final c = HfRef.parse('https://hf.co/a/b/blob/dev/x.gguf')!;
      expect(c.revision, 'dev');
      expect(c.filePath, 'x.gguf');

      final d = HfRef.parse('hf.co/bartowski/Foo-GGUF:Q4_K_M')!;
      expect(d.repo, 'bartowski/Foo-GGUF');
      expect(d.quantHint, 'Q4_K_M');

      expect(HfRef.parse('owner/repo')!.repo, 'owner/repo');
      expect(HfRef.parse('ollama run hf.co/o/r:Q8_0')!.quantHint, 'Q8_0');
      expect(HfRef.parse('just-a-word'), isNull);
      expect(HfRef.parse(''), isNull);
    });

    test('classifies files', () {
      const split = HfFile(path: 'm-00001-of-00003.gguf', size: 1);
      const proj = HfFile(path: 'mmproj-model-f16.gguf', size: 1);
      const plain = HfFile(path: 'dir/Model-7B.IQ4_XS.gguf', size: 1);
      expect(split.isSplit, isTrue);
      expect(proj.isProjector, isTrue);
      expect(plain.isSplit, isFalse);
      expect(plain.quant, 'IQ4_XS');
      expect(plain.name, 'Model-7B.IQ4_XS.gguf');
    });
  });
}
