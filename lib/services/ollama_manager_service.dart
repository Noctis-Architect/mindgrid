import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../l10n/app_strings.dart';
import '../models/app_settings.dart';
import '../models/ollama_models.dart';
import 'local_http_client.dart';
import 'ollama_runtime.dart';

class OllamaManagerService {
  OllamaManagerService({OllamaRuntime? runtime})
      : _runtime = runtime ?? OllamaRuntime();

  final OllamaRuntime _runtime;

  static const libraryUrl = 'https://ollama.com/api/tags';
  static const libraryPageUrl = 'https://ollama.com/library';
  static const windowsDownloadUrl =
      'https://github.com/ollama/ollama/releases/latest';
  static const linuxInstallCmd =
      'curl -fsSL https://ollama.com/install.sh | sh';

  static const fallbackLibrary = [
    'llama3.2',
    'llama3.2:1b',
    'llama3.2:3b',
    'gemma3:4b',
    'gemma3:12b',
    'qwen2.5:7b',
    'qwen2.5:14b',
    'deepseek-r1:7b',
    'deepseek-r1:14b',
    'mistral',
    'phi3:mini',
    'codellama',
    'nomic-embed-text',
  ];

  bool get isDesktopLinux => !kIsWeb && Platform.isLinux;
  bool get isDesktopWindows => !kIsWeb && Platform.isWindows;
  bool get canAutoInstall => isDesktopLinux;

