import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'file_picker_utils.dart';

/// Picks files with [file_picker], falling back to native GTK dialogs on Linux
/// when zenity/kdialog/qarma are not installed.
class PlatformFilePicker {
  static Future<bool> _linuxHasCliDialogTool() async {
    for (final tool in ['qarma', 'kdialog', 'zenity']) {
      final result = await Process.run('which', [tool]);
      if (result.exitCode == 0) return true;
    }
    return false;
  }

  static bool get _isLinuxDesktop => !kIsWeb && Platform.isLinux;

  static Future<bool> _shouldUseFileSelector() async {
    if (!_isLinuxDesktop) return false;
    return !(await _linuxHasCliDialogTool());
  }

  static List<XTypeGroup> _typeGroupsFor(
    FileType type,
    List<String>? allowedExtensions,
  ) {
    switch (type) {
      case FileType.image:
        return const [
          XTypeGroup(
            label: 'images',
            extensions: ['bmp', 'gif', 'jpeg', 'jpg', 'png', 'webp'],
          ),
        ];
      case FileType.custom:
        if (allowedExtensions == null || allowedExtensions.isEmpty) {
          return const [];
        }
        return [
          XTypeGroup(
            label: 'files',
            extensions: allowedExtensions,
          ),
        ];
      default:
        return const [];
    }
  }

  static Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
    bool withData = false,
  }) async {
    if (await _shouldUseFileSelector()) {
      return _pickWithFileSelector(
        dialogTitle: dialogTitle,
        type: type,
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
        withData: withData,
      );
    }

    try {
      return await FilePicker.platform.pickFiles(
        dialogTitle: dialogTitle,
        type: type,
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
        withData: withData,
      );
    } catch (_) {
      if (!_isLinuxDesktop) rethrow;
      return _pickWithFileSelector(
        dialogTitle: dialogTitle,
        type: type,
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
        withData: withData,
      );
    }
  }

  static Future<FilePickerResult?> _pickWithFileSelector({
    String? dialogTitle,
    required FileType type,
    List<String>? allowedExtensions,
    required bool allowMultiple,
    required bool withData,
  }) async {
    final groups = _typeGroupsFor(type, allowedExtensions);
    final List<XFile> xFiles;
    if (allowMultiple) {
      xFiles = await openFiles(
        acceptedTypeGroups: groups,
        confirmButtonText: dialogTitle,
      );
    } else {
      final file = await openFile(
        acceptedTypeGroups: groups,
        confirmButtonText: dialogTitle,
      );
      xFiles = file == null ? [] : [file];
    }

    if (xFiles.isEmpty) return null;

    final platformFiles = await Future.wait(
      xFiles.map((file) async {
        final path = normalizePickerPath(file.path);
        final name = file.name.isNotEmpty ? file.name : p.basename(path);
        final bytes = withData ? await file.readAsBytes() : null;
        return PlatformFile(
          name: name,
          path: path.isEmpty ? file.path : path,
          size: bytes?.length ?? await file.length(),
          bytes: bytes,
        );
      }),
    );

    return FilePickerResult(platformFiles);
  }

  static Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
  }) async {
    if (await _shouldUseFileSelector()) {
      return _saveWithFileSelector(
        dialogTitle: dialogTitle,
        fileName: fileName,
        type: type,
        allowedExtensions: allowedExtensions,
      );
    }

    try {
      return await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: fileName,
        type: type,
        allowedExtensions: allowedExtensions,
      );
    } catch (_) {
      if (!_isLinuxDesktop) rethrow;
      return _saveWithFileSelector(
        dialogTitle: dialogTitle,
        fileName: fileName,
        type: type,
        allowedExtensions: allowedExtensions,
      );
    }
  }

  static Future<String?> _saveWithFileSelector({
    String? dialogTitle,
    String? fileName,
    required FileType type,
    List<String>? allowedExtensions,
  }) async {
    final location = await getSaveLocation(
      acceptedTypeGroups: _typeGroupsFor(type, allowedExtensions),
      suggestedName: fileName,
      confirmButtonText: dialogTitle,
    );
    return location?.path;
  }
}
