import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridge to the native runner for the custom (Dart-drawn) title bar.
///
/// Linux and Windows remove the system caption in their runners and expose
/// move / resize / minimize / maximize / close over this channel.
class WindowChrome {
  WindowChrome._();

  static const _channel = MethodChannel('mindgrid/window');

  /// True on platforms where the app draws its own title bar.
  static bool get enabled =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows);

  /// Windows keeps no top resize border once the caption is gone, so the
  /// title bar provides one. GTK supplies its own on Linux.
  static bool get needsTopResizeHandle => !kIsWeb && Platform.isWindows;

  static Future<void> _call(String method, [Object? args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // Running under tests or an older runner.
    } on PlatformException {
      // Ignore: window controls are best-effort.
    }
  }

  static Future<void> startDrag() => _call('startDrag');
  static Future<void> startResize(String edge) => _call('startResize', edge);
  static Future<void> minimize() => _call('minimize');
  static Future<void> toggleMaximize() => _call('toggleMaximize');
  static Future<void> close() => _call('close');

  static Future<bool> isMaximized() async {
    try {
      return await _channel.invokeMethod<bool>('isMaximized') ?? false;
    } catch (_) {
      return false;
    }
  }
}
