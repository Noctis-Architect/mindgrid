import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_http_client.dart';

enum WhisperMode { local, remote }

enum WhisperStatus { stopped, starting, running, error }

/// A downloadable whisper.cpp model (ggml format).
class WhisperCatalogModel {
  const WhisperCatalogModel(this.id, this.approxMb, {this.multilingual = true});

  /// e.g. `base`, `small-q5_1`, `large-v3-turbo`.
  final String id;
  final int approxMb;
  final bool multilingual;

  String get fileName => 'ggml-$id.bin';
}

class WhisperLocalModel {
  const WhisperLocalModel({required this.path, required this.size});
  final String path;
  final int size;

  String get fileName => p.basename(path);

  String get label => fileName
      .replaceFirst(RegExp(r'^ggml-'), '')
      .replaceFirst(RegExp(r'\.bin$'), '');
}

class WhisperException implements Exception {
  WhisperException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Local speech-to-text through whisper.cpp.
///
/// On desktop the app runs whisper.cpp's `whisper-server` as a child process
/// with the selected model loaded and talks to it over loopback HTTP. On any
/// platform (including Android) it can instead use a whisper.cpp server
/// running elsewhere on the network.
class WhisperService extends ChangeNotifier {
  static const repo = 'ggerganov/whisper.cpp';

  static const catalog = <WhisperCatalogModel>[
    WhisperCatalogModel('tiny', 75),
    WhisperCatalogModel('tiny-q5_1', 31),
    WhisperCatalogModel('base', 142),
    WhisperCatalogModel('base-q5_1', 57),
    WhisperCatalogModel('small', 466),
    WhisperCatalogModel('small-q5_1', 181),
    WhisperCatalogModel('medium', 1500),
    WhisperCatalogModel('medium-q5_0', 514),
    WhisperCatalogModel('large-v3-turbo', 1600),
    WhisperCatalogModel('large-v3-turbo-q5_0', 547),
    WhisperCatalogModel('large-v3', 2900),
    WhisperCatalogModel('large-v3-q5_0', 1100),
  ];

  /// Whisper language codes offered in the UI (`auto` detects).
  static const languages = <String, String>{
    'auto': 'Auto-detect',
    'fa': 'فارسی',
    'en': 'English',
    'ar': 'العربية',
    'tr': 'Türkçe',
    'de': 'Deutsch',
    'fr': 'Français',
    'es': 'Español',
    'ru': 'Русский',
    'zh': '中文',
    'ja': '日本語',
    'ko': '한국어',
    'hi': 'हिन्दी',
    'ur': 'اردو',
    'it': 'Italiano',
    'pt': 'Português',
  };

  // ── Persisted settings ────────────────────────────────────────────────────
  WhisperMode mode = WhisperMode.local;
  String remoteUrl = '';
  String binaryPath = '';
  String modelPath = '';
  String language = 'auto';
  bool translate = false;
  int threads = 4;
  bool dictation = true;
  List<String> externalModels = [];

  // ── Runtime state ─────────────────────────────────────────────────────────
  WhisperStatus status = WhisperStatus.stopped;
  String? error;
  String? resolvedBinary;
  List<WhisperLocalModel> models = [];
  bool loaded = false;

  Process? _process;
  int _port = 0;
  String? _runningModel;
  final List<String> _logTail = [];
  bool _disposed = false;

  bool get supportsLocalEngine =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  WhisperMode get effectiveMode =>
      supportsLocalEngine ? mode : WhisperMode.remote;

  String get _remoteBase => remoteUrl.trim().replaceAll(RegExp(r'/+$'), '');

  /// True when a transcription request can be served (possibly after an
  /// automatic engine start).
  bool get canTranscribe {
    if (effectiveMode == WhisperMode.remote) return _remoteBase.isNotEmpty;
    return resolvedBinary != null &&
        modelPath.isNotEmpty &&
        File(modelPath).existsSync();
  }

  /// Whether the chat microphone should dictate through whisper.
  bool get dictationReady => dictation && canTranscribe;

  String? get runningModel => _runningModel;
  String get logTail => _logTail.join('\n');

  // ── Init / persistence ────────────────────────────────────────────────────

  Future<void> load() async {
    if (loaded) return;
    final prefs = await SharedPreferences.getInstance();
    mode = prefs.getString('whisper_mode') == 'remote'
        ? WhisperMode.remote
        : WhisperMode.local;
    remoteUrl = prefs.getString('whisper_remote_url') ?? '';
    binaryPath = prefs.getString('whisper_binary') ?? '';
    modelPath = prefs.getString('whisper_model') ?? '';
    language = prefs.getString('whisper_language') ?? 'auto';
    translate = prefs.getBool('whisper_translate') ?? false;
    threads = prefs.getInt('whisper_threads') ??
        (Platform.numberOfProcessors ~/ 2).clamp(1, 8);
    dictation = prefs.getBool('whisper_dictation') ?? true;
    externalModels = prefs.getStringList('whisper_external_models') ?? [];
    loaded = true;
    await _reapStaleEngine(prefs);
    await refresh();
  }

