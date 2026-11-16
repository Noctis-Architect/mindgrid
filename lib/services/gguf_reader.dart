import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

/// Metadata extracted from a GGUF file header.
///
/// Only the key/value section is read — tensor data is never touched, so this
/// works on multi-gigabyte files and on partially downloaded ones as long as
/// the header is complete.
class GgufMetadata {
  const GgufMetadata({
    required this.version,
    required this.tensorCount,
    required this.fileSize,
    required this.values,
    this.specialTokens = const {},
    this.bosToken,
    this.eosToken,
    this.eotToken,
    this.vocabSize = 0,
  });

  final int version;
  final int tensorCount;
  final int fileSize;

  /// Scalar and short-array metadata values (large arrays are omitted).
  final Map<String, Object?> values;

  /// Well-known control tokens that exist in the vocabulary.
  final Set<String> specialTokens;
  final String? bosToken;
  final String? eosToken;
  final String? eotToken;
  final int vocabSize;

  String? _str(String key) {
    final v = values[key];
    return v is String && v.trim().isNotEmpty ? v.trim() : null;
  }

  int? _int(String key) {
    final v = values[key];
    return v is int ? v : (v is num ? v.toInt() : null);
  }

  String? get architecture => _str('general.architecture');
  String? get name => _str('general.name');
  String? get basename => _str('general.basename');
  String? get sizeLabel => _str('general.size_label');
  String? get finetune => _str('general.finetune');
  String? get license => _str('general.license');
  String? get quantizedBy => _str('general.quantized_by');
  String? get baseModelName => _str('general.base_model.0.name');
  String? get chatTemplate => _str('tokenizer.chat_template');
  String? get tokenizerModel => _str('tokenizer.ggml.model');
  int? get fileType => _int('general.file_type');
  int? get parameterCount => _int('general.parameter_count');

  int? get contextLength {
    final arch = architecture;
    if (arch == null) return null;
    return _int('$arch.context_length');
  }

  int? get embeddingLength {
    final arch = architecture;
    if (arch == null) return null;
    return _int('$arch.embedding_length');
  }

  int? get blockCount {
    final arch = architecture;
    if (arch == null) return null;
    return _int('$arch.block_count');
  }

  bool get hasVision {
    final arch = architecture;
    return values.keys.any(
      (k) =>
          k.startsWith('clip.') ||
          (arch != null && k.startsWith('$arch.vision.')) ||
          k.startsWith('mmproj.'),
    );
  }

  /// Human readable quantization (e.g. `Q4_K_M`), from `general.file_type`.
  String? get quantization => ggufFileTypeName(fileType);
}

String? ggufFileTypeName(int? fileType) {
  const names = <int, String>{
    0: 'F32',
    1: 'F16',
    2: 'Q4_0',
    3: 'Q4_1',
    7: 'Q8_0',
    8: 'Q5_0',
    9: 'Q5_1',
    10: 'Q2_K',
    11: 'Q3_K_S',
    12: 'Q3_K_M',
    13: 'Q3_K_L',
    14: 'Q4_K_S',
    15: 'Q4_K_M',
    16: 'Q5_K_S',
    17: 'Q5_K_M',
    18: 'Q6_K',
    19: 'IQ2_XXS',
    20: 'IQ2_XS',
    21: 'Q2_K_S',
    22: 'IQ3_XS',
    23: 'IQ3_XXS',
    24: 'IQ1_S',
    25: 'IQ4_NL',
    26: 'IQ3_S',
    27: 'IQ3_M',
    28: 'IQ2_S',
    29: 'IQ2_M',
    30: 'IQ4_XS',
    31: 'IQ1_M',
    32: 'BF16',
    34: 'TQ1_0',
    35: 'TQ2_0',
  };
  return fileType == null ? null : names[fileType];
}

class GgufFormatException implements Exception {
  GgufFormatException(this.message, {this.truncated = false});
  final String message;

  /// True when the header ran past the end of the available bytes — the file
  /// is incomplete (e.g. a partial download) rather than malformed.
  final bool truncated;

