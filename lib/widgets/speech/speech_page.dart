import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/file_picker_utils.dart';
import '../../core/hover_surface.dart';
import '../../core/motion.dart';
import '../../core/platform_file_picker.dart';
import '../../core/text_direction.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/l10n.dart';
import '../../models/ollama_models.dart';
import '../../services/audio_recorder_service.dart';
import '../../services/hf_service.dart';
import '../../services/model_hub_controller.dart';
import '../../services/whisper_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../model_hub/hub_widgets.dart';
import '../model_hub/modelfile_editor.dart' show hubMono;

/// Speech section: local speech-to-text through whisper.cpp.
class SpeechPage extends StatefulWidget {
  const SpeechPage({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<SpeechPage> createState() => _SpeechPageState();
}

class _SpeechPageState extends State<SpeechPage> {
  late final WhisperService _w;
  late final ModelHubController _hub;
  final _recorder = AudioRecorderService();
  final _remote = TextEditingController();

  bool _recording = false;
  bool _busy = false;
  int _seconds = 0;
  Timer? _timer;
  String _transcript = '';
  String? _tryError;
  bool? _remoteOk;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _w = state.whisper;
    _hub = state.hub;
    _w.addListener(_changed);
    _hub.addListener(_changed);
    _w.load().then((_) {
      if (mounted) _remote.text = _w.remoteUrl;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _w.removeListener(_changed);
    _hub.removeListener(_changed);
    _recorder.dispose();
    _remote.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _toast(String text, {ToastType type = ToastType.info}) {
    context.read<AppState>().showToast(text, type: type);
  }

  Future<void> _toggleEngine() async {
    if (_w.status == WhisperStatus.running ||
        _w.status == WhisperStatus.starting) {
      await _w.stop();
      return;
    }
    try {
      await _w.start();
    } catch (e) {
      if (mounted) _toast('$e', type: ToastType.err);
    }
  }

  Future<void> _chooseBinary() async {
    final result = await PlatformFilePicker.pickFiles(
      dialogTitle: context.sRead.speechChooseBinary,
      type: FileType.any,
    );
    final path = normalizePickerPath(result?.files.firstOrNull?.path);
    if (path.isEmpty) return;
    _w.binaryPath = path;
    await _w.save();
    await _w.refresh();
  }

  Future<void> _addModelFile() async {
    final result = await PlatformFilePicker.pickFiles(
      dialogTitle: context.sRead.speechAddModelFile,
      type: FileType.any,
    );
    final path = normalizePickerPath(result?.files.firstOrNull?.path);
    if (path.isEmpty) return;
    await _w.addExternalModel(path);
  }

  Future<void> _download(WhisperCatalogModel m) async {
    final hf = await HfSettings.load();
    final dir = await WhisperService.modelsDir();
    _hub.enqueueWhisperModel(
      name: 'whisper ${m.id}',
      url: HfService.fileUrl(
        hf,
        const HfRef(repo: WhisperService.repo),
        m.fileName,
      ),
      destPath: p.join(dir.path, m.fileName),
    );
  }

  HubTask? _taskFor(WhisperCatalogModel m) {
    for (final t in _hub.tasks) {
      if (t.kind == HubTaskKind.whisperModel &&
          t.fileName == m.fileName &&
          t.stage != HubTaskStage.completed) {
        return t;
      }
    }
    return null;
  }

  Future<void> _run(Future<String> Function() job) async {
    setState(() {
      _busy = true;
      _tryError = null;
    });
    try {
      final text = await job();
      if (!mounted) return;
      setState(() => _transcript = text);
    } catch (e) {
      if (mounted) setState(() => _tryError = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleRecord() async {
    final s = context.sRead;
    if (_busy) return;
    if (_recording) {
      _timer?.cancel();
      setState(() => _recording = false);
      try {
        final bytes = await _recorder.stop(s);
        await _run(() => _w.transcribe(bytes));
      } catch (e) {
        if (mounted) setState(() => _tryError = '$e');
      }
      return;
    }
    try {
      await _recorder.start(s);
      if (!mounted) return;
      setState(() {
        _recording = true;
        _seconds = 0;
        _tryError = null;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds++);
        if (_seconds >= 300) _toggleRecord();
      });
    } catch (e) {
      if (mounted) setState(() => _tryError = '$e');
    }
  }

  Future<void> _pickAudio() async {
    final result = await PlatformFilePicker.pickFiles(
      dialogTitle: context.sRead.speechPickAudio,
      type: FileType.any,
    );
    final path = normalizePickerPath(result?.files.firstOrNull?.path);
    if (path.isEmpty) return;
    await _run(() => _w.transcribeFile(path));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final mobile = MediaQuery.sizeOf(context).width < mobileBreakpoint;
    final local = _w.effectiveMode == WhisperMode.local;

    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(mobile ? 14 : 28, 18, 12, 6),
            child: Row(
              children: [
                const Icon(Icons.graphic_eq_rounded,
                    color: AppColors.accent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.speechTitle,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text1,
                        ),
                      ),
                      Text(
                        s.speechSubtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.text3),
                      ),
                    ],
                  ),
                ),
                if (mobile)
                  HoverIconButton(
                    icon: Icons.close_rounded,
                    tooltip: s.close,
                    onPressed: widget.onClose,
                  ),
              ],
            ),
          ),
          Expanded(
            child: !_w.loaded
                ? const Center(
                    child: SizedBox(
                        width: 140, child: SmoothProgressBar(height: 3)),
                  )
                : ListView(
                    padding: EdgeInsets.fromLTRB(
                        mobile ? 14 : 28, 12, mobile ? 14 : 28, 28),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 860),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FadeSlideIn(child: _tryCard(s)),
                              const SizedBox(height: 14),
                              FadeSlideIn(
                                delay: const Duration(milliseconds: 50),
                                child: _engineCard(s, local),
                              ),
                              if (local) ...[
                                const SizedBox(height: 14),
                                FadeSlideIn(
                                  delay: const Duration(milliseconds: 100),
                                  child: _modelsCard(s),
                                ),
                              ],
                              const SizedBox(height: 14),
                              FadeSlideIn(
                                delay: const Duration(milliseconds: 150),
                                child: _optionsCard(s),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.info_outline_rounded,
                                      size: 14, color: AppColors.text4),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      s.speechTtsNote,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.text4,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── Try it ────────────────────────────────────────────────────────────────

  Widget _tryCard(AppStrings s) {
    final ready = _w.canTranscribe;
    final mm = (_seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (_seconds % 60).toString().padLeft(2, '0');
    return HubCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _RecordButton(
                recording: _recording,
                busy: _busy,
                enabled: ready && _recorder.isSupported,
                onTap: _toggleRecord,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _recording
                          ? '${s.speechStopRecording}  $mm:$ss'
                          : _busy
                              ? s.speechTranscribing
                              : s.speechRecord,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text1,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ready ? s.speechTryHint : s.speechNeedSetup,
                      style: TextStyle(
                        fontSize: 12,
                        color: ready ? AppColors.text3 : AppColors.yellow,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: ready && !_busy && !_recording ? _pickAudio : null,
                icon: const Icon(Icons.audio_file_outlined, size: 16),
                label: Text(s.speechPickAudio),
              ),
            ],
          ),
          AnimatedSize(
            duration: AppMotion.slow,
            curve: AppMotion.emphasized,
            alignment: Alignment.topCenter,
            child: _busy
                ? const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: SmoothProgressBar(height: 3),
                  )
                : _tryError != null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          _tryError!,
                          style: const TextStyle(
                              color: AppColors.red, fontSize: 12.5),
                        ),
                      )
                    : _transcript.isEmpty
                        ? const SizedBox(width: double.infinity)
                        : Container(
                            margin: const EdgeInsets.only(top: 14),
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                14, 10, 6, 10),
                            decoration: BoxDecoration(
                              color: AppColors.bgCode,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    _transcript,
                                    textDirection:
                                        detectTextDirection(_transcript),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.7,
                                      color: AppColors.text1,
                                    ),
                                  ),
                                ),
                                HoverIconButton(
                                  icon: Icons.copy_rounded,
                                  tooltip: s.copy,
                                  iconSize: 14,
                                  onPressed: () {
                                    Clipboard.setData(
                                        ClipboardData(text: _transcript));
                                    _toast(s.copied, type: ToastType.ok);
                                  },
                                ),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  // ── Engine ────────────────────────────────────────────────────────────────

  Widget _engineCard(AppStrings s, bool local) {
    final (dot, label) = switch (_w.status) {
      WhisperStatus.running => (
          AppColors.green,
          s.speechRunning(
            p.basename(_w.runningModel ?? '')
                .replaceFirst('ggml-', '')
                .replaceFirst('.bin', ''),
          ),
        ),
      WhisperStatus.starting => (AppColors.yellow, s.speechStarting),
      WhisperStatus.error => (AppColors.red, _w.error ?? s.genericError),
      WhisperStatus.stopped => (AppColors.text4, s.speechStopped),
    };
    final active = _w.status == WhisperStatus.running ||
        _w.status == WhisperStatus.starting;

    return HubCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: HubSectionTitle(s.speechEngine)),
              if (_w.supportsLocalEngine)
                _Segmented(
                  value: _w.mode == WhisperMode.local ? 0 : 1,
                  labels: [s.speechLocal, s.speechRemote],
                  onChanged: (i) async {
                    if (i == 1) await _w.stop();
                    _w.mode = i == 0 ? WhisperMode.local : WhisperMode.remote;
                    await _w.save();
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (local) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: AnimatedContainer(
                    duration: AppMotion.base,
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: dot, shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: _w.status == WhisperStatus.error
                          ? AppColors.red
                          : AppColors.text1,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _w.resolvedBinary == null || _w.modelPath.isEmpty
                      ? null
                      : _toggleEngine,
                  style: active
                      ? FilledButton.styleFrom(
                          backgroundColor: AppColors.bgActive,
                          foregroundColor: AppColors.text1,
                        )
                      : null,
                  icon: Icon(
                    active ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    size: 17,
                  ),
                  label: Text(active ? s.speechStop : s.speechStart),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _w.resolvedBinary == null
                      ? Icons.warning_amber_rounded
                      : Icons.terminal_rounded,
                  size: 15,
                  color: _w.resolvedBinary == null
                      ? AppColors.yellow
                      : AppColors.text3,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Directionality(
                    textDirection: _w.resolvedBinary == null
                        ? Directionality.of(context)
                        : TextDirection.ltr,
                    child: Text(
                      _w.resolvedBinary ?? s.speechBinaryNotFound,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _w.resolvedBinary == null
                          ? const TextStyle(
                              fontSize: 12.5, color: AppColors.yellow)
                          : hubMono.copyWith(fontSize: 11.5),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _chooseBinary,
                  child: Text(s.speechChooseBinary),
                ),
              ],
            ),
            if (_w.resolvedBinary == null) ...[
              const SizedBox(height: 8),
              Text(
                s.speechBinaryHelp,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.text3,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 8),
              const _CodeLine(
                'git clone https://github.com/ggml-org/whisper.cpp && cd whisper.cpp && '
                'cmake -B build -DBUILD_SHARED_LIBS=OFF && cmake --build build -j --config Release',
              ),
            ],
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: TextField(
                      controller: _remote,
                      style: hubMono.copyWith(color: AppColors.text1),
                      decoration: InputDecoration(
                        labelText: s.speechRemoteUrl,
                        hintText: 'http://192.168.1.10:8080',
                      ),
                      onChanged: (v) {
                        _w.remoteUrl = v;
                        _remoteOk = null;
                        _w.save();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () async {
                    final ok = await _w.testRemote();
                    if (mounted) setState(() => _remoteOk = ok);
                  },
                  child: Text(s.speechTest),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _remoteOk == null
                  ? s.speechRemoteHelp
                  : _remoteOk!
                      ? s.speechRemoteOk
                      : s.speechRemoteFail,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: _remoteOk == null
                    ? AppColors.text3
                    : _remoteOk!
                        ? AppColors.green
                        : AppColors.red,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Models ────────────────────────────────────────────────────────────────

  Widget _modelsCard(AppStrings s) {
    final installedNames = _w.models.map((m) => m.fileName).toSet();
    return HubCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HubSectionTitle(
            s.speechModels,
            trailing: TextButton.icon(
              onPressed: _addModelFile,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(s.speechAddModelFile),
            ),
          ),
          const SizedBox(height: 8),
          if (_w.models.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                s.speechNoModels,
                style: const TextStyle(fontSize: 12.5, color: AppColors.text3),
              ),
            )
          else
            for (final m in _w.models)
              _ModelRow(
                model: m,
                selected: m.path == _w.modelPath,
                onSelect: () => _w.selectModel(m.path),
                onDelete: () => _w.removeModel(m),
                deleteTooltip: s.delete,
              ),
          const SizedBox(height: 14),
          HubSectionTitle(s.speechCatalog),
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in WhisperService.catalog)
                  _CatalogChip(
                    model: m,
                    installed: installedNames.contains(m.fileName),
                    task: _taskFor(m),
                    onTap: () => _download(m),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            s.speechCatalogHelp,
            style: const TextStyle(
                fontSize: 11.5, color: AppColors.text4, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ── Options ───────────────────────────────────────────────────────────────

  Widget _optionsCard(AppStrings s) {
    Widget row(String title, String? subtitle, Widget control) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 13.5, color: AppColors.text1)),
                    if (subtitle != null)
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.text3)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              control,
            ],
          ),
        );

    return HubCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HubSectionTitle(s.speechOptions),
          const SizedBox(height: 6),
          row(
            s.speechLanguage,
            s.speechLanguageHelp,
            SizedBox(
              width: 170,
              child: DropdownButtonFormField<String>(
                key: ValueKey(_w.language),
                initialValue: WhisperService.languages.containsKey(_w.language)
                    ? _w.language
                    : 'auto',
                isDense: true,
                isExpanded: true,
                dropdownColor: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(AppRadius.md),
                style: const TextStyle(fontSize: 13, color: AppColors.text1),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                ),
                items: [
                  for (final e in WhisperService.languages.entries)
                    DropdownMenuItem(
                      value: e.key,
                      child: Text(e.key == 'auto' ? s.speechAuto : e.value),
                    ),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  _w.language = v;
                  await _w.save();
                },
              ),
            ),
          ),
          row(
            s.speechTranslate,
            s.speechTranslateHelp,
            Switch(
              value: _w.translate,
              onChanged: (v) {
                _w.translate = v;
                _w.save();
              },
            ),
          ),
          row(
            s.speechDictation,
            s.speechDictationHelp,
            Switch(
              value: _w.dictation,
              onChanged: (v) {
                _w.dictation = v;
                _w.save();
              },
            ),
          ),
          if (_w.effectiveMode == WhisperMode.local)
            row(
              s.speechThreads,
              null,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HoverIconButton(
                    icon: Icons.remove_rounded,
                    enabled: _w.threads > 1,
                    onPressed: () {
                      _w.threads--;
                      _w.save();
                    },
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${_w.threads}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text1,
                      ),
                    ),
                  ),
                  HoverIconButton(
                    icon: Icons.add_rounded,
                    enabled: _w.threads < 32,
                    onPressed: () {
                      _w.threads++;
                      _w.save();
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RecordButton extends StatefulWidget {
  const _RecordButton({
    required this.recording,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final bool recording;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<_RecordButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didUpdateWidget(covariant _RecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recording && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.recording && _pulse.isAnimating) {
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
    final can = widget.enabled && !widget.busy;
    final color = widget.recording ? AppColors.red : AppColors.accent;
    return Pressable(
      enabled: can,
      scale: 0.92,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: can ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) => Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: can ? color : AppColors.bgActive,
              boxShadow: widget.recording
                  ? [
                      BoxShadow(
                        color: AppColors.red
                            .withValues(alpha: 0.25 + 0.3 * _pulse.value),
                        blurRadius: 10 + 14 * _pulse.value,
                        spreadRadius: 2 * _pulse.value,
                      ),
                    ]
                  : const [],
            ),
            child: child,
          ),
          child: widget.busy
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.text2,
                  ),
                )
              : AnimatedSwitcher(
                  duration: AppMotion.base,
                  transitionBuilder: (c, a) =>
                      ScaleTransition(scale: a, child: c),
                  child: Icon(
                    widget.recording ? Icons.stop_rounded : Icons.mic_rounded,
                    key: ValueKey(widget.recording),
                    size: 24,
                    color: can ? Colors.white : AppColors.text4,
                  ),
                ),
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.value,
    required this.labels,
    required this.onChanged,
  });

  final int value;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.bgCode,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            HoverSurface(
              onTap: () => onChanged(i),
              builder: (context, hovered) => AnimatedContainer(
                duration: AppMotion.base,
                curve: AppMotion.emphasized,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: value == i ? AppColors.bgActive : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: value == i
                        ? AppColors.text1
                        : hovered
                            ? AppColors.text2
                            : AppColors.text3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.model,
    required this.selected,
    required this.onSelect,
    required this.onDelete,
    required this.deleteTooltip,
  });

  final WhisperLocalModel model;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  final String deleteTooltip;

  @override
  Widget build(BuildContext context) {
    return HoverSurface(
      onTap: onSelect,
      builder: (context, hovered) => AnimatedContainer(
        duration: AppHover.duration,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 4, 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accentGlow
              : hovered
                  ? AppColors.bgHover
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.hoverBorder : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: AppMotion.base,
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.accent : AppColors.text4,
                  width: selected ? 5 : 1.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  model.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text1,
                  ),
                ),
              ),
            ),
            HubTag(formatBytes(model.size)),
            HoverIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: deleteTooltip,
              iconSize: 15,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogChip extends StatelessWidget {
  const _CatalogChip({
    required this.model,
    required this.installed,
    required this.task,
    required this.onTap,
  });

  final WhisperCatalogModel model;
  final bool installed;
  final HubTask? task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final busy = task != null;
    final pct = task?.fraction == null ? null : (task!.fraction! * 100).floor();
    final size = model.approxMb >= 1000
        ? '${(model.approxMb / 1000).toStringAsFixed(1)} GB'
        : '${model.approxMb} MB';
    return HoverSurface(
      enabled: !installed && !busy,
      onTap: installed || busy ? null : onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: AppHover.duration,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: installed
              ? AppColors.green.withValues(alpha: 0.08)
              : busy
                  ? AppColors.accentGlow
                  : hovered
                      ? AppColors.bgActive
                      : AppColors.bgHover,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: installed
                ? AppColors.green.withValues(alpha: 0.3)
                : busy
                    ? AppColors.hoverBorder
                    : hovered
                        ? AppColors.borderFocus
                        : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              )
            else
              Icon(
                installed ? Icons.check_rounded : Icons.download_rounded,
                size: 14,
                color: installed
                    ? AppColors.green
                    : hovered
                        ? AppColors.accent
                        : AppColors.text3,
              ),
            const SizedBox(width: 8),
            Text(
              model.id,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: installed ? AppColors.green : AppColors.text1,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              pct != null ? '$pct%' : '~$size',
              style: TextStyle(
                fontSize: 11,
                color: pct != null ? AppColors.accent : AppColors.text4,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeLine extends StatelessWidget {
  const _CodeLine(this.code);
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.bgCode,
        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
        border: Border.all(color: AppColors.border),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            Expanded(
              child: SelectableText(code,
                  style: hubMono.copyWith(fontSize: 11.5)),
            ),
            HoverIconButton(
              icon: Icons.copy_rounded,
              iconSize: 14,
              onPressed: () => Clipboard.setData(ClipboardData(text: code)),
            ),
          ],
        ),
      ),
    );
  }
}
