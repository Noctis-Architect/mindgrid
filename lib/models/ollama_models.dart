import '../l10n/app_strings.dart';

enum OllamaLocalStatus {
  running,
  installedNotRunning,
  notInstalled,
  unsupported,
}

class OllamaLibraryModel {
  const OllamaLibraryModel({
    required this.name,
    this.size,
    this.parameterSize,
    this.family,
  });

  final String name;
  final int? size;
  final String? parameterSize;
  final String? family;

  String get baseName => name.contains(':') ? name.split(':').first : name;

  factory OllamaLibraryModel.fromJson(Map<String, dynamic> json) {
    final details = json['details'];
    return OllamaLibraryModel(
      name: json['name'] as String? ?? json['model'] as String? ?? '',
      size: json['size'] as int?,
      parameterSize: details is Map
          ? details['parameter_size'] as String?
          : null,
      family: details is Map ? details['family'] as String? : null,
    );
  }
}

class OllamaModelFamily {
  const OllamaModelFamily({
    required this.name,
    this.description,
    this.featuredVariants = const [],
  });

  final String name;
  final String? description;
  final List<OllamaModelVariant> featuredVariants;
}

class OllamaModelVariant {
  const OllamaModelVariant({
    required this.fullName,
    required this.tag,
    this.parameterSize,
    this.quantization,
    this.variantType,
    this.sizeBytes,
  });

  final String fullName;
  final String tag;
  final String? parameterSize;
  final String? quantization;
  final String? variantType;
  final int? sizeBytes;

  String get groupKey {
    final parts = <String>[];
    if (parameterSize != null && parameterSize!.isNotEmpty) {
      parts.add(parameterSize!);
    }
    if (variantType != null && variantType!.isNotEmpty) {
      parts.add(variantType!);
    }
    return parts.isEmpty ? tag : parts.join(' · ');
  }

  String get displayLabel {
    if (quantization != null && quantization!.isNotEmpty) {
      return quantization!;
    }
    if (tag == 'latest') return 'latest';
    return tag;
  }
}

class OllamaTagParser {
  OllamaTagParser._();

  static final _paramRe = RegExp(r'^(\d+(?:\.\d+)?[bkmgt])$', caseSensitive: false);
  static final _quantRe = RegExp(
    r'(?:^|-)(q\d+(?:_\d+)?(?:_K_[SLM])?|fp16|f16|bf16)$',
    caseSensitive: false,
  );
  static final _kindRe = RegExp(r'^(instruct|text|vision|chat|embed|code)$');

  static OllamaModelVariant parse(
    String baseName,
    String tag, {
    int? sizeBytes,
  }) {
    if (tag == 'latest') {
      return OllamaModelVariant(
        fullName: '$baseName:latest',
        tag: tag,
        variantType: 'default',
        sizeBytes: sizeBytes,
      );
    }

    var working = tag;
    String? quant;
    final quantMatch = _quantRe.firstMatch(working);
    if (quantMatch != null) {
      quant = quantMatch.group(1)?.toUpperCase();
      working = working.substring(0, quantMatch.start).replaceAll(RegExp(r'-$'), '');
    }

    String? params;
    String? kind;
    for (final part in working.split('-')) {
      if (part.isEmpty) continue;
      if (_paramRe.hasMatch(part)) {
        params = part.toUpperCase();
      } else if (_kindRe.hasMatch(part)) {
        kind = part;
      }
    }

    if (params == null) {
      final simple = _paramRe.firstMatch(working);
      if (simple != null) params = simple.group(1)!.toUpperCase();
    }

    return OllamaModelVariant(
      fullName: '$baseName:$tag',
      tag: tag,
      parameterSize: params,
      quantization: quant,
      variantType: kind,
      sizeBytes: sizeBytes,
    );
  }
}

enum OllamaDownloadState {
  queued,
  downloading,
  paused,
  completed,
  failed,
}

class OllamaPullProgress {
  const OllamaPullProgress({
    required this.model,
    this.status,
    this.completed,
    this.total,
    this.done = false,
    this.error,
    this.speedBytesPerSec,
    this.etaSeconds,
  });

  final String model;
  final String? status;
  final int? completed;
  final int? total;
  final bool done;
  final String? error;
  final double? speedBytesPerSec;
  final int? etaSeconds;

  double? get fraction {
    if (completed == null || total == null || total == 0) return null;
    return (completed! / total!).clamp(0.0, 1.0);
  }