  Future<bool> isBinaryInstalled() async {
    if (kIsWeb) return false;
    try {
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        ['ollama'],
        runInShell: Platform.isWindows,
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isApiReachable([String base = 'http://127.0.0.1:11434']) async {
    try {
      final client = createClientForBase(base);
      try {
        final res = await client
            .get(Uri.parse('${base.replaceAll(RegExp(r'/+$'), '')}/api/tags'))
            .timeout(const Duration(seconds: 3));
        return res.statusCode >= 200 && res.statusCode < 300;
      } finally {
        client.close();
      }
    } catch (_) {
      return false;
    }
  }

  Future<bool> isSystemdServiceActive() async {
    if (!isDesktopLinux) return false;
    try {
      final result = await Process.run('systemctl', ['is-active', 'ollama']);
      return result.exitCode == 0 &&
          result.stdout.toString().trim() == 'active';
    } catch (_) {
      return false;
    }
  }

  Future<OllamaLocalStatus> checkLocalStatus() async {
    if (kIsWeb) return OllamaLocalStatus.unsupported;
    if (await isApiReachable()) return OllamaLocalStatus.running;
    if (await isBinaryInstalled()) {
      return OllamaLocalStatus.installedNotRunning;
    }
    return OllamaLocalStatus.notInstalled;
  }

  Future<bool> isConfiguredReachable(AppSettings settings) async {
    final base = settings.ollamaUrl.replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) return false;
    return isApiReachable(base);
  }

  Future<OllamaLocalStatus> checkConnection(AppSettings settings) async {
    if (await isConfiguredReachable(settings)) {
      return OllamaLocalStatus.running;
    }
    return checkLocalStatus();
  }

  Future<OllamaInstallResult> installOnLinux({
    required AppStrings s,
    void Function(String line)? onLog,
  }) async {
    if (!isDesktopLinux) {
      return OllamaInstallResult(
        success: false,
        message: s.installLinuxOnly,
      );
    }

    onLog?.call(s.downloadingOllama);
    final pkexec = await _commandExists('pkexec');
    final ProcessResult result;
    if (pkexec) {
      result = await Process.run(
        'pkexec',
        ['bash', '-c', linuxInstallCmd],
        runInShell: false,
      );
    } else {
      result = await Process.run(
        'bash',
        ['-c', linuxInstallCmd],
        runInShell: true,
      );
    }

    final out = '${result.stdout}\n${result.stderr}'.trim();
    if (out.isNotEmpty) onLog?.call(out);

    if (result.exitCode != 0) {
      return OllamaInstallResult(
        success: false,
        message: out.isNotEmpty ? out : s.installFailed(result.exitCode),
      );
    }

    onLog?.call(s.installComplete);
    final service = await enableSystemdService(s: s, onLog: onLog);
    if (!service.success) {
      await startOllamaServe(s: s, onLog: onLog);
    }

    final reachable = await _waitForApi();
    return OllamaInstallResult(
      success: reachable,
      message: reachable ? s.ollamaRunning : s.installDoneApiUnavailable,
    );
  }

  Future<OllamaServiceResult> enableSystemdService({
    required AppStrings s,
    void Function(String line)? onLog,
  }) async {
    if (!isDesktopLinux) {
      return OllamaServiceResult(
        success: false,
        message: s.installLinuxOnly,
      );
    }

    onLog?.call(s.enablingOllamaService);
    final pkexec = await _commandExists('pkexec');
    final args = ['enable', '--now', 'ollama'];
    final ProcessResult result;
    if (pkexec) {
      result = await Process.run('pkexec', ['systemctl', ...args]);
    } else {
      result = await Process.run('systemctl', args, runInShell: true);
    }

    final out = '${result.stdout}\n${result.stderr}'.trim();
    if (out.isNotEmpty) onLog?.call(out);

    if (result.exitCode == 0) {
      return OllamaServiceResult(
        success: true,
        message: s.ollamaServiceEnabled,
      );
    }

    return OllamaServiceResult(
      success: false,
      message: out.isNotEmpty ? out : s.serviceEnableFailed,
    );
  }

  Future<OllamaServiceResult> startOllamaServe({
    required AppStrings s,
    void Function(String line)? onLog,
  }) async {
    if (kIsWeb) {
      return OllamaServiceResult(
        success: false,
        message: s.localRunWebUnsupported,
      );
    }

    if (!await isBinaryInstalled()) {
      return OllamaServiceResult(
        success: false,
        message: s.ollamaCommandNotFound,
      );
    }

    onLog?.call(s.runningOllamaServe);
    try {
      await Process.start(
        'ollama',
        ['serve'],
        mode: ProcessStartMode.detached,
      );
      final reachable = await _waitForApi();
      return OllamaServiceResult(
        success: reachable,
        message: reachable ? s.ollamaRunning : s.processStartedWait,
      );
    } catch (e) {
      return OllamaServiceResult(success: false, message: '$e');
    }
  }

  Future<List<OllamaLibraryModel>> fetchLibraryModels() async {
    try {
      final res = await http
          .get(Uri.parse(libraryUrl))
          .timeout(const Duration(seconds: 20));
      if (!res.statusCode.toString().startsWith('2')) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final json = jsonDecode(res.body);
      if (json is! Map || json['models'] is! List) {
        throw Exception('Invalid library response');
      }
      final models = (json['models'] as List)
          .whereType<Map>()
          .map((m) => OllamaLibraryModel.fromJson(Map<String, dynamic>.from(m)))
          .where((m) => m.name.isNotEmpty)
          .toList();
      models.sort((a, b) => a.name.compareTo(b.name));
      if (models.isNotEmpty) return models;
    } catch (_) {}

    return fallbackLibrary
        .map((name) => OllamaLibraryModel(name: name))
        .toList();
  }

  Future<List<OllamaModelFamily>> fetchLibraryFamilies() async {
    final featured = await fetchLibraryModels();
    final featuredByBase = <String, List<OllamaModelVariant>>{};
    for (final m in featured) {
      final base = m.baseName;
      featuredByBase.putIfAbsent(base, () => []);
      final tag = m.name.contains(':') ? m.name.split(':').skip(1).join(':') : 'latest';
      featuredByBase[base]!.add(
        OllamaTagParser.parse(base, tag, sizeBytes: m.size),
      );
    }

    try {
      final res = await http
          .get(Uri.parse(libraryPageUrl))
          .timeout(const Duration(seconds: 30));
      if (!res.statusCode.toString().startsWith('2')) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final names = _parseLibraryPageNames(res.body);
      if (names.isEmpty) throw Exception('Empty library page');

      final families = names
          .map(
            (name) => OllamaModelFamily(
              name: name,
              featuredVariants: featuredByBase[name] ?? const [],
            ),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return families;
    } catch (_) {
      return featuredByBase.entries
          .map(
            (e) => OllamaModelFamily(
              name: e.key,
              featuredVariants: e.value,
            ),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    }
  }

  Future<List<OllamaModelVariant>> fetchModelVariants(String familyName) async {
    try {
      final url = '$libraryPageUrl/$familyName/tags';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (!res.statusCode.toString().startsWith('2')) {
        throw Exception('HTTP ${res.statusCode}');
      }
      return _parseVariantTagsPage(res.body, familyName);
    } catch (_) {
      return fallbackLibrary
          .where((n) => n.startsWith('$familyName:'))
          .map((n) {
            final tag = n.substring(familyName.length + 1);
            return OllamaTagParser.parse(familyName, tag);
          })
          .toList();
    }
  }

  static List<String> _parseLibraryPageNames(String html) {
    final re = RegExp(r'href="/library/([^"/:]+)"');
    final seen = <String>{};
    final names = <String>[];
    for (final m in re.allMatches(html)) {
      final name = m.group(1)!;
      if (seen.add(name)) names.add(name);
    }
    return names;
  }

  static List<OllamaModelVariant> _parseVariantTagsPage(
    String html,
    String familyName,
  ) {
    final tagRe = RegExp(
      'href="/library/${RegExp.escape(familyName)}:([^"]+)"',
    );
    final sizeRe = RegExp(r'([\d.]+)\s*(GB|MB|KB|TB)', caseSensitive: false);

    final tagOrder = <String>[];
    final tagSizes = <String, int>{};

    for (final m in tagRe.allMatches(html)) {
      final tag = m.group(1)!;
      if (!tagOrder.contains(tag)) tagOrder.add(tag);

      final chunk = html.substring(
        m.start,
        (m.start + 1200).clamp(0, html.length),
      );
      final sizeMatch = sizeRe.firstMatch(chunk);
      if (sizeMatch != null && !tagSizes.containsKey(tag)) {
        tagSizes[tag] = _parseHumanSize(
          sizeMatch.group(1)!,
          sizeMatch.group(2)!.toUpperCase(),
        );
      }
    }

    return tagOrder
        .map(
          (tag) => OllamaTagParser.parse(
            familyName,
            tag,
            sizeBytes: tagSizes[tag],
          ),
        )
        .toList();
  }

  static int _parseHumanSize(String value, String unit) {
    final n = double.tryParse(value) ?? 0;
    final mult = switch (unit) {
      'TB' => 1024 * 1024 * 1024 * 1024,
      'GB' => 1024 * 1024 * 1024,
      'MB' => 1024 * 1024,
      'KB' => 1024,
      _ => 1,
    };
    return (n * mult).round();
  }

  Future<Set<String>> fetchInstalledModelNames(AppSettings settings) async {
    try {
      final result = await _runtime.fetchOllama(
        '/api/tags',
        settings,
        method: 'GET',
        primaryUrl: settings.ollamaUrl,
      );
      final json = jsonDecode(result.response.body);
      if (json is! Map || json['models'] is! List) return {};
      return (json['models'] as List)
          .whereType<Map>()
          .map((m) => m['name']?.toString() ?? m['model']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  Stream<OllamaPullProgress> pullModel(
    String model,
    AppSettings settings, {
    String? primaryUrl,
  }) {
    return startPull(model, settings, primaryUrl: primaryUrl).stream;
  }

  OllamaPullSession startPull(
    String model,
    AppSettings settings, {
    String? primaryUrl,
  }) {
    late final StreamController<OllamaPullProgress> controller;
    http.Client? activeClient;
    var aborted = false;

    void cancel() {
      aborted = true;
      activeClient?.close();
      if (!controller.isClosed) {
        controller.close();
      }
    }

    controller = StreamController<OllamaPullProgress>(
      onCancel: cancel,
    );

    Future<void> run() async {
      final bases = await _runtime.listOllamaBases(
        primaryUrl ?? settings.ollamaUrl,
      );
      Object? lastErr;

      for (final base in bases) {
        if (aborted) return;
        try {
          await for (final progress in _pullOnBase(
            base,
            model,
            settings,
            onClient: (client) => activeClient = client,
            isAborted: () => aborted,
          )) {
            if (aborted) return;
            controller.add(progress);
            if (progress.done) {
              if (progress.error == null || progress.error!.isEmpty) {
                _runtime.rememberReachableBase(base);
              }
              await controller.close();
              return;
            }
          }
          await controller.close();
          return;
        } catch (e) {
          lastErr = e;
        }
      }

      if (!controller.isClosed) {
        controller.add(
          OllamaPullProgress(
            model: model,
            done: true,
            error: lastErr?.toString() ?? 'Ollama unreachable',
          ),
        );
        await controller.close();
      }
    }

    unawaited(run());

    return OllamaPullSession(stream: controller.stream, cancel: cancel);
  }

  Stream<OllamaPullProgress> _pullOnBase(
    String base,
    String model,
    AppSettings settings, {
    void Function(http.Client client)? onClient,
    bool Function()? isAborted,
  }) async* {
    final uri = Uri.parse('${base.replaceAll(RegExp(r'/+$'), '')}/api/pull');
    final client = createClientForBase(base);
    onClient?.call(client);
    var lineBuf = '';
    int? lastCompleted;
    int? lastTotal;
    try {
      yield OllamaPullProgress(
        model: model,
        status: 'pulling manifest',
      );

      final request = http.Request('POST', uri)
        ..headers.addAll(_runtime.jsonAuthHeaders(settings))
        ..body = jsonEncode({'name': model, 'stream': true});

      final response =
          await client.send(request).timeout(const Duration(hours: 6));
      if (!response.statusCode.toString().startsWith('2')) {
        final body = await response.stream.bytesToString();
        yield OllamaPullProgress(
          model: model,
          done: true,
          error: _runtime.formatFetchError(response.statusCode, body),
        );
        return;
      }

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        if (isAborted?.call() == true) return;
        lineBuf += chunk;
        final lines = lineBuf.split('\n');
        lineBuf = lines.removeLast();

        for (final line in lines) {
          final json = _decodePullLine(line);
          if (json == null) continue;
          final progress = OllamaPullProgress.fromPullJson(
            json,
            model: model,
            lastCompleted: lastCompleted,
            lastTotal: lastTotal,
          );
          if (progress.completed != null) lastCompleted = progress.completed;
          if (progress.total != null) lastTotal = progress.total;

          yield progress;

          if (progress.error != null && progress.error!.isNotEmpty) return;
          if (progress.done) return;
        }
      }

      if (lineBuf.trim().isNotEmpty) {
        final json = _decodePullLine(lineBuf);
        if (json != null) {
          final progress = OllamaPullProgress.fromPullJson(
            json,
            model: model,
            lastCompleted: lastCompleted,
            lastTotal: lastTotal,
          );
          yield progress;
          if (progress.done ||
              (progress.error != null && progress.error!.isNotEmpty)) {
            return;
          }
        }
      }

      yield OllamaPullProgress(model: model, done: true, status: 'success');
    } finally {
      client.close();
    }
  }

  Map<String, dynamic>? _decodePullLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;
    try {
      final json = jsonDecode(trimmed);
      if (json is Map<String, dynamic>) return json;
      if (json is Map) return Map<String, dynamic>.from(json);
    } catch (_) {}
    return null;
  }

  Future<void> deleteModel(String model, AppSettings settings) async {
    await _runtime.fetchOllama(
      '/api/delete',
      settings,
      method: 'DELETE',
      body: jsonEncode({'name': model}),
      primaryUrl: settings.ollamaUrl,
    );
  }

  Future<bool> _waitForApi({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await isApiReachable()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    return false;
  }

  Future<bool> _commandExists(String command) async {
    try {
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        [command],
        runInShell: Platform.isWindows,
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
