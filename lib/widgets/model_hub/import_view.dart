import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/file_picker_utils.dart';
import '../../core/hover_surface.dart';
import '../../core/motion.dart';
import '../../core/platform_file_picker.dart';
import '../../l10n/l10n.dart';
import '../../models/ollama_models.dart';
import '../../services/gguf_reader.dart';
import '../../services/hf_service.dart';
import '../../services/model_hub_controller.dart';
import '../../services/model_templates.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import 'hub_widgets.dart';
import 'modelfile_editor.dart';

enum _Step { home, hfFiles, analyzing, editor }

/// Import tab: install a GGUF from disk or from a Hugging Face link.
class ImportView extends StatefulWidget {
  const ImportView({
    super.key,
    required this.installed,
    required this.onQueued,
  });

  final List<InstalledModel> installed;

  /// Called after a job was added to the download manager.
  final VoidCallback onQueued;

  @override
  State<ImportView> createState() => _ImportViewState();
}

class _ImportViewState extends State<ImportView> {
  _Step _step = _Step.home;
  String? _error;
  bool _busy = false;
  bool _dragOver = false;
  bool _showConnection = false;

  final _link = TextEditingController();
  final _endpoint = TextEditingController();
  final _token = TextEditingController();
  final _proxy = TextEditingController();
  HfSettings _hf = HfSettings();

  // Hugging Face selection
  HfRef? _ref;
  List<HfFile> _files = [];

  // Pending import (either source)
  String? _localPath;
  HfFile? _hfFile;
  String? _hfUrl;
  String? _hfDest;
  String _fileName = '';
  int _fileSize = 0;
  GgufMetadata? _meta;
  int _editorSeq = 0;

  @override
  void initState() {
    super.initState();
    HfSettings.load().then((v) {
      if (!mounted) return;
      setState(() {
        _hf = v;
        _endpoint.text = v.endpoint;
        _token.text = v.token;
        _proxy.text = v.proxy;
      });
    });
  }

  @override
  void dispose() {
    _link.dispose();
    _endpoint.dispose();
    _token.dispose();
    _proxy.dispose();
    super.dispose();
  }

  bool get _dropEnabled =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  Future<void> _saveHf() async {
    _hf
      ..endpoint = _endpoint.text.trim().isEmpty
          ? HfSettings.defaultEndpoint
          : _endpoint.text.trim()
      ..token = _token.text.trim()
      ..proxy = _proxy.text.trim();
    await _hf.save();
  }

  void _reset() {
    setState(() {
      _step = _Step.home;
      _error = null;
      _busy = false;
      _localPath = null;
      _hfFile = null;
      _hfUrl = null;
      _hfDest = null;
      _meta = null;
    });
  }

  // ── Local file ────────────────────────────────────────────────────────────

