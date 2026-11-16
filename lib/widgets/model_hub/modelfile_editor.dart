import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/hover_surface.dart';
import '../../l10n/l10n.dart';
import '../../models/ollama_models.dart';
import '../../services/gguf_reader.dart';
import '../../services/model_templates.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import 'hub_widgets.dart';

const hubMono = TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: ['Consolas', 'Menlo', 'DejaVu Sans Mono', 'Courier New'],
  fontSize: 12,
  height: 1.5,
  color: AppColors.text2,
);

/// Configures how a GGUF is registered in Ollama: name, chat format, system
/// prompt, stop sequences and sampling parameters, with a live Modelfile
/// preview.
class ModelfileEditor extends StatefulWidget {
  const ModelfileEditor({
    super.key,
    required this.fileName,
    required this.fileSize,
    required this.meta,
    required this.installed,
    required this.submitLabel,
    required this.submitIcon,
    required this.onSubmit,
    required this.onBack,
    this.footerNote,
  });

  final String fileName;
  final int fileSize;
  final GgufMetadata? meta;
  final List<InstalledModel> installed;
  final String submitLabel;
  final IconData submitIcon;
  final void Function(ModelfileSpec spec) onSubmit;
  final VoidCallback onBack;
  final Widget? footerNote;

  @override
  State<ModelfileEditor> createState() => _ModelfileEditorState();
}

class _ModelfileEditorState extends State<ModelfileEditor> {
  static const _paramKeys = [
    'temperature',
    'top_p',
    'top_k',
    'min_p',
    'repeat_penalty',
    'num_ctx',
    'num_predict',
  ];
  static const _installedPrefix = 'installed:';

  late ProfileDetection _detection;
  late ModelfileSpec _spec;
  late String _source;
  bool _advanced = false;
  bool _loadingSource = false;
  int _sourceSeq = 0;

  final _name = TextEditingController();
  final _system = TextEditingController();
  final _template = TextEditingController();
  final _renderer = TextEditingController();
  final _parser = TextEditingController();
  final _stopInput = TextEditingController();
  final Map<String, TextEditingController> _params = {
    for (final k in _paramKeys) k: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _detection = ModelTemplates.detect(widget.meta, fileName: widget.fileName);
    _source = _detection.profile.id;
    _spec = ModelTemplates.buildSpec(
      name: ModelNaming.suggest(meta: widget.meta, fileName: widget.fileName),
      profile: _detection.profile,
      meta: widget.meta,
    );
    _name.text = _spec.name;
    _syncControllers();
    // Unknown formats need a manual look — open the advanced section.
    _advanced = !_detection.confident;
  }

