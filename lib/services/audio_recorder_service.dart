import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../l10n/app_strings.dart';

class AudioRecorderService {
  AudioRecorderService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isLinux || Platform.isMacOS || Platform.isWindows);

  Future<bool> hasPermission() async {
    if (!isSupported) return false;
    return _recorder.hasPermission();
  }

  Future<bool> requestPermission() async {
    if (!isSupported) return false;

    // permission_handler only supports mobile; desktop recorders manage access
    // themselves (e.g. PipeWire on Linux).
    if (Platform.isAndroid || Platform.isIOS) {
      final mic = await Permission.microphone.request();
      if (!mic.isGranted) return false;
    }

    return _recorder.hasPermission();
  }

  Future<String> _tempPath() async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return p.join(dir.path, 'mindgrid_voice_$stamp.wav');
  }

  Future<void> start(AppStrings strings) async {
    if (!isSupported) {
      throw StateError(strings.audioRecordUnsupported);
    }
    if (!await requestPermission()) {
      throw StateError(strings.microphoneDenied);
    }
    final path = await _tempPath();
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 256000,
      ),
      path: path,
    );
  }

  Future<List<int>> stop(AppStrings strings) async {
    final path = await _recorder.stop();
    if (path == null || path.isEmpty) {
      throw StateError(strings.audioFileNotSaved);
    }
    final file = File(path);
    if (!await file.exists()) {
      throw StateError(strings.audioFileNotFound);
    }
    final bytes = await file.readAsBytes();
    await file.delete().catchError((_) => file);
    if (bytes.isEmpty) {
      throw StateError(strings.audioRecordEmpty);
    }
    return bytes;
  }

  Future<void> cancel() async {
    await _recorder.stop();
  }

  Future<bool> get isRecording async => _recorder.isRecording();

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