  @override
  String toString() => message;
}

/// Control tokens we look for in the vocabulary to pick a chat format when
/// the file carries no `tokenizer.chat_template`.
const ggufKnownSpecialTokens = <String>{
  '<|im_start|>',
  '<|im_end|>',
  '<|im_sep|>',
  '<|endoftext|>',
  '<start_of_turn>',
  '<end_of_turn>',
  '<|turn>',
  '<turn|>',
  '<|start_header_id|>',
  '<|end_header_id|>',
  '<|eot_id|>',
  '<|eom_id|>',
  '<｜User｜>',
  '<｜Assistant｜>',
  '<｜end▁of▁sentence｜>',
  '<｜begin▁of▁sentence｜>',
  '<|user|>',
  '<|assistant|>',
  '<|system|>',
  '<|end|>',
  '[INST]',
  '[/INST]',
  '<think>',
  '</think>',
  '<tool_call>',
  '</tool_call>',
  '<|start_of_role|>',
  '<|end_of_role|>',
  '<|end_of_text|>',
  '<|START_OF_TURN_TOKEN|>',
  '<|END_OF_TURN_TOKEN|>',
  '<|start|>',
  '<|channel|>',
  '</s>',
};

class GgufReader {
  GgufReader._();

  /// Reads GGUF metadata off the UI isolate.
  static Future<GgufMetadata> read(String path) {
    return Isolate.run(() => readSync(path));
  }

  static GgufMetadata readSync(String path) {
    final file = File(path);
    final raf = file.openSync();
    try {
      final r = _Reader(raf, raf.lengthSync());
      final magic = r.bytes(4);
      if (magic[0] != 0x47 ||
          magic[1] != 0x47 ||
          magic[2] != 0x55 ||
          magic[3] != 0x46) {
        throw GgufFormatException('Not a GGUF file (bad magic header).');
      }
      final version = r.u32();
      if (version < 1 || version > 3) {
        throw GgufFormatException('Unsupported GGUF version $version.');
      }
      r.wide = version >= 2;
      final tensorCount = r.len();
      final kvCount = r.len();
      if (kvCount > 100000) {
        throw GgufFormatException('Corrupt GGUF header.');
      }

      final values = <String, Object?>{};
      List<String>? tokens;

      for (var i = 0; i < kvCount; i++) {
        final key = r.string();
        final type = r.u32();
        if (type == _tArray) {
          final itemType = r.u32();
          final count = r.len();
          if (key == 'tokenizer.ggml.tokens' && itemType == _tString) {
            tokens = List<String>.generate(count, (_) => r.string());
          } else if (count <= 16 && itemType != _tArray) {
            values[key] =
                List<Object?>.generate(count, (_) => r.value(itemType));
          } else {
            r.skipArray(itemType, count);
          }
        } else {
          values[key] = r.value(type);
        }
      }

      String? tokenAt(String key) {
        final id = values[key];
        if (tokens == null || id is! int || id < 0 || id >= tokens.length) {
          return null;
        }
        return tokens[id];
      }

      final special = <String>{};
      if (tokens != null) {
        for (final t in tokens) {
          if (ggufKnownSpecialTokens.contains(t)) special.add(t);
        }
      }

      return GgufMetadata(
        version: version,
        tensorCount: tensorCount,
        fileSize: r.fileLength,
        values: values,
        specialTokens: special,
        bosToken: tokenAt('tokenizer.ggml.bos_token_id'),
        eosToken: tokenAt('tokenizer.ggml.eos_token_id'),
        eotToken: tokenAt('tokenizer.ggml.eot_token_id'),
        vocabSize: tokens?.length ?? 0,
      );
    } finally {
      raf.closeSync();
    }
  }
}

const _tU8 = 0;
const _tI8 = 1;
const _tU16 = 2;
const _tI16 = 3;
const _tU32 = 4;
const _tI32 = 5;
const _tF32 = 6;
const _tBool = 7;
const _tString = 8;
const _tArray = 9;
const _tU64 = 10;
const _tI64 = 11;
const _tF64 = 12;

