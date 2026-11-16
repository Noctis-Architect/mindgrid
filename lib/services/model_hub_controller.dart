import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/app_settings.dart';
import '../models/ollama_models.dart';
import 'hf_service.dart';
import 'model_templates.dart';
import 'ollama_manager_service.dart';

enum HubTaskKind { pull, huggingFace, localFile, whisperModel }

enum HubTaskStage {
  queued,
  downloading,
  hashing,
  uploading,
  creating,
  paused,
  completed,
  failed,
}

class HubTask {
  HubTask({
    required this.id,
    required this.kind,
    required this.model,
    this.spec,
    this.filePath,
    this.fileName,
    this.url,
    this.digest,
    this.total = 0,
    this.deleteFileWhenDone = false,
  });

  final String id;
  final HubTaskKind kind;

  /// Target Ollama model name.
  final String model;

  final ModelfileSpec? spec;

  /// Final GGUF path on disk (import tasks).
  String? filePath;
  final String? fileName;
  final String? url;

  /// `sha256:<hex>` when known up front (Hugging Face LFS object id).
  String? digest;
  final bool deleteFileWhenDone;

  HubTaskStage stage = HubTaskStage.queued;
  int received = 0;
  int total;
  double speed = 0;
  int? etaSeconds;
  String? status;
  String? error;

  // Runtime handles.
  void Function()? _abort;
  bool _stopRequested = false;
  final _SpeedMeter _meter = _SpeedMeter();

  String get partPath => '${filePath!}.part';

  double? get fraction {
    if (total <= 0) return null;
    return (received / total).clamp(0.0, 1.0);
  }

  bool get isActive =>
      stage == HubTaskStage.downloading ||
      stage == HubTaskStage.hashing ||
      stage == HubTaskStage.uploading ||
      stage == HubTaskStage.creating;

  bool get isPending =>
      isActive ||
      stage == HubTaskStage.queued ||
      stage == HubTaskStage.paused;

  bool get canPause =>
      stage == HubTaskStage.downloading && kind != HubTaskKind.localFile;

  bool get _isFileDownload =>
      kind == HubTaskKind.huggingFace || kind == HubTaskKind.whisperModel;
}

class _SpeedMeter {
  int? _lastBytes;
  DateTime? _lastTime;
  double? _smoothed;

  void reset() {
    _lastBytes = null;
    _lastTime = null;
    _smoothed = null;
  }

  void update(HubTask t) {
    final now = DateTime.now();
    if (_lastBytes == null || _lastTime == null) {
      _lastBytes = t.received;
      _lastTime = now;
      return;
    }
    final dt = now.difference(_lastTime!).inMilliseconds;
    if (dt < 400) return;
    final delta = t.received - _lastBytes!;
    if (delta >= 0) {
      final instant = delta * 1000 / dt;
      _smoothed = _smoothed == null ? instant : _smoothed! * 0.7 + instant * 0.3;
    }
    _lastBytes = t.received;
    _lastTime = now;
    t.speed = _smoothed ?? 0;
    t.etaSeconds = (t.speed > 0 && t.total > t.received)
        ? ((t.total - t.received) / t.speed).ceil()
        : null;
  }
}

class _Stopped implements Exception {}

/// App-wide queue for everything that installs a model into Ollama:
/// library pulls, Hugging Face downloads and local GGUF imports.
class ModelHubController extends ChangeNotifier {
  ModelHubController({
    required this.service,
    required this.settings,
    this.onInstalled,
    this.onFailed,
    this.onWhisperModelReady,
  });

  final OllamaManagerService service;
  final AppSettings Function() settings;
  final void Function(String model)? onInstalled;
  final void Function(String model, String error)? onFailed;

  /// A whisper.cpp model finished downloading to [path].
  final void Function(String path)? onWhisperModelReady;

  final List<HubTask> tasks = [];
  HubTask? _active;
  Timer? _notifyTimer;
  int _seq = 0;
  bool _disposed = false;

  int get pendingCount => tasks.where((t) => t.isPending).length;

  HubTask? taskForModel(String model) {
    for (final t in tasks) {
      if (t.isPending && ollamaModelNamesMatch(t.model, model)) return t;
    }
    return null;
  }