  @override
  void dispose() {
    _name.dispose();
    _system.dispose();
    _template.dispose();
    _renderer.dispose();
    _parser.dispose();
    _stopInput.dispose();
    for (final c in _params.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncControllers() {
    _template.text = _spec.template ?? '';
    _renderer.text = _spec.renderer ?? '';
    _parser.text = _spec.parser ?? '';
    for (final k in _paramKeys) {
      final v = _spec.parameters[k];
      _params[k]!.text = v == null
          ? ''
          : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());
    }
  }

  ModelfileSpec _current() {
    final spec = _spec.copy()
      ..name = _name.text.trim()
      ..system = _system.text
      ..template = _template.text.trim().isEmpty ? null : _template.text
      ..renderer = _renderer.text.trim().isEmpty ? null : _renderer.text.trim()
      ..parser = _parser.text.trim().isEmpty ? null : _parser.text.trim();
    for (final k in _paramKeys) {
      final raw = _params[k]!.text.trim();
      final n = num.tryParse(raw);
      if (raw.isEmpty || n == null) {
        spec.parameters.remove(k);
      } else {
        spec.parameters[k] = n;
      }
    }
    return spec;
  }

  Future<void> _selectSource(String value) async {
    if (value.startsWith(_installedPrefix)) {
      final model = value.substring(_installedPrefix.length);
      final state = context.read<AppState>();
      setState(() => _loadingSource = true);
      try {
        final info = await state.ollamaManager.showModel(model, state.settings);
        final parsed = ModelTemplates.fromModelfileText(
          info['modelfile']?.toString() ?? '',
          name: _name.text.trim(),
        );
        if (!mounted) return;
        setState(() {
          _source = value;
          _spec = parsed..license = widget.meta?.license;
          _syncControllers();
        });
      } catch (e) {
        if (mounted) {
          setState(() => _sourceSeq++);
          state.showToast(state.strings.error('$e'), type: ToastType.err);
        }
      } finally {
        if (mounted) setState(() => _loadingSource = false);
      }
      return;
    }
    setState(() {
      _source = value;
      _spec = ModelTemplates.buildSpec(
        name: _name.text.trim(),
        profile: ModelTemplates.byId(value),
        meta: widget.meta,
      );
      _syncControllers();
    });
  }

  void _addStop() {
    final v = _stopInput.text;
    if (v.trim().isEmpty || _spec.stops.contains(v)) return;
    setState(() {
      _spec.stops.add(v);
      _stopInput.clear();
    });
  }

  String? _nameError(String value) {
    final s = context.sRead;
    if (value.trim().isEmpty) return s.modelNameHint;
    if (!ModelNaming.isValid(value.trim())) return s.modelNameInvalid;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final meta = widget.meta;
    final current = _current();
    final nameError = _nameError(_name.text);
    final exists = widget.installed
        .any((m) => ollamaModelNamesMatch(m.name, current.name));
    final mobile = MediaQuery.sizeOf(context).width < mobileBreakpoint;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(mobile ? 14 : 20, 16, mobile ? 14 : 20, 20),
            children: [
              // ── File summary ──
              HubCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description_outlined,
                            size: 18, color: AppColors.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              meta?.name ?? widget.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.text1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        widget.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: hubMono.copyWith(
                            fontSize: 11, color: AppColors.text3),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (widget.fileSize > 0)
                          HubTag(formatBytes(widget.fileSize),
                              icon: Icons.sd_storage_outlined),
                        if (meta?.architecture != null)
                          HubTag(meta!.architecture!,
                              icon: Icons.account_tree_outlined),
                        if (meta?.sizeLabel != null)
                          HubTag(meta!.sizeLabel!, color: AppColors.teal),
                        if ((meta?.quantization ??
                                ModelNaming.quantFromFileName(
                                    widget.fileName)) !=
                            null)
                          HubTag(
                            meta?.quantization ??
                                ModelNaming.quantFromFileName(widget.fileName)!,
                            color: AppColors.purple,
                          ),
                        if (meta?.contextLength != null)
                          HubTag('ctx ${meta!.contextLength}',
                              icon: Icons.layers_outlined),
                        if (meta?.hasVision ?? false)
                          HubTag(s.vision,
                              color: AppColors.accent,
                              icon: Icons.visibility_outlined),
                        if (_spec.renderer != null ||
                            ModelTemplates.byId(_spec.profileId).thinking)
                          HubTag('thinking',
                              color: AppColors.yellow,
                              icon: Icons.psychology_alt_outlined),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── Name ──
              HubSectionTitle(s.modelName),
              const SizedBox(height: 8),
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextField(
                  controller: _name,
                  onChanged: (_) => setState(() {}),
                  style: hubMono.copyWith(fontSize: 13, color: AppColors.text1),
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                  decoration: InputDecoration(
                    hintText: 'my-model:7b-q4_k_m',
                    errorText: nameError,
                    helperText: nameError == null && exists
                        ? s.modelNameExists
                        : s.modelNameHint,
                    helperStyle: TextStyle(
                      fontSize: 11.5,
                      color: nameError == null && exists
                          ? AppColors.yellow
                          : AppColors.text4,
                    ),
                    prefixIcon: const Icon(Icons.sell_outlined, size: 16),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ── Chat format ──
              HubSectionTitle(s.chatFormat),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('$_source#$_sourceSeq'),
                initialValue: _source,
                isExpanded: true,
                dropdownColor: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(AppRadius.md),
                style: const TextStyle(fontSize: 13, color: AppColors.text1),
                icon: _loadingSource
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.6),
                      )
                    : const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                items: [
                  for (final p in ModelTemplates.profiles)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text(
                        p.id == ModelTemplates.autoId ? s.formatAuto : p.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  for (final m in widget.installed)
                    DropdownMenuItem(
                      value: '$_installedPrefix${m.name}',
                      child: Text(
                        s.copyFromInstalled(m.name),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _loadingSource
                    ? null
                    : (v) {
                        if (v != null) _selectSource(v);
                      },
              ),
              const SizedBox(height: 8),
              _DetectionNote(
                detection: _detection,
                usingDetected: _source == _detection.profile.id,
                isAuto: _source == ModelTemplates.autoId,
              ),
              const SizedBox(height: 18),

              // ── System prompt ──
              HubSectionTitle(s.systemPromptOptional),
              const SizedBox(height: 8),
              TextField(
                controller: _system,
                onChanged: (_) => setState(() {}),
                minLines: 2,
                maxLines: 6,
                style: const TextStyle(fontSize: 13, height: 1.5),
                decoration: InputDecoration(hintText: s.systemPromptHint),
              ),
              const SizedBox(height: 14),

              // ── Advanced ──
              HoverSurface(
                onTap: () => setState(() => _advanced = !_advanced),
                builder: (context, hovered) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      AnimatedRotation(
                        turns: _advanced ? 0.25 : 0,
                        duration: AppMotion.base,
                        curve: AppMotion.emphasized,
                        child: Icon(
                          Directionality.of(context) == TextDirection.rtl
                              ? Icons.chevron_left_rounded
                              : Icons.chevron_right_rounded,
                          size: 18,
                          color: hovered ? AppColors.text1 : AppColors.text3,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        s.advancedOptions,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: hovered ? AppColors.text1 : AppColors.text2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: AppMotion.slow,
                curve: AppMotion.emphasized,
                alignment: Alignment.topCenter,
                child: !_advanced
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _advancedSection(context),
                      ),
              ),
              const SizedBox(height: 16),

              // ── Preview ──
              HubSectionTitle(
                s.modelfilePreview,
                trailing: HoverIconButton(
                  icon: Icons.copy_rounded,
                  tooltip: s.copy,
                  iconSize: 14,
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(
                        text: current.toModelfile(from: './${widget.fileName}'),
                      ),
                    );
                    context
                        .read<AppState>()
                        .showToast(s.copied, type: ToastType.ok);
                  },
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 240),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgCode,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: SingleChildScrollView(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: SelectableText(
                      _previewText(current),
                      style: hubMono.copyWith(fontSize: 11.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(mobile ? 14 : 20, 12, mobile ? 14 : 20, 12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: widget.onBack,
                icon: Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.arrow_forward_rounded
                      : Icons.arrow_back_rounded,
                  size: 16,
                ),
                label: Text(s.back),
              ),
              const SizedBox(width: 8),
              Expanded(child: widget.footerNote ?? const SizedBox.shrink()),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: nameError != null || _loadingSource
                    ? null
                    : () => widget.onSubmit(_current()),
                icon: Icon(widget.submitIcon, size: 16),
                label: Text(widget.submitLabel),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _previewText(ModelfileSpec spec) {
    var text = spec.toModelfile(from: './${widget.fileName}');
    // Keep the preview readable: licenses can be thousands of lines.
    final i = text.indexOf('\nLICENSE """');
    if (i >= 0) text = '${text.substring(0, i)}\nLICENSE """…"""';
    return text;
  }

  Widget _advancedSection(BuildContext context) {
    final s = context.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HubSectionTitle(s.templateLabel),
        const SizedBox(height: 8),
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextField(
            controller: _template,
            onChanged: (_) => setState(() {}),
            minLines: 3,
            maxLines: 12,
            style: hubMono,
            decoration: InputDecoration(
              hintText: s.templateAutoHint,
              fillColor: AppColors.bgCode,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _renderer,
                  onChanged: (_) => setState(() {}),
                  style: hubMono.copyWith(color: AppColors.text1),
                  decoration: const InputDecoration(labelText: 'RENDERER'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _parser,
                  onChanged: (_) => setState(() {}),
                  style: hubMono.copyWith(color: AppColors.text1),
                  decoration: const InputDecoration(labelText: 'PARSER'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        HubSectionTitle(s.stopSequences),
        const SizedBox(height: 8),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final stop in _spec.stops)
                _StopChip(
                  label: stop,
                  onRemove: () => setState(() => _spec.stops.remove(stop)),
                ),
              SizedBox(
                width: 190,
                height: 32,
                child: TextField(
                  controller: _stopInput,
                  onSubmitted: (_) => _addStop(),
                  style: hubMono.copyWith(color: AppColors.text1),
                  decoration: InputDecoration(
                    hintText: s.addStop,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    suffixIcon: GestureDetector(
                      onTap: _addStop,
                      child: const Icon(Icons.add_rounded, size: 16),
                    ),
                    suffixIconConstraints:
                        const BoxConstraints(minWidth: 30, minHeight: 30),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        HubSectionTitle(s.parametersLabel),
        const SizedBox(height: 8),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final k in _paramKeys)
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _params[k],
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
                    ],
                    style: hubMono.copyWith(color: AppColors.text1),
                    decoration: InputDecoration(
                      labelText: k,
                      hintText: k == 'num_ctx' &&
                              widget.meta?.contextLength != null
                          ? 'max ${widget.meta!.contextLength}'
                          : 'default',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      isDense: true,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetectionNote extends StatelessWidget {
  const _DetectionNote({
    required this.detection,
    required this.usingDetected,
    required this.isAuto,
  });

  final ProfileDetection detection;
  final bool usingDetected;
  final bool isAuto;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final IconData icon;
    final Color color;
    final String text;
    if (isAuto && !detection.confident) {
      icon = Icons.warning_amber_rounded;
      color = AppColors.yellow;
      text = detection.reason ?? s.formatNotDetected;
    } else if (usingDetected && detection.confident) {
      icon = Icons.verified_outlined;
      color = AppColors.green;
      text = s.detectedVia(detection.reason ?? '');
    } else if (usingDetected) {
      icon = Icons.info_outline_rounded;
      color = AppColors.yellow;
      text = s.guessedVia(detection.reason ?? '');
    } else {
      icon = Icons.edit_outlined;
      color = AppColors.text3;
      text = s.formatManual;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 11.5, color: color, height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _StopChip extends StatelessWidget {
  const _StopChip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(9, 5, 4, 5),
      decoration: BoxDecoration(
        color: AppColors.bgHover,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.replaceAll('\n', r'\n'),
            style: hubMono.copyWith(fontSize: 11.5, color: AppColors.text1),
          ),
          const SizedBox(width: 4),
          HoverSurface(
            onTap: onRemove,
            builder: (context, hovered) => Icon(
              Icons.close_rounded,
              size: 13,
              color: hovered ? AppColors.red : AppColors.text4,
            ),
          ),
        ],
      ),
    );
  }
}