class _Reader {
  _Reader(this._raf, this.fileLength);

  final RandomAccessFile _raf;
  final int fileLength;

  /// GGUF v1 used 32-bit lengths; v2+ uses 64-bit.
  bool wide = true;

  static const _chunk = 1 << 20;
  Uint8List _buf = Uint8List(0);
  int _bufStart = 0; // file offset of _buf[0]
  int _pos = 0; // absolute file offset

  void _need(int n) {
    if (_pos + n > fileLength) {
      throw GgufFormatException(
        'GGUF header is incomplete (file truncated).',
        truncated: true,
      );
    }
    final rel = _pos - _bufStart;
    if (rel >= 0 && rel + n <= _buf.length) return;
    final size = n > _chunk ? n : _chunk;
    final toRead = (_pos + size > fileLength) ? fileLength - _pos : size;
    _raf.setPositionSync(_pos);
    _buf = _raf.readSync(toRead);
    _bufStart = _pos;
    if (_buf.length < n) {
      throw GgufFormatException(
        'GGUF header is incomplete (file truncated).',
        truncated: true,
      );
    }
  }

  ByteData _view(int n) {
    _need(n);
    final rel = _pos - _bufStart;
    _pos += n;
    return ByteData.sublistView(_buf, rel, rel + n);
  }

  Uint8List bytes(int n) {
    _need(n);
    final rel = _pos - _bufStart;
    _pos += n;
    return Uint8List.sublistView(_buf, rel, rel + n);
  }

  void skip(int n) {
    if (_pos + n > fileLength) {
      throw GgufFormatException(
        'GGUF header is incomplete (file truncated).',
        truncated: true,
      );
    }
    _pos += n;
  }

  int u32() => _view(4).getUint32(0, Endian.little);
  int u64() => _view(8).getUint64(0, Endian.little);
  int len() => wide ? u64() : u32();

  String string() {
    final n = len();
    if (n < 0 || n > 64 * 1024 * 1024) {
      throw GgufFormatException('Corrupt GGUF string length.');
    }
    return utf8.decode(bytes(n), allowMalformed: true);
  }

  Object? value(int type) {
    switch (type) {
      case _tU8:
        return _view(1).getUint8(0);
      case _tI8:
        return _view(1).getInt8(0);
      case _tU16:
        return _view(2).getUint16(0, Endian.little);
      case _tI16:
        return _view(2).getInt16(0, Endian.little);
      case _tU32:
        return u32();
      case _tI32:
        return _view(4).getInt32(0, Endian.little);
      case _tF32:
        return _view(4).getFloat32(0, Endian.little);
      case _tBool:
        return _view(1).getUint8(0) != 0;
      case _tString:
        return string();
      case _tU64:
        return u64();
      case _tI64:
        return _view(8).getInt64(0, Endian.little);
      case _tF64:
        return _view(8).getFloat64(0, Endian.little);
      case _tArray:
        final itemType = u32();
        final count = len();
        skipArray(itemType, count);
        return null;
      default:
        throw GgufFormatException('Unknown GGUF value type $type.');
    }
  }

  static int? _fixedSize(int type) => switch (type) {
        _tU8 || _tI8 || _tBool => 1,
        _tU16 || _tI16 => 2,
        _tU32 || _tI32 || _tF32 => 4,
        _tU64 || _tI64 || _tF64 => 8,
        _ => null,
      };

  void skipArray(int itemType, int count) {
    final fixed = _fixedSize(itemType);
    if (fixed != null) {
      skip(fixed * count);
      return;
    }
    if (itemType == _tString) {
      for (var i = 0; i < count; i++) {
        skip(len());
      }
      return;
    }
    if (itemType == _tArray) {
      for (var i = 0; i < count; i++) {
        final t = u32();
        final c = len();
        skipArray(t, c);
      }
      return;
    }
    throw GgufFormatException('Unknown GGUF array type $itemType.');
  }
}
