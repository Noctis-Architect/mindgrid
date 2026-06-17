import 'dart:convert';
import 'dart:io';

import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/file_picker_utils.dart';
import '../core/platform_file_picker.dart';
import '../core/hover_surface.dart';
import '../core/text_direction.dart';
import '../l10n/l10n.dart';
import '../models/chat_models.dart';
import '../services/audio_recorder_service.dart';
import '../services/model_capabilities.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class ChatInputArea extends StatefulWidget {
  const ChatInputArea({super.key});

  @override
  State<ChatInputArea> createState() => ChatInputAreaState();
}

class ChatInputAreaState extends State<ChatInputArea> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _recorder = AudioRecorderService();
  bool _dragOver = false;
  bool _recording = false;
  bool _recorderBusy = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  @override
  void dispose() {
    _recordTimer?.cancel();
    _recorder.dispose();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void setText(String text) {
    _controller.text = text;
    _focus.requestFocus();
    setState(() {});
  }

  static const _textExtensions = {
    'txt', 'md', 'py', 'js', 'ts', 'jsx', 'tsx', 'html', 'css',
    'json', 'yaml', 'yml', 'csv', 'xml', 'sh', 'bash', 'c', 'cpp',
    'h', 'java', 'go', 'rs', 'php', 'rb', 'sql',
  };

  Future<void> _addFile(String name, String content) async {
    final state = context.read<AppState>();
    final s = state.strings;
    if (content.length > 500000) {
      state.showToast(s.fileTooLarge(name), type: ToastType.err);
      return;
    }
    state.addAttachedFile(AttachedFile(name: name, content: content));
    setState(() {});
  }

  static const _maxImageBytes = 10 * 1024 * 1024;

  Future<void> _addImage(String name, Uint8List bytes, String mimeType) async {
    final state = context.read<AppState>();
    final s = state.strings;
    if (bytes.length > _maxImageBytes) {
      state.showToast(s.fileTooLargeMax(name), type: ToastType.err);
      return;
    }
    state.addAttachedImage(
      AttachedImage(name: name, mimeType: mimeType, bytes: bytes),
    );
    setState(() {});
  }

  Future<void> _pickImages() async {
    final state = context.read<AppState>();
    final s = state.strings;
    try {
      final result = await PlatformFilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.image,
        withData: kIsWeb || !(Platform.isAndroid || Platform.isIOS),
      );
      if (result == null || !mounted) return;
      for (final f in result.files) {
        final ext = ModelCapabilities.extensionFromName(f.name);
        final mime = (ext != null
                ? ModelCapabilities.mimeFromExtension(ext)
                : null) ??
            'image/jpeg';
        final bytes = await readPlatformFileBytes(f);
        if (!mounted) return;
        if (bytes == null || bytes.isEmpty) {
          state.showToast(s.readImageFailed(f.name), type: ToastType.err);
          continue;
        }
        await _addImage(f.name, bytes, mime);
      }
      if (state.attachedImages.isNotEmpty && !state.selectedModelSupportsVision) {
        state.showToast(s.selectVisionModel, type: ToastType.info);
      }
    } catch (e) {
      if (!mounted) return;
      state.showToast(s.readImageFailed('$e'), type: ToastType.err);
    }
  }

  Future<void> _handleDroppedFiles(List<XFile> files) async {
    final state = context.read<AppState>();
    final s = state.strings;
    for (final f in files) {
      final ext = ModelCapabilities.extensionFromName(f.name);
      final mime = ext != null ? ModelCapabilities.mimeFromExtension(ext) : null;
      if (mime != null && state.selectedModelSupportsVision) {
        final bytes = await f.readAsBytes();
        if (!mounted) return;
        if (bytes.length > _maxImageBytes) {
          state.showToast(s.fileTooLargeMax(f.name), type: ToastType.err);
          continue;
        }
        await _addImage(f.name, bytes, mime);
        continue;
      }
      if (!_textExtensions.contains(ext ?? '')) {
        state.showToast(s.dropFileError(f.name), type: ToastType.err);
        continue;
      }
      final content = await f.readAsString();
      if (!mounted) return;
      await _addFile(f.name, content);
    }
  }

  Future<void> _pickFiles() async {
    final state = context.read<AppState>();
    final s = state.strings;
    final result = await PlatformFilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: _textExtensions.toList(),
      withData: kIsWeb || !(Platform.isAndroid || Platform.isIOS),
    );
    if (result == null || !mounted) return;
    for (final f in result.files) {
      final bytes = await readPlatformFileBytes(f);
      if (!mounted) return;
      if (bytes == null || bytes.isEmpty) {
        state.showToast(s.readImageFailed(f.name), type: ToastType.err);
        continue;
      }
      if (bytes.length > 500000) {
        state.showToast(s.fileTooLarge(f.name), type: ToastType.err);
        continue;
      }
      final content = utf8.decode(bytes, allowMalformed: true);
      if (!mounted) return;
      await _addFile(f.name, content);
    }
  }

  Future<void> _toggleRecording() async {
    final state = context.read<AppState>();
    final s = state.strings;
    if (_recorderBusy) return;

    if (_recording) {
      setState(() => _recorderBusy = true);
      try {
        final bytes = await _recorder.stop(s);
        _recordTimer?.cancel();
        _recordTimer = null;
        if (!mounted) return;
        setState(() {
          _recording = false;
          _recordSeconds = 0;
          _recorderBusy = false;
        });
        state.setAttachedAudio(
          AttachedAudio(
            name: 'voice_${DateTime.now().millisecondsSinceEpoch}.wav',
            bytes: bytes,
            durationMs: _recordSeconds * 1000,
          ),
        );
        state.showToast(s.audioSaved, type: ToastType.ok);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _recording = false;
          _recordSeconds = 0;
          _recorderBusy = false;
        });
        state.showToast('$e', type: ToastType.err);
      }
      return;
    }

    if (!_recorder.isSupported) {
      state.showToast(s.audioNotSupported, type: ToastType.err);
      return;
    }
    if (!state.selectedModelSupportsAudio) {
      state.showToast(s.selectAudioModel, type: ToastType.info);
      return;
    }

    setState(() => _recorderBusy = true);
    try {
      await _recorder.start(s);
      if (!mounted) return;
      setState(() {
        _recording = true;
        _recorderBusy = false;
        _recordSeconds = 0;
      });
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recordSeconds += 1);
        if (_recordSeconds >= 30) {
          _toggleRecording();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _recorderBusy = false);
      state.showToast('$e', type: ToastType.err);
    }
  }

  void _submit() {
    final state = context.read<AppState>();
    final s = state.strings;
    if (state.isStreaming) {
      state.stopStreaming();
      return;
    }
    var text = _controller.text;
    if (text.trim().isEmpty && state.attachedAudio != null) {
      text = s.processAudioFile;
    }
    if (text.trim().isEmpty &&
        state.attachedFiles.isEmpty &&
        state.attachedImages.isEmpty &&
        state.attachedAudio == null) {
      return;
    }
    state.sendMessage(text);
    _controller.clear();
    setState(() {});
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed) {
      final value = _controller.value;
      final sel = value.selection;
      final text = value.text;
      final pos = sel.baseOffset;
      final next = '${text.substring(0, pos)}\n${text.substring(pos)}';
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: pos + 1),
      );
      return KeyEventResult.handled;
    }
    if (!context.read<AppState>().isStreaming) {
      _submit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool get _dropEnabled =>
      !kIsWeb &&
      (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = context.s;
    final mobile = MediaQuery.sizeOf(context).width < mobileBreakpoint;
    final canSend = state.isStreaming ||
        _controller.text.trim().isNotEmpty ||
        state.attachedFiles.isNotEmpty ||
        state.attachedImages.isNotEmpty ||
        state.attachedAudio != null;

    Widget content = Container(
      padding: EdgeInsets.fromLTRB(
        mobile ? 10 : 16,
        10,
        mobile ? 10 : 16,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgApp,
        border: Border(
          top: BorderSide(
            color: _dragOver
                ? AppColors.accent.withValues(alpha: 0.5)
                : AppColors.border,
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.attachedFiles.isNotEmpty ||
                  state.attachedImages.isNotEmpty ||
                  state.attachedAudio != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...List.generate(state.attachedFiles.length, (i) {
                        final f = state.attachedFiles[i];
                        return _AttachedFileChip(
                          name: f.name,
                          onDelete: () => state.removeAttachedFile(i),
                        );
                      }),
                      ...List.generate(state.attachedImages.length, (i) {
                        final img = state.attachedImages[i];
                        return _AttachedImageChip(
                          image: img,
                          onDelete: () => state.removeAttachedImage(i),
                        );
                      }),
                      if (state.attachedAudio != null)
                        _AttachedAudioChip(
                          audio: state.attachedAudio!,
                          onDelete: state.clearAttachedAudio,
                        ),
                    ],
                  ),
                ),
              if (_recording)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RecordingBanner(seconds: _recordSeconds, label: s.recordingProgress),
                ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bgPanel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _dragOver
                        ? AppColors.accent.withValues(alpha: 0.6)
                        : AppColors.borderMd,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Focus(
                      onKeyEvent: _onKey,
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        maxLines: 8,
                        minLines: 1,
                        textDirection: textDirectionFor(
                          _controller.text,
                          localeDefault: localeTextDirection(state.locale),
                        ),
                        textAlign: textAlignFor(
                          _controller.text,
                          localeDefault: localeTextDirection(state.locale),
                        ),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: state.isOllama ? s.inputHintOllama : s.inputHint,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        ),
                        style: const TextStyle(
                          color: AppColors.text1,
                          fontSize: 14,
                          height: 1.55,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _InputIconButton(
                            icon: Icons.attach_file_rounded,
                            onPressed: _pickFiles,
                            tooltip: s.attachFile,
                          ),
                          _InputIconButton(
                            icon: Icons.image_outlined,
                            onPressed: _pickImages,
                            tooltip: state.selectedModelSupportsVision
                                ? s.attachImage
                                : s.attachImageNeedsVision,
                          ),
                          if (state.isOllama)
                            _InputIconButton(
                              icon: Icons.lightbulb_outline_rounded,
                              onPressed: state.toggleThink,
                              tooltip: state.settings.thinkEnabled
                                  ? s.thinkingOn
                                  : s.thinkingOff,
                              active: state.settings.thinkEnabled,
                            ),
                          if (state.isOllama && _recorder.isSupported)
                            _MicButton(
                              recording: _recording,
                              busy: _recorderBusy,
                              enabled: state.selectedModelSupportsAudio,
                              onPressed: _toggleRecording,
                            ),
                          const Spacer(),
                          _SendButton(
                            streaming: state.isStreaming,
                            enabled: canSend,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                s.disclaimer,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.text4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    if (_dropEnabled) {
      content = DropTarget(
        onDragEntered: (_) => setState(() => _dragOver = true),
        onDragExited: (_) => setState(() => _dragOver = false),
        onDragDone: (detail) {
          setState(() => _dragOver = false);
          _handleDroppedFiles(detail.files);
        },
        child: content,
      );
    }

    return content;
  }
}

class _InputIconButton extends StatelessWidget {
  const _InputIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return HoverIconButton(
      icon: icon,
      onPressed: onPressed,
      tooltip: tooltip,
      active: active,
    );
  }
}

class _SendButton extends StatefulWidget {
  const _SendButton({
    required this.streaming,
    required this.enabled,
    required this.onPressed,
  });

  final bool streaming;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.streaming ? AppColors.red : AppColors.accent;
    final canAct = widget.enabled;

    return MouseRegion(
      onEnter: canAct ? (_) => setState(() => _hovered = true) : null,
      onExit: canAct ? (_) => setState(() => _hovered = false) : null,
      child: GestureDetector(
        onTap: canAct ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: AppHover.duration,
          curve: AppHover.curve,
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: canAct
                ? (widget.streaming
                    ? (_hovered ? AppColors.red.withValues(alpha: 0.85) : AppColors.red)
                    : (_hovered ? AppColors.accentDim : AppColors.accent))
                : AppColors.bgHover,
            borderRadius: BorderRadius.circular(10),
            boxShadow: canAct && _hovered
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            widget.streaming ? Icons.stop_rounded : Icons.arrow_upward_rounded,
            size: 17,
            color: canAct ? Colors.white : AppColors.text4,
          ),
        ),
      ),
    );
  }
}