  Future<void> _pickLocal() async {
    final s = context.sRead;
    try {
      final result = await PlatformFilePicker.pickFiles(
        dialogTitle: s.chooseGgufFile,
        type: FileType.any,
      );
      final path = normalizePickerPath(result?.files.firstOrNull?.path);
      if (path.isEmpty) return;
      await _openLocal(path);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _openLocal(String path) async {
    final s = context.sRead;
    setState(() {
      _step = _Step.analyzing;
      _error = null;
    });
    try {
      final file = File(path);
      final size = await file.length();
      final meta = await GgufReader.read(path);
      if (!mounted) return;
      setState(() {
        _localPath = path;
        _fileName = p.basename(path);
        _fileSize = size;
        _meta = meta;
        _editorSeq++;
        _step = _Step.editor;
      });
    } on GgufFormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _Step.home;
        _error = '${s.notGgufFile} ${e.message}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _Step.home;
        _error = '$e';
      });
    }
  }

  // ── Hugging Face ──────────────────────────────────────────────────────────

  Future<void> _findHfFiles() async {
    final s = context.sRead;
    final ref = HfRef.parse(_link.text);
    if (ref == null) {
      setState(() => _error = s.hfInvalidLink);
      return;
    }
    await _saveHf();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final files = await HfService.listGgufFiles(ref, _hf);
      if (!mounted) return;
      if (files.isEmpty) {
        setState(() {
          _busy = false;
          _error = s.hfNoGguf;
        });
        return;
      }
      _ref = ref;
      _files = files;

      // A link to one file, or `repo:QUANT`, selects it directly.
      HfFile? direct;
      if (ref.filePath != null) {
        direct = files.where((f) => f.path == ref.filePath).firstOrNull;
      } else if (ref.quantHint != null) {
        final q = ref.quantHint!.toUpperCase();
        final matches = files
            .where((f) => !f.isSplit && !f.isProjector && f.quant == q)
            .toList();
        if (matches.length == 1) direct = matches.first;
      }
      setState(() => _busy = false);
      if (direct != null && !direct.isSplit) {
        await _selectHfFile(direct);
      } else {
        setState(() => _step = _Step.hfFiles);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
        _showConnection = true;
      });
    }
  }

  Future<void> _selectHfFile(HfFile file) async {
    final ref = _ref!;
    setState(() {
      _step = _Step.analyzing;
      _error = null;
    });
    try {
      final dir = await ModelHubController.modelsDir();
      final dest = p.join(
        dir.path,
        '${ref.repo.replaceAll('/', '__')}__${file.name}',
      );
      final url = HfService.fileUrl(_hf, ref, file.path);
      GgufMetadata? meta;
      if (await File(dest).exists()) {
        meta = await GgufReader.read(dest);
      } else {
        meta = await HfService.fetchHeader(
          url: url,
          partPath: '$dest.part',
          settings: _hf,
          totalSize: file.size,
        );
      }
      if (!mounted) return;
      setState(() {
        _hfFile = file;
        _hfUrl = url;
        _hfDest = dest;
        _fileName = file.name;
        _fileSize = file.size;
        _meta = meta;
        _editorSeq++;
        _step = _Step.editor;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _files.length > 1 ? _Step.hfFiles : _Step.home;
        _error = '$e';
      });
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  void _submit(ModelfileSpec spec) {
    final state = context.read<AppState>();
    if (_localPath != null) {
      state.hub.enqueueLocalImport(path: _localPath!, spec: spec);
    } else if (_hfFile != null) {
      state.hub.enqueueHuggingFace(
        url: _hfUrl!,
        destPath: _hfDest!,
        size: _hfFile!.size,
        sha256: _hfFile!.sha256,
        spec: spec,
        keepFile: _hf.keepFiles,
      );
    } else {
      return;
    }
    state.showToast(state.strings.queuedToast(spec.name));
    _reset();
    _link.clear();
    widget.onQueued();
  }

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (_step) {
      _Step.home => _home(context),
      _Step.hfFiles => _hfFilesView(context),
      _Step.analyzing => _Analyzing(
          key: const ValueKey('analyzing'),
          label: context.s.analyzingGguf,
        ),
      _Step.editor => ModelfileEditor(
          key: ValueKey('editor-$_editorSeq'),
          fileName: _fileName,
          fileSize: _fileSize,
          meta: _meta,
          installed: widget.installed,
          submitLabel: _localPath != null
              ? context.s.installToOllama
              : context.s.downloadAndInstall,
          submitIcon: _localPath != null
              ? Icons.bolt_rounded
              : Icons.download_rounded,
          onSubmit: _submit,
          onBack: () => setState(() {
            _step = _hfFile != null && _files.length > 1
                ? _Step.hfFiles
                : _Step.home;
            _hfFile = null;
            _localPath = null;
          }),
        ),
    };

    Widget view = FadeThrough(child: child);
    if (_dropEnabled && _step == _Step.home) {
      view = DropTarget(
        onDragEntered: (_) => setState(() => _dragOver = true),
        onDragExited: (_) => setState(() => _dragOver = false),
        onDragDone: (detail) {
          setState(() => _dragOver = false);
          final path = detail.files.firstOrNull?.path;
          if (path != null && path.isNotEmpty) _openLocal(path);
        },
        child: view,
      );
    }
    return view;
  }

  Widget _home(BuildContext context) {
    final s = context.s;
    final mobile = MediaQuery.sizeOf(context).width < mobileBreakpoint;
    return ListView(
      key: const ValueKey('home'),
      padding: EdgeInsets.all(mobile ? 14 : 20),
      children: [
        AnimatedSize(
          duration: AppMotion.base,
          curve: AppMotion.emphasized,
          alignment: Alignment.topCenter,
          child: _error == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ErrorBanner(
                    message: _error!,
                    onClose: () => setState(() => _error = null),
                  ),
                ),
        ),
        // Local file
        FadeSlideIn(
          child: HoverSurface(
            onTap: _pickLocal,
            builder: (context, hovered) => HubCard(
              borderColor: _dragOver
                  ? AppColors.accent
                  : hovered
                      ? AppColors.borderFocus
                      : null,
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  _SourceIcon(
                    icon: Icons.upload_file_rounded,
                    active: hovered || _dragOver,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.importLocalTitle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _dropEnabled
                              ? s.importLocalDescDrop
                              : s.importLocalDesc,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.text3,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    color: AppColors.text4,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Hugging Face
        FadeSlideIn(
          delay: const Duration(milliseconds: 60),
          child: HubCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _SourceIcon(icon: Icons.hub_outlined),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.importHfTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            s.importHfDesc,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.text3,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    controller: _link,
                    onSubmitted: (_) => _busy ? null : _findHfFiles(),
                    style: hubMono.copyWith(
                        fontSize: 12.5, color: AppColors.text1),
                    decoration: const InputDecoration(
                      hintText:
                          'https://huggingface.co/owner/repo  ·  owner/repo:Q4_K_M',
                      prefixIcon: Icon(Icons.link_rounded, size: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _showConnection = !_showConnection),
                      icon: const Icon(Icons.settings_ethernet_rounded,
                          size: 15),
                      label: Text(s.hfConnection),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _busy ? null : _findHfFiles,
                      icon: _busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: AppColors.text3,
                              ),
                            )
                          : const Icon(Icons.search_rounded, size: 16),
                      label: Text(s.hfFindFiles),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: AppMotion.slow,
                  curve: AppMotion.emphasized,
                  alignment: Alignment.topCenter,
                  child: !_showConnection
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: _connection(context),
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FadeSlideIn(
          delay: const Duration(milliseconds: 120),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.auto_fix_high_rounded,
                    size: 14, color: AppColors.text4),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.importHint,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.text4,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _connection(BuildContext context) {
    final s = context.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              TextField(
                controller: _endpoint,
                style: hubMono.copyWith(color: AppColors.text1),
                decoration: InputDecoration(
                  labelText: s.hfEndpoint,
                  hintText: HfSettings.defaultEndpoint,
                  helperText: s.hfEndpointHelp,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _proxy,
                style: hubMono.copyWith(color: AppColors.text1),
                decoration: InputDecoration(
                  labelText: s.hfProxy,
                  hintText: 'http://127.0.0.1:10808',
                  helperText: s.hfProxyHelp,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _token,
                obscureText: true,
                style: hubMono.copyWith(color: AppColors.text1),
                decoration: InputDecoration(
                  labelText: s.hfToken,
                  hintText: 'hf_…',
                  helperText: s.hfTokenHelp,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                s.hfKeepFile,
                style: const TextStyle(fontSize: 12.5, color: AppColors.text2),
              ),
            ),
            Switch(
              value: _hf.keepFiles,
              onChanged: (v) {
                setState(() => _hf.keepFiles = v);
                _saveHf();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _hfFilesView(BuildContext context) {
    final s = context.s;
    final mobile = MediaQuery.sizeOf(context).width < mobileBreakpoint;
    return Column(
      key: const ValueKey('hf-files'),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(mobile ? 8 : 14, 10, mobile ? 14 : 20, 6),
          child: Row(
            children: [
              HoverIconButton(
                icon: Directionality.of(context) == TextDirection.rtl
                    ? Icons.arrow_forward_rounded
                    : Icons.arrow_back_rounded,
                tooltip: s.back,
                onPressed: _reset,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    _ref?.repo ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text1,
                    ),
                  ),
                ),
              ),
              HubTag('${_files.length} GGUF'),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: EdgeInsets.fromLTRB(mobile ? 14 : 20, 4, mobile ? 14 : 20, 6),
            child: _ErrorBanner(
              message: _error!,
              onClose: () => setState(() => _error = null),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(mobile ? 14 : 20, 6, mobile ? 14 : 20, 20),
            itemCount: _files.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final f = _files[i];
              final disabled = f.isSplit;
              return FadeSlideIn(
                delay: Duration(milliseconds: (i * 25).clamp(0, 300)),
                offset: const Offset(0, 8),
                child: HoverSurface(
                  enabled: !disabled,
                  onTap: disabled ? null : () => _selectHfFile(f),
                  builder: (context, hovered) => Opacity(
                    opacity: disabled ? 0.5 : 1,
                    child: HubCard(
                      borderColor: hovered ? AppColors.borderFocus : null,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    f.path,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: hubMono.copyWith(
                                      fontSize: 12.5,
                                      color: AppColors.text1,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    if (f.quant != null)
                                      HubTag(f.quant!,
                                          color: AppColors.purple),
                                    if (f.isProjector)
                                      HubTag(s.hfProjector,
                                          color: AppColors.yellow),
                                    if (f.isSplit)
                                      HubTag(s.hfSplitUnsupported,
                                          color: AppColors.red),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            formatBytes(f.size),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.text2,
                              fontWeight: FontWeight.w600,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.download_rounded,
                            size: 17,
                            color: hovered ? AppColors.accent : AppColors.text4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SourceIcon extends StatelessWidget {
  const _SourceIcon({required this.icon, this.active = false});
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.base,
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: active ? AppColors.accentGlow : AppColors.bgHover,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        size: 20,
        color: active ? AppColors.accent : AppColors.text2,
      ),
    );
  }
}

class _Analyzing extends StatelessWidget {
  const _Analyzing({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 160, child: SmoothProgressBar(height: 3)),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(color: AppColors.text3, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onClose});
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: AppColors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.text1,
                height: 1.45,
              ),
            ),
          ),
          HoverIconButton(
            icon: Icons.close_rounded,
            iconSize: 14,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