  int? get percent =>
      fraction != null ? (fraction! * 100).round().clamp(0, 100) : null;

  static OllamaPullProgress fromPullJson(
    Map<String, dynamic> json, {
    required String model,
    int? lastCompleted,
    int? lastTotal,
  }) {
    final status = json['status']?.toString();
    final completed = _pullInt(json['completed']) ?? lastCompleted;
    final total = _pullInt(json['total']) ?? lastTotal;
    final err = json['error']?.toString();
    final done = status == 'success' || json['done'] == true;

    return OllamaPullProgress(
      model: model,
      status: status,
      completed: completed,
      total: total,
      done: done,
      error: err,
    );
  }

  static int? _pullInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  OllamaPullProgress copyWith({
    String? status,
    int? completed,
    int? total,
    bool? done,
    String? error,
    double? speedBytesPerSec,
    int? etaSeconds,
  }) {
    return OllamaPullProgress(
      model: model,
      status: status ?? this.status,
      completed: completed ?? this.completed,
      total: total ?? this.total,
      done: done ?? this.done,
      error: error ?? this.error,
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      etaSeconds: etaSeconds ?? this.etaSeconds,
    );
  }

  String statusLabel(AppStrings s) {
    final st = status?.toLowerCase() ?? '';
    if (st.contains('pulling manifest')) return s.pullingManifest;
    if (st.contains('downloading')) return s.downloadingLayers;
    if (st.contains('verifying')) return s.verifyingChecksum;
    if (st.contains('success')) return s.installSuccess;
    return status ?? s.downloading;
  }
}

class OllamaPullSession {
  const OllamaPullSession({required this.stream, required this.cancel});

  final Stream<OllamaPullProgress> stream;
  final void Function() cancel;
}

class OllamaDownloadSpeedTracker {
  int? _lastBytes;
  DateTime? _lastTime;
  double? _smoothedSpeed;

  OllamaPullProgress enrich(OllamaPullProgress progress) {
    final completed = progress.completed;
    final total = progress.total;
    if (completed == null) return progress;

    final now = DateTime.now();
    if (_lastBytes != null && _lastTime != null) {
      final dtMs = now.difference(_lastTime!).inMilliseconds;
      if (dtMs >= 300) {
        final delta = completed - _lastBytes!;
        if (delta >= 0) {
          final instant = delta * 1000 / dtMs;
          _smoothedSpeed = _smoothedSpeed == null
              ? instant
              : _smoothedSpeed! * 0.7 + instant * 0.3;
        }
        _lastBytes = completed;
        _lastTime = now;
      }
    } else {
      _lastBytes = completed;
      _lastTime = now;
    }

    int? eta;
    final speed = _smoothedSpeed;
    if (speed != null &&
        speed > 0 &&
        total != null &&
        total > completed) {
      eta = ((total - completed) / speed).ceil();
    }

    return progress.copyWith(
      speedBytesPerSec: speed,
      etaSeconds: eta,
    );
  }

  void reset() {
    _lastBytes = null;
    _lastTime = null;
    _smoothedSpeed = null;
  }
}

class OllamaInstallResult {
  const OllamaInstallResult({required this.success, this.message = ''});

  final bool success;
  final String message;
}

class OllamaServiceResult {
  const OllamaServiceResult({required this.success, this.message = ''});

  final bool success;
  final String message;
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '—';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
}

String formatSpeed(double bytesPerSec) {
  if (bytesPerSec <= 0) return '—';
  return '${formatBytes(bytesPerSec.round())}/s';
}

String formatEta(int seconds, AppStrings s) {
  if (seconds <= 0) return s.etaRemaining;
  if (seconds < 60) return s.etaSeconds(seconds);
  if (seconds < 3600) {
    final m = seconds ~/ 60;
    final sec = seconds % 60;
    return s.etaMinutesSeconds(m, sec);
  }
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return s.etaHoursMinutes(h, m);
}

bool ollamaModelNamesMatch(String a, String b) {
  if (a == b) return true;
  final aParts = a.split(':');
  final bParts = b.split(':');
  final aBase = aParts.first;
  final bBase = bParts.first;
  if (aBase != bBase) return false;
  final aTag = aParts.length > 1 ? aParts.sublist(1).join(':') : 'latest';
  final bTag = bParts.length > 1 ? bParts.sublist(1).join(':') : 'latest';
  return aTag == bTag;
}