  /// Kills an engine left behind by a previous run that did not exit cleanly.
  Future<void> _reapStaleEngine(SharedPreferences prefs) async {
    final pid = prefs.getInt('whisper_pid');
    if (pid == null || !supportsLocalEngine) return;
    await prefs.remove('whisper_pid');
    try {
      if (Platform.isWindows) {
        final r = await Process.run(
          'tasklist',
          ['/FI', 'PID eq $pid', '/FO', 'CSV', '/NH'],
        );
        if (r.stdout.toString().toLowerCase().contains('whisper')) {
          Process.killPid(pid);
        }
      } else {
        final r = await Process.run('ps', ['-p', '$pid', '-o', 'command=']);
        if (r.exitCode == 0 && r.stdout.toString().contains('whisper')) {
          Process.killPid(pid);
        }
      }
    } catch (_) {}
  }

  Future<void> _rememberPid(int? pid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (pid == null) {
        await prefs.remove('whisper_pid');
      } else {
        await prefs.setInt('whisper_pid', pid);
      }
    } catch (_) {}
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('whisper_mode', mode.name);
    await prefs.setString('whisper_remote_url', remoteUrl.trim());
    await prefs.setString('whisper_binary', binaryPath.trim());
    await prefs.setString('whisper_model', modelPath);
    await prefs.setString('whisper_language', language);
    await prefs.setBool('whisper_translate', translate);
    await prefs.setInt('whisper_threads', threads);
    await prefs.setBool('whisper_dictation', dictation);
    await prefs.setStringList('whisper_external_models', externalModels);
    _notify();
  }

