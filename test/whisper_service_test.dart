import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindgrid/services/whisper_service.dart';

Uint8List wav({int rate = 16000, int bits = 16, int format = 1}) {
  final b = ByteData(44 + 320);
  void tag(int o, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + 320, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, format, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, rate, Endian.little);
  b.setUint32(28, rate * bits ~/ 8, Endian.little);
  b.setUint16(32, bits ~/ 8, Endian.little);
  b.setUint16(34, bits, Endian.little);
  tag(36, 'data');
  b.setUint32(40, 320, Endian.little);
  return b.buffer.asUint8List();
}

void main() {
  test('cleanTranscript strips non-speech markers and tidies whitespace', () {
    expect(
      WhisperService.cleanTranscript(' [BLANK_AUDIO]\n  Hello   there. \n\n (music)\n How are you?\n'),
      'Hello there.\nHow are you?',
    );
    expect(WhisperService.cleanTranscript('[MUSIC PLAYING]'), '');
    expect(WhisperService.cleanTranscript(' سلام  دنیا '), 'سلام دنیا');
  });

  test('isWhisperWav accepts only 16 kHz 16-bit PCM', () async {
    final dir = Directory.systemTemp.createTempSync('mg_wav');
    addTearDown(() => dir.deleteSync(recursive: true));
    Future<bool> check(Uint8List bytes) async {
      final f = File('${dir.path}/a.wav')..writeAsBytesSync(bytes);
      return WhisperService.isWhisperWav(f);
    }

    expect(await check(wav()), isTrue);
    expect(await check(wav(rate: 44100)), isFalse);
    expect(await check(wav(bits: 8)), isFalse);
    expect(await check(wav(format: 3)), isFalse);
    expect(await check(Uint8List.fromList([1, 2, 3])), isFalse);
  });

  test('catalog file names follow whisper.cpp naming', () {
    expect(WhisperService.catalog.first.fileName, 'ggml-tiny.bin');
    expect(
      WhisperService.catalog.map((m) => m.id),
      containsAll(['base', 'small', 'large-v3-turbo']),
    );
  });
}
