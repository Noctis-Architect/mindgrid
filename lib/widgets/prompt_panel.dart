import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../l10n/l10n.dart';
import '../models/prompt_config.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'json_highlight.dart';

class PromptPanel extends StatefulWidget {
  const PromptPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<PromptPanel> createState() => _PromptPanelState();
}

class _PromptPanelState extends State<PromptPanel> {
  late PromptConfig _config;
  late TextEditingController _systemPrompt;
  final List<TextEditingController> _keyControllers = [];
  final List<TextEditingController> _valControllers = [];
  bool _editPayload = false;
  late TextEditingController _payloadEditor;
  String? _payloadError;

  @override
  void initState() {
    super.initState();
    _config = context.read<AppState>().promptConfig;
    _systemPrompt = TextEditingController(text: _config.systemPrompt);
    _payloadEditor = TextEditingController();
    _syncVariableControllers();
    _refreshPayloadPreview();
  }

  void _syncVariableControllers() {
    for (final c in _keyControllers) {
      c.dispose();
    }
    for (final c in _valControllers) {
      c.dispose();
    }
    _keyControllers.clear();
    _valControllers.clear();
    for (final v in _config.variables) {
      _keyControllers.add(TextEditingController(text: v.key));
      _valControllers.add(TextEditingController(text: v.value));
    }
  }

  void _updateVariable(int i) {
    final vars = [..._config.variables];
    while (vars.length <= i) {
      vars.add(const PromptVariable(key: '', value: ''));
    }
    vars[i] = PromptVariable(
      key: _keyControllers[i].text,
      value: _valControllers[i].text,
    );
    _config = _config.copyWith(variables: vars);
  }

  @override
  void dispose() {
    _systemPrompt.dispose();
    _payloadEditor.dispose();
    for (final c in _keyControllers) {
      c.dispose();
    }
    for (final c in _valControllers) {
      c.dispose();
    }
    super.dispose();
  }

  PromptConfig get _localConfig =>
      _config.copyWith(systemPrompt: _systemPrompt.text);

  void _refreshPayloadPreview() {
    final state = context.read<AppState>();
    final preview = state.previewPayload(config: _localConfig);
    final text = const JsonEncoder.withIndent('  ').convert(preview);
    if (_payloadEditor.text != text) {
      _payloadEditor.text = text;
    }
  }

  Future<void> _save() async {
    for (var i = 0; i < _keyControllers.length; i++) {
      _updateVariable(i);
    }
    await context.read<AppState>().savePromptConfig(
          _config.copyWith(systemPrompt: _systemPrompt.text),
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = context.s;
    final wide = MediaQuery.sizeOf(context).width > 800;

    return Material(
      color: AppColors.bgPanel,
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1100,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Text(s.promptEngineering,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _leftColumn(state, s)),
                          const SizedBox(width: 16),
                          Expanded(child: _rightColumn(state, s)),
                        ],
                      )
                    : ListView(
                        children: [
                          _leftColumn(state, s),
                          const SizedBox(height: 16),
                          _rightColumn(state, s),
                        ],
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: () async {
                  await _save();
                  widget.onClose();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: Text(s.save),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leftColumn(AppState state, AppStrings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.presetRoles,
            style: const TextStyle(fontSize: 11, color: AppColors.text3)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: s.promptPresets.map((p) {
            return ActionChip(
              label: Text(p.label),
              onPressed: () {
                _systemPrompt.text = p.text;
                setState(() {});
                state.showToast(s.presetApplied, type: ToastType.ok);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderMd),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                color: AppColors.bgHover,
                child: Text(s.systemPromptLabel,
                    style: const TextStyle(fontSize: 11, color: AppColors.text3)),
              ),
              TextField(
                controller: _systemPrompt,
                maxLines: 8,
                onChanged: (_) {
                  setState(() {});
                  if (!_editPayload) _refreshPayloadPreview();
                },
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                  hintText: s.systemPromptHint,
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(s.variables,
                style: const TextStyle(fontSize: 12, color: AppColors.text3)),
            const Spacer(),
            TextButton(
              onPressed: () {
                setState(() {
                  _config = _config.copyWith(
                    variables: [
                      ..._config.variables,
                      const PromptVariable(key: '', value: ''),
                    ],
                  );
                  _keyControllers.add(TextEditingController());
                  _valControllers.add(TextEditingController());
                });
              },
              child: Text(s.add),
            ),
          ],
        ),
        ...List.generate(_config.variables.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(labelText: s.key),
                    controller: _keyControllers[i],
                    onChanged: (_) {
                      _updateVariable(i);
                      if (!_editPayload) _refreshPayloadPreview();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(labelText: s.value),
                    controller: _valControllers[i],
                    onChanged: (_) {
                      _updateVariable(i);
                      if (!_editPayload) _refreshPayloadPreview();
                    },
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _keyControllers[i].dispose();
                      _valControllers[i].dispose();
                      _keyControllers.removeAt(i);
                      _valControllers.removeAt(i);
                      final vars = [..._config.variables]..removeAt(i);
                      _config = _config.copyWith(variables: vars);
                    });
                  },
                  icon: const Icon(Icons.close, size: 16),
                ),
              ],
            ),
          );
        }),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(s.injectUserProfile),
          subtitle: Text(s.injectUserProfileSubtitle),
          value: _config.injectUserInfo,
          onChanged: (v) => setState(() {
            _config = _config.copyWith(injectUserInfo: v);
            if (!_editPayload) _refreshPayloadPreview();
          }),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(s.conversationHistory),
          value: _config.injectHistory,
          onChanged: (v) => setState(() {
            _config = _config.copyWith(injectHistory: v);
            if (!_editPayload) _refreshPayloadPreview();
          }),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(s.dateTime),
          value: _config.injectDateTime,
          onChanged: (v) => setState(() {
            _config = _config.copyWith(injectDateTime: v);
            if (!_editPayload) _refreshPayloadPreview();
          }),
        ),
      ],
    );
  }

  Widget _rightColumn(AppState state, AppStrings s) {
    if (!_editPayload) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_editPayload) _refreshPayloadPreview();
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(s.fullPayload,
                style: const TextStyle(fontSize: 12, color: AppColors.text3)),
            const Spacer(),
            TextButton(
              onPressed: () {
                if (_editPayload) {
                  try {
                    final parsed = jsonDecode(_payloadEditor.text);
                    if (parsed is Map) parsed.remove('_endpoint');
                    state.setEditedPayload(
                      const JsonEncoder.withIndent('  ').convert(parsed),
                    );
                    setState(() {
                      _editPayload = false;
                      _payloadError = null;
                    });
                    state.showToast(s.customPayloadApplied, type: ToastType.ok);
                  } catch (e) {
                    setState(() => _payloadError = e.toString());
                  }
                } else {
                  setState(() => _editPayload = true);
                }
              },
              child: Text(_editPayload ? s.apply : '✏ Edit'),
            ),
            if (state.hasPayloadOverride)
              TextButton(
                onPressed: () {
                  state.setEditedPayload(null);
                  setState(() => _editPayload = false);
                  _refreshPayloadPreview();
                },
                child: Text(s.reset,
                    style: const TextStyle(color: AppColors.yellow)),
              ),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _payloadEditor.text));
                state.showToast(s.jsonCopied, type: ToastType.ok);
              },
              child: Text(s.copy),
            ),
          ],
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.bgCode,
              border: Border.all(
                color: _payloadError != null ? AppColors.red : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _editPayload
                ? TextField(
                    controller: _payloadEditor,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFF9DA3C4),
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText.rich(
                      highlightJson(_payloadEditor.text),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
