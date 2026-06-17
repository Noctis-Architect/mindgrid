import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// Normalizes a local filesystem path from a picker result.
String normalizePickerPath(String? path) {
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('file://')) {
    return Uri.parse(path).toFilePath();
  }
  return path;
}

/// Reads file bytes from a [PlatformFile], including mobile where [PlatformFile.bytes] is null.
Future<Uint8List?> readPlatformFileBytes(PlatformFile file) async {
  if (file.bytes != null && file.bytes!.isNotEmpty) {
    return file.bytes;
  }
  if (!kIsWeb) {
    final path = normalizePickerPath(file.path);
    if (path.isNotEmpty) {
      return File(path).readAsBytes();
    }
  }
  try {
    return await file.xFile.readAsBytes();
  } catch (_) {
    return null;
  }
}