  static Future<Directory> modelsDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'whisper'));
    await dir.create(recursive: true);
    return dir;
  }

  /// Rescans installed models and re-resolves the engine binary.
  Future<void> refresh() async {
    final found = <WhisperLocalModel>[];
    try {
      final dir = await modelsDir();
      await for (final e in dir.list()) {
        if (e is File && e.path.toLowerCase().endsWith('.bin')) {
          found.add(WhisperLocalModel(path: e.path, size: await e.length()));
        }
      }
    } catch (_) {}
    final stillThere = <String>[];
    for (final path in externalModels) {
      final f = File(path);
      if (await f.exists()) {
        stillThere.add(path);
        if (!found.any((m) => m.path == path)) {
          found.add(WhisperLocalModel(path: path, size: await f.length()));
        }
      }
    }
    externalModels = stillThere;
    found.sort((a, b) => a.fileName.compareTo(b.fileName));
    models = found;
    if (modelPath.isNotEmpty && !found.any((m) => m.path == modelPath)) {
      modelPath = '';
    }
    if (modelPath.isEmpty && found.isNotEmpty) modelPath = found.first.path;
    resolvedBinary = supportsLocalEngine ? await _findBinary() : null;
    _notify();
  }

  Future<void> addExternalModel(String path) async {
    if (!externalModels.contains(path)) externalModels.add(path);
    modelPath = path;
    await save();
    await refresh();
  }

  Future<void> removeModel(WhisperLocalModel model) async {
    if (_runningModel == model.path) await stop();
    if (externalModels.remove(model.path)) {
      // External files are only unlinked from the app, never deleted.
    } else {
      try {
        await File(model.path).delete();
      } catch (_) {}
    }
    if (modelPath == model.path) modelPath = '';
    await save();
    await refresh();
  }

  Future<void> selectModel(String path) async {
    if (modelPath == path) return;
    modelPath = path;
    await save();
    if (status == WhisperStatus.running || status == WhisperStatus.starting) {
      await stop();
      await start();
    }
  }

  // ── Engine binary ─────────────────────────────────────────────────────────

  static List<String> get _binaryNames => Platform.isWindows
      ? const ['whisper-server.exe', 'server.exe']
      : const ['whisper-server', 'whisper-cpp-server'];

  Future<String?> _findBinary() async {
    final custom = binaryPath.trim();
    if (custom.isNotEmpty && await File(custom).exists()) return custom;

    // Bundled next to the app (release packages ship it there).
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final bundled = <String>[
      p.join(exeDir, 'whisper'),
      p.join(exeDir, 'lib', 'whisper'),
      p.join(exeDir, '..', 'Resources', 'whisper'),
      exeDir,
    ];
    for (final dir in bundled) {
      for (final name in _binaryNames) {
        final f = File(p.join(dir, name));
        if (await f.exists()) return p.normalize(f.path);
      }
    }

    // On PATH.
    for (final name in _binaryNames) {
      try {
        final r = await Process.run(
          Platform.isWindows ? 'where' : 'which',
          [name],
          runInShell: Platform.isWindows,
        );
        if (r.exitCode == 0) {
          final line = r.stdout.toString().trim().split('\n').first.trim();
          if (line.isNotEmpty) return line;
        }
      } catch (_) {}
    }

    // Common manual install locations.
    if (!Platform.isWindows) {
      final home = Platform.environment['HOME'] ?? '';
      for (final dir in [
        '/usr/local/bin',
        '/opt/homebrew/bin',
        '/opt/whisper.cpp/build/bin',
        if (home.isNotEmpty) p.join(home, '.local', 'bin'),
        if (home.isNotEmpty) p.join(home, 'whisper.cpp', 'build', 'bin'),
      ]) {
        for (final name in _binaryNames) {
          final f = File(p.join(dir, name));
          if (await f.exists()) return f.path;
        }
      }
    }
    return null;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<int> _freePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  /// Starts whisper-server with the selected model and waits until it serves.
  Future<void> start() async {
    if (effectiveMode != WhisperMode.local) return;
    if (status == WhisperStatus.starting) return;
    if (status == WhisperStatus.running && _runningModel == modelPath) return;
    await stop();

    resolvedBinary ??= await _findBinary();
    final binary = resolvedBinary;
    if (binary == null) {
      _fail('whisper.cpp engine (whisper-server) was not found.');
      throw WhisperException(error!);
    }
    if (modelPath.isEmpty || !await File(modelPath).exists()) {
      _fail('No whisper model selected.');
      throw WhisperException(error!);
    }

    status = WhisperStatus.starting;
    error = null;
    _logTail.clear();
    _notify();

    try {
      _port = await _freePort();
      final process = await Process.start(
        binary,
        [
          '-m', modelPath,
          '--host', '127.0.0.1',
          '--port', '$_port',
          '-t', '$threads',
          '-l', language,
        ],
        workingDirectory: p.dirname(binary),
      );
      _process = process;
      _runningModel = modelPath;
      unawaited(_rememberPid(process.pid));

      void capture(Stream<List<int>> stream) {
        stream
            .transform(const Utf8Decoder(allowMalformed: true))
            .transform(const LineSplitter())
            .listen((line) {
          _logTail.add(line);
          if (_logTail.length > 40) _logTail.removeAt(0);
        }, onError: (_) {});
      }

      capture(process.stdout);
      capture(process.stderr);

      unawaited(process.exitCode.then((code) {
        if (!identical(_process, process)) return;
        _process = null;
        _runningModel = null;
        if (status != WhisperStatus.stopped) {
          _fail(
            'whisper-server exited (code $code).'
            '${_logTail.isEmpty ? '' : '\n${_logTail.skip(_logTail.length > 6 ? _logTail.length - 6 : 0).join('\n')}'}',
          );
        }
      }));

      // Loading a large model can take a while on slow disks.
      final deadline = DateTime.now().add(const Duration(seconds: 120));
      while (DateTime.now().isBefore(deadline)) {
        if (!identical(_process, process)) {
          throw WhisperException(error ?? 'whisper-server failed to start.');
        }
        if (await _ping('http://127.0.0.1:$_port')) {
          status = WhisperStatus.running;
          _notify();
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      await stop();
      _fail('whisper-server did not become ready in time.');
      throw WhisperException(error!);
    } on WhisperException {
      rethrow;
    } catch (e) {
      await stop();
      _fail('$e');
      throw WhisperException(error!);
    }
  }

  Future<void> stop() async {
    final process = _process;
    _process = null;
    _runningModel = null;
    if (process != null) {
      process.kill();
      unawaited(_rememberPid(null));
      try {
        await process.exitCode.timeout(const Duration(seconds: 3));
      } catch (_) {
        process.kill(ProcessSignal.sigkill);
      }
    }
    status = WhisperStatus.stopped;
    error = null;
    _notify();
  }

  void _fail(String message) {
    status = WhisperStatus.error;
    error = message;
    _notify();
  }

  Future<bool> _ping(String base) async {
    final client = createClientForBase(base);
    try {
      final res = await client
          .get(Uri.parse('$base/'))
          .timeout(const Duration(seconds: 2));
      return res.statusCode < 500;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  /// Checks that the configured remote server answers.
  Future<bool> testRemote() => _ping(_remoteBase);

  // ── Transcription ─────────────────────────────────────────────────────────

  /// Transcribes 16 kHz mono WAV audio and returns the recognised text.
  Future<String> transcribe(List<int> wavBytes, {String name = 'audio.wav'}) async {
    final String base;
    if (effectiveMode == WhisperMode.remote) {
      if (_remoteBase.isEmpty) {
        throw WhisperException('Remote whisper server URL is not set.');
      }
      base = _remoteBase;
    } else {
      if (status != WhisperStatus.running || _runningModel != modelPath) {
        await start();
      }
      base = 'http://127.0.0.1:$_port';
    }

    final client = createClientForBase(base);
    try {
      final req = http.MultipartRequest('POST', Uri.parse('$base/inference'))
        ..fields['response_format'] = 'json'
        ..fields['temperature'] = '0.0'
        ..fields['temperature_inc'] = '0.2'
        ..fields['language'] = language
        ..fields['translate'] = translate ? 'true' : 'false'
        ..files.add(
          http.MultipartFile.fromBytes('file', wavBytes, filename: name),
        );
      final streamed =
          await client.send(req).timeout(const Duration(minutes: 30));
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode != 200) {
        throw WhisperException(
          'whisper server error ${streamed.statusCode}: '
          '${body.length > 200 ? body.substring(0, 200) : body}',
        );
      }
      String text;
      try {
        final json = jsonDecode(body);
        if (json is Map && json['error'] != null) {
          throw WhisperException('${json['error']}');
        }
        text = json is Map ? (json['text']?.toString() ?? '') : body;
      } on FormatException {
        text = body;
      }
      return cleanTranscript(text);
    } on TimeoutException {
      throw WhisperException('Transcription timed out.');
    } on SocketException catch (e) {
      throw WhisperException('Cannot reach whisper server: ${e.message}');
    } finally {
      client.close();
    }
  }

  /// Transcribes an arbitrary audio file. Non-WAV input is converted with
  /// ffmpeg when it is installed.
  Future<String> transcribeFile(String path) async {
    var file = File(path);
    File? temp;
    try {
      if (!await isWhisperWav(file)) {
        temp = await _convertToWav(path);
        file = temp;
      }
      return await transcribe(
        await file.readAsBytes(),
        name: '${p.basenameWithoutExtension(path)}.wav',
      );
    } finally {
      try {
        await temp?.delete();
      } catch (_) {}
    }
  }

  /// whisper.cpp accepts 16-bit PCM WAV at 16 kHz.
  static Future<bool> isWhisperWav(File file) async {
    try {
      final raf = await file.open();
      try {
        final h = await raf.read(44);
        if (h.length < 44) return false;
        final riff = ascii.decode(h.sublist(0, 4), allowInvalid: true);
        final wave = ascii.decode(h.sublist(8, 12), allowInvalid: true);
        if (riff != 'RIFF' || wave != 'WAVE') return false;
        final format = h[20] | (h[21] << 8);
        final rate = h[24] | (h[25] << 8) | (h[26] << 16) | (h[27] << 24);
        final bits = h[34] | (h[35] << 8);
        return format == 1 && rate == 16000 && bits == 16;
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
    }
  }

  Future<File> _convertToWav(String path) async {
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      throw WhisperException(
        'Only 16 kHz 16-bit WAV audio is supported on this device.',
      );
    }
    final dir = await getTemporaryDirectory();
    final out = File(
      p.join(dir.path, 'mg_whisper_${DateTime.now().microsecondsSinceEpoch}.wav'),
    );
    try {
      final r = await Process.run(
        'ffmpeg',
        [
          '-y', '-loglevel', 'error',
          '-i', path,
          '-ar', '16000', '-ac', '1', '-c:a', 'pcm_s16le',
          out.path,
        ],
        runInShell: Platform.isWindows,
      );
      if (r.exitCode != 0 || !await out.exists()) {
        throw WhisperException(
          'Could not convert audio: ${r.stderr.toString().trim()}',
        );
      }
      return out;
    } on ProcessException {
      throw WhisperException(
        'This file is not 16 kHz WAV and ffmpeg is not installed to '
        'convert it.',
      );
    }
  }

  /// Strips whisper's non-speech annotations and collapses whitespace.
  static String cleanTranscript(String text) {
    var t = text
        .replaceAll(RegExp(r'\[(BLANK_AUDIO|MUSIC|NOISE|SILENCE|INAUDIBLE)[^\]]*\]',
            caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\((music|silence|applause|noise)[^)]*\)',
            caseSensitive: false), ' ');
    t = t.replaceAll(RegExp(r'[ \t]+'), ' ');
    t = t.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).join('\n');
    return t.trim();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _process?.kill();
    _process = null;
    super.dispose();
  }
}