class _MicButton extends StatefulWidget {
  const _MicButton({
    required this.recording,
    required this.busy,
    required this.enabled,
    required this.onPressed,
  });

  final bool recording;
  final bool busy;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didUpdateWidget(covariant _MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recording) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.recording;
    final color = active ? AppColors.red : AppColors.yellow;
    final canAct = widget.enabled && !widget.busy;

    return Tooltip(
      message: widget.enabled
          ? (active ? context.s.stopRecording : context.s.recordAudio)
          : context.s.recordAudioNeedsModel,
      child: MouseRegion(
        cursor: canAct ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: canAct ? widget.onPressed : null,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final glow = active ? 0.25 + _pulse.value * 0.35 : 0.0;
              return Container(
                width: 34,
                height: 34,
                margin: const EdgeInsets.only(left: 2),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.red.withValues(alpha: 0.15 + glow)
                      : (canAct
                          ? AppColors.yellow.withValues(alpha: 0.12)
                          : AppColors.bgHover),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: active
                        ? AppColors.red.withValues(alpha: 0.7)
                        : (canAct
                            ? AppColors.yellow.withValues(alpha: 0.45)
                            : AppColors.border),
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: AppColors.red.withValues(alpha: glow),
                            blurRadius: 14,
                          ),
                        ]
                      : null,
                ),
                child: widget.busy
                    ? const Center(
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Icon(
                        active ? Icons.stop_rounded : Icons.mic_rounded,
                        size: 17,
                        color: canAct ? color : AppColors.text4,
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RecordingBanner extends StatelessWidget {
  const _RecordingBanner({required this.seconds, required this.label});

  final int seconds;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label ${seconds}s / 30s',
            style: const TextStyle(
              color: AppColors.red,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachedAudioChip extends StatelessWidget {
  const _AttachedAudioChip({required this.audio, required this.onDelete});

  final AttachedAudio audio;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final duration = audio.durationMs != null
        ? '${(audio.durationMs! / 1000).toStringAsFixed(0)}s'
        : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.yellow.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.yellow.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mic_rounded, size: 12, color: AppColors.yellow),
          const SizedBox(width: 6),
          Text(
            s.audioFileLabel(duration),
            style: const TextStyle(fontSize: 12, color: AppColors.text2),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close, size: 12, color: AppColors.text4),
          ),
        ],
      ),
    );
  }
}

class _AttachedImageChip extends StatelessWidget {
  const _AttachedImageChip({required this.image, required this.onDelete});
  final AttachedImage image;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgHover,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
            child: Image.memory(
              Uint8List.fromList(image.bytes),
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              image.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.text2),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDelete,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close, size: 12, color: AppColors.text4),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachedFileChip extends StatelessWidget {
  const _AttachedFileChip({required this.name, required this.onDelete});
  final String name;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.bgHover,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file_outlined,
              size: 12, color: AppColors.text3),
          const SizedBox(width: 6),
          Text(name,
              style: const TextStyle(fontSize: 12, color: AppColors.text2)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close, size: 12, color: AppColors.text4),
          ),
        ],
      ),
    );
  }
}