  static Future<Directory> modelsDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'gguf'));
    await dir.create(recursive: true);
    return dir;
  }

  // ── Enqueue ───────────────────────────────────────────────────────────────

  void enqueuePull(String model) {
    if (taskForModel(model) != null) return;
    tasks.removeWhere(
      (t) => !t.isPending && ollamaModelNamesMatch(t.model, model),
    );
    _add(HubTask(id: 't${_seq++}', kind: HubTaskKind.pull, model: model));
  }

  void enqueueLocalImport({
    required String path,
    required ModelfileSpec spec,
  }) {
    _add(
      HubTask(
        id: 't${_seq++}',
        kind: HubTaskKind.localFile,
        model: spec.name,
        spec: spec,
        filePath: path,
        fileName: p.basename(path),
      ),
    );
  }

  void enqueueHuggingFace({
    required String url,
    required String destPath,
    required int size,
    required ModelfileSpec spec,
    String? sha256,
    bool keepFile = false,
  }) {
    _add(
      HubTask(
        id: 't${_seq++}',
        kind: HubTaskKind.huggingFace,
        model: spec.name,
        spec: spec,
        filePath: destPath,
        fileName: p.basename(destPath),
        url: url,
        total: size,
        digest: sha256 != null && sha256.isNotEmpty ? 'sha256:$sha256' : null,
        deleteFileWhenDone: !keepFile,
      ),
    );
  }

  /// Downloads a whisper.cpp ggml model (no Ollama import step).
  void enqueueWhisperModel({
    required String name,
    required String url,
    required String destPath,
    int size = 0,
  }) {
    if (tasks.any((t) => t.isPending && t.filePath == destPath)) return;
    _add(
      HubTask(
        id: 't${_seq++}',
        kind: HubTaskKind.whisperModel,
        model: name,
        filePath: destPath,
        fileName: p.basename(destPath),
        url: url,
        total: size,
      ),
    );
  }

  void _add(HubTask task) {
    tasks.add(task);
    _notify(now: true);
    _pump();
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  void pause(String id) {
    final t = _find(id);
    if (t == null || !t.canPause) return;
    t._stopRequested = true;
    t.stage = HubTaskStage.paused;
    t.speed = 0;
    t.etaSeconds = null;
    t._abort?.call();
    _notify(now: true);
  }

  void resume(String id) {
    final t = _find(id);
    if (t == null || t.stage != HubTaskStage.paused) return;
    t.stage = HubTaskStage.queued;
    _notify(now: true);
    _pump();
  }

  void retry(String id) {
    final t = _find(id);
    if (t == null || t.stage != HubTaskStage.failed) return;
    t.error = null;
    t.stage = HubTaskStage.queued;
    _notify(now: true);
    _pump();
  }

  Future<void> cancel(String id) async {
    final t = _find(id);
    if (t == null) return;
    t._stopRequested = true;
    t._abort?.call();
    tasks.remove(t);
    if (t._isFileDownload && t.filePath != null) {
      for (final path in [t.partPath, if (t.deleteFileWhenDone) t.filePath!]) {
        try {
          final f = File(path);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }
    _notify(now: true);
  }

  void clearFinished() {
    tasks.removeWhere(
      (t) =>
          t.stage == HubTaskStage.completed || t.stage == HubTaskStage.failed,
    );
    _notify(now: true);
  }

  HubTask? _find(String id) {
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  // ── Worker ────────────────────────────────────────────────────────────────

  void _pump() {
    if (_active != null || _disposed) return;
    HubTask? next;
    for (final t in tasks) {
      if (t.stage == HubTaskStage.queued) {
        next = t;
        break;
      }
    }
    if (next == null) return;
    _active = next;
    unawaited(_run(next));
  }

  Future<void> _run(HubTask t) async {
    t._stopRequested = false;
    t._meter.reset();
    t.error = null;
    try {
      switch (t.kind) {
        case HubTaskKind.pull:
          await _runPull(t);
        case HubTaskKind.huggingFace:
          await _runDownload(t);
          await _runImport(t);
        case HubTaskKind.localFile:
          await _runImport(t);
        case HubTaskKind.whisperModel:
          await _runDownload(t);
      }
      t.stage = HubTaskStage.completed;
      t.speed = 0;
      t.etaSeconds = null;
      if (t.kind == HubTaskKind.whisperModel) {
        onWhisperModelReady?.call(t.filePath!);
      } else {
        onInstalled?.call(t.model);
      }
    } on _Stopped {
      // paused or cancelled — state already set by the caller
    } catch (e) {
      if (!t._stopRequested) {
        t.stage = HubTaskStage.failed;
        t.error = _cleanError(e);
        t.speed = 0;
        t.etaSeconds = null;
        onFailed?.call(t.model, t.error!);
      }
    } finally {
      t._abort = null;
      if (identical(_active, t)) _active = null;
      _notify(now: true);
      _pump();
    }
  }

  String _cleanError(Object e) {
    var s = e.toString();
    s = s.replaceFirst(RegExp(r'^(Exception|HttpException|ClientException): '), '');
    return s.length > 400 ? '${s.substring(0, 400)}…' : s;
  }

  void _check(HubTask t) {
    if (t._stopRequested) throw _Stopped();
  }

  Future<void> _runPull(HubTask t) async {
    t.stage = HubTaskStage.downloading;
    t.status = 'pulling manifest';
    _notify(now: true);

    final session = service.startPull(t.model, settings());
    t._abort = session.cancel;
    String? error;
    var done = false;
    await for (final progress in session.stream) {
      if (t._stopRequested) break;
      t.status = progress.status;
      if (progress.completed != null) t.received = progress.completed!;
      if (progress.total != null) t.total = progress.total!;
      t._meter.update(t);
      if (progress.done) {
        done = true;
        error = progress.error;
        break;
      }
      _notify();
    }
    _check(t);
    if (error != null && error.isNotEmpty) throw Exception(error);
    if (!done) throw Exception('Connection to Ollama was interrupted');
  }

  Future<void> _runDownload(HubTask t) async {
    final dest = File(t.filePath!);
    if (await dest.exists() && (t.total <= 0 || await dest.length() == t.total)) {
      t.received = await dest.length();
      return;
    }

    t.stage = HubTaskStage.downloading;
    t.status = null;
    final part = File(t.partPath);
    await part.parent.create(recursive: true);
    final hf = await HfSettings.load();

    var attempts = 0;
    while (true) {
      _check(t);
      var have = await part.exists() ? await part.length() : 0;
      if (t.total > 0 && have > t.total) {
        await part.delete();
        have = 0;
      }
      t.received = have;
      _notify(now: true);
      if (t.total > 0 && have == t.total) break;

      final client = HfService.createClient(hf);
      t._abort = () => client.close(force: true);
      IOSink? sink;
      try {
        final res = await HfService.open(
          client,
          Uri.parse(t.url!),
          token: hf.token.trim(),
          rangeStart: have > 0 ? have : null,
        ).timeout(const Duration(seconds: 45));

        if (res.statusCode == 416) {
          await res.drain<void>();
          await part.delete();
          continue;
        }
        if (res.statusCode != 200 && res.statusCode != 206) {
          await res.drain<void>();
          throw HfException(
            switch (res.statusCode) {
              401 => 'Unauthorized (401) — add a Hugging Face token.',
              403 => 'Access denied (403) — accept the model license on '
                  'Hugging Face or check your token.',
              404 => 'File not found (404).',
              _ => 'HTTP ${res.statusCode}',
            },
            statusCode: res.statusCode,
          );
        }
        if (res.statusCode == 200 && have > 0) {
          // Range ignored: restart from zero.
          await part.writeAsBytes(const []);
          have = 0;
          t.received = 0;
        }
        if (t.total <= 0 && res.contentLength > 0) {
          t.total = have + res.contentLength;
        }

        sink = part.openWrite(mode: FileMode.append);
        await for (final chunk in res.timeout(const Duration(seconds: 60))) {
          if (t._stopRequested) break;
          sink.add(chunk);
          t.received += chunk.length;
          t._meter.update(t);
          _notify();
        }
        await sink.flush();
        await sink.close();
        sink = null;
        _check(t);
        attempts = 0;
        if (t.total <= 0 || t.received >= t.total) break;
        // Stream ended early — loop and resume from where we are.
      } on _Stopped {
        rethrow;
      } on HfException {
        rethrow;
      } catch (e) {
        try {
          await sink?.flush();
          await sink?.close();
        } catch (_) {}
        _check(t);
        attempts++;
        if (attempts > 6) rethrow;
        t.status = 'reconnecting';
        t.speed = 0;
        _notify(now: true);
        await Future<void>.delayed(Duration(seconds: 2 * attempts));
      } finally {
        client.close(force: true);
        t._abort = null;
      }
    }

    _check(t);
    if (await dest.exists()) await dest.delete();
    await part.rename(dest.path);
    t.status = null;
  }

  Future<void> _runImport(HubTask t) async {
    final file = File(t.filePath!);
    if (!await file.exists()) {
      throw Exception('File not found: ${t.filePath}');
    }
    final size = await file.length();
    final cfg = settings();

    // 1. Digest
    var digest = t.digest;
    if (digest == null) {
      t.stage = HubTaskStage.hashing;
      t.received = 0;
      t.total = size;
      t.speed = 0;
      t.etaSeconds = null;
      t._meter.reset();
      _notify(now: true);
      final hex = await _sha256(t, file.path);
      digest = 'sha256:$hex';
      t.digest = digest;
    }
    _check(t);

    // 2. Blob upload (skipped when Ollama already has it)
    final base = await service.resolveBase(cfg);
    if (!await service.blobExists(base, digest, cfg)) {
      t.stage = HubTaskStage.uploading;
      t.received = 0;
      t.total = size;
      t.speed = 0;
      t.etaSeconds = null;
      t._meter.reset();
      _notify(now: true);
      await service.uploadBlob(
        base: base,
        digest: digest,
        file: file,
        settings: cfg,
        onAbortHandle: (abort) => t._abort = abort,
        onProgress: (sent, total) {
          t.received = sent;
          t.total = total;
          t._meter.update(t);
          _notify();
        },
      );
    }
    _check(t);

    // 3. Create
    t.stage = HubTaskStage.creating;
    t.speed = 0;
    t.etaSeconds = null;
    t.status = 'creating model';
    _notify(now: true);
    final body = t.spec!.toCreateJson(
      fileName: t.fileName ?? 'model.gguf',
      digest: digest,
    );
    await for (final status in service.createModel(
      base: base,
      body: body,
      settings: cfg,
      onAbortHandle: (abort) => t._abort = abort,
    )) {
      t.status = status;
      _notify();
    }
    _check(t);

    if (t.deleteFileWhenDone) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  Future<String> _sha256(HubTask t, String path) async {
    final port = ReceivePort();
    final isolate = await Isolate.spawn(_hashEntry, [port.sendPort, path]);
    t._abort = () {
      isolate.kill(priority: Isolate.immediate);
      port.close();
    };
    try {
      await for (final msg in port) {
        if (msg is int) {
          t.received = msg;
          t._meter.update(t);
          _notify();
        } else if (msg is String) {
          return msg;
        } else if (msg is List && msg.isNotEmpty) {
          throw Exception(msg.first.toString());
        }
      }
      throw _Stopped();
    } finally {
      port.close();
      t._abort = null;
    }
  }

  static Future<void> _hashEntry(List<Object> args) async {
    final send = args[0] as SendPort;
    final path = args[1] as String;
    try {
      final out = AccumulatorSink<Digest>();
      final input = sha256.startChunkedConversion(out);
      final raf = await File(path).open();
      var done = 0;
      var lastReport = 0;
      try {
        while (true) {
          final chunk = await raf.read(4 * 1024 * 1024);
          if (chunk.isEmpty) break;
          input.add(chunk);
          done += chunk.length;
          if (done - lastReport >= 32 * 1024 * 1024) {
            lastReport = done;
            send.send(done);
          }
        }
      } finally {
        await raf.close();
      }
      input.close();
      send.send(out.events.single.toString());
    } catch (e) {
      send.send(['$e']);
    }
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  void _notify({bool now = false}) {
    if (_disposed) return;
    if (now) {
      _notifyTimer?.cancel();
      _notifyTimer = null;
      notifyListeners();
      return;
    }
    _notifyTimer ??= Timer(const Duration(milliseconds: 120), () {
      _notifyTimer = null;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _notifyTimer?.cancel();
    for (final t in tasks) {
      t._stopRequested = true;
      t._abort?.call();
    }
    super.dispose();
  }
}

/// Minimal sink that collects conversion output.
class AccumulatorSink<T> implements Sink<T> {
  final List<T> events = [];
  @override
  void add(T data) => events.add(data);
  @override
  void close() {}
}
