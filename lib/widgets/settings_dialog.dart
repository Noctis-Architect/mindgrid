import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/hover_surface.dart';
import '../core/uid.dart';
import '../l10n/l10n.dart';
import '../models/app_settings.dart';
import '../services/ollama_runtime.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late AppSettings _draft;
  late TextEditingController _ollamaUrl;
  late TextEditingController _apiBaseUrl;
  late TextEditingController _apiKey;
  late TextEditingController _apiKeyName;
  late TextEditingController _manualModel;
  late TextEditingController _customHeaders;
  late TextEditingController _extractBase;
  late TextEditingController _extractKey;
  late TextEditingController _extractModelManual;
  late TextEditingController _extractPrompt;
  late TextEditingController _maxTokens;
  late TextEditingController _contextWindow;
  late TextEditingController _requestTimeout;
  String _selectedProfileId = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    final state = context.read<AppState>();
    _draft = state.settings;
    _selectedProfileId = _draft.selectedApiKeyProfileId;
    _ollamaUrl = TextEditingController(text: _draft.ollamaUrl);
    _apiBaseUrl = TextEditingController(text: _draft.apiBaseUrl);
    _apiKey = TextEditingController(text: _draft.apiKey);
    _apiKeyName = TextEditingController(
      text: _draft.apiKeyProfiles
              .where((p) => p.id == _selectedProfileId)
              .map((p) => p.name)
              .firstOrNull ??
          '',
    );
    _manualModel = TextEditingController(text: _draft.selectedModel);
    _customHeaders = TextEditingController(text: _draft.customHeaders);
    _extractBase = TextEditingController(text: _draft.extractApiBase);
    _extractKey = TextEditingController(text: _draft.extractApiKey);
    _extractModelManual = TextEditingController(text: _draft.extractModelManual);
    _extractPrompt = TextEditingController(text: _draft.extractPrompt);
    _maxTokens = TextEditingController(text: '${_draft.maxTokens}');
    _contextWindow = TextEditingController(text: '${_draft.contextWindow}');
    _requestTimeout = TextEditingController(text: '${_draft.requestTimeout}');
  }

  @override
  void dispose() {
    _tabs.dispose();
    _ollamaUrl.dispose();
    _apiBaseUrl.dispose();
    _apiKey.dispose();
    _apiKeyName.dispose();
    _manualModel.dispose();
    _customHeaders.dispose();
    _extractBase.dispose();
    _extractKey.dispose();
    _extractModelManual.dispose();
    _extractPrompt.dispose();
    _maxTokens.dispose();
    _contextWindow.dispose();
    _requestTimeout.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      jsonDecode(_customHeaders.text);
    } catch (_) {
      context.read<AppState>().showToast(
        context.read<AppState>().strings.invalidCustomHeadersJson,
        type: ToastType.err,
      );
      return;
    }

    var profiles = List<ApiKeyProfile>.from(_draft.apiKeyProfiles);
    final keyVal = _apiKey.text.trim();
    final nameVal = _apiKeyName.text.trim();
    var selId = _selectedProfileId;

    if (selId.isNotEmpty) {
      final idx = profiles.indexWhere((p) => p.id == selId);
      if (idx != -1) {
        profiles[idx] = ApiKeyProfile(
          id: profiles[idx].id,
          name: nameVal.isNotEmpty ? nameVal : profiles[idx].name,
          key: keyVal,
        );
      }
    } else if (nameVal.isNotEmpty && keyVal.isNotEmpty) {
      final existing = profiles
          .where((p) => p.name.toLowerCase() == nameVal.toLowerCase())
          .firstOrNull;
      if (existing != null) {
        profiles = profiles
            .map((p) => p.id == existing.id
                ? ApiKeyProfile(id: p.id, name: nameVal, key: keyVal)
                : p)
            .toList();
        selId = existing.id;
      } else {
        final created = ApiKeyProfile(id: newId(), name: nameVal, key: keyVal);
        profiles.add(created);
        selId = created.id;
      }
    }

    final saved = _draft.copyWith(
      ollamaUrl: OllamaRuntime.normalizeOllamaBase(
        _ollamaUrl.text.trim().isEmpty
            ? 'http://127.0.0.1:11434'
            : _ollamaUrl.text.trim(),
      ),
      apiBaseUrl: _apiBaseUrl.text.trim(),
      apiKey: keyVal,
      apiKeyProfiles: profiles,
      selectedApiKeyProfileId: selId,
      customHeaders: _customHeaders.text.trim(),
      extractApiBase: _extractBase.text.trim(),
      extractApiKey: _extractKey.text.trim(),
      extractModelManual: _extractModelManual.text.trim(),
      extractPrompt: _extractPrompt.text.trim(),
      maxTokens: int.tryParse(_maxTokens.text) ?? _draft.maxTokens,
      contextWindow: int.tryParse(_contextWindow.text) ?? _draft.contextWindow,
      requestTimeout: int.tryParse(_requestTimeout.text) ?? _draft.requestTimeout,
    );

    await context.read<AppState>().saveSettings(saved);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = context.s;
    final mobile = MediaQuery.sizeOf(context).width < mobileBreakpoint;
    final screenH = MediaQuery.sizeOf(context).height;

    return Dialog(
      backgroundColor: AppColors.bgPanel,
      insetPadding: EdgeInsets.all(mobile ? 8 : 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: mobile ? double.infinity : 700,
          maxHeight: screenH * (mobile ? 0.96 : 0.9),
        ),
        child: Column(
          children: [
            _DialogHeader(icon: Icons.settings_outlined, title: s.settingsTitle, onClose: widget.onClose),
            _StyledTabBar(
              controller: _tabs,
              tabs: [s.tabGeneral, s.tabApi, s.tabAutoExtract, s.tabAdvanced],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _generalTab(s),
                  _apiTab(state, s),
                  _extractTab(state, s),
                  _advancedTab(s),
                ],
              ),
            ),
            _DialogFooter(onSave: _save, label: s.saveSettings),
          ],
        ),
      ),
    );
  }

  Widget _generalTab(dynamic s) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        _SectionLabel(label: s.creativity),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _draft.temperature,
                min: 0,
                max: 2,
                divisions: 40,
                onChanged: (v) => setState(() => _draft = _draft.copyWith(temperature: v)),
              ),
            ),
            const SizedBox(width: 10),
            _ValueBadge(text: _draft.temperature.toStringAsFixed(2)),
          ],
        ),
        const SizedBox(height: 12),
        _numField(s.maxOutputTokens, _maxTokens, (v) {
          setState(() => _draft = _draft.copyWith(maxTokens: v));
        }),
        _numField(s.contextMessageCount, _contextWindow, (v) {
          setState(() => _draft = _draft.copyWith(contextWindow: v));
        }),
        _SettingsSwitch(
          title: s.streaming,
          subtitle: s.streamingSubtitle,
          value: _draft.streamingEnabled,
          onChanged: (v) => setState(() => _draft = _draft.copyWith(streamingEnabled: v)),
        ),
        _SettingsSwitch(
          title: s.thinkingMode,
          subtitle: _draft.provider == LlmProvider.ollama
              ? s.thinkingModeOllama
              : s.thinkingModeOllamaOnly,
          value: _draft.thinkEnabled,
          onChanged: _draft.provider == LlmProvider.ollama
              ? (v) => setState(() => _draft = _draft.copyWith(thinkEnabled: v))
              : null,
        ),
      ],
    );
  }

  Widget _apiTab(AppState state, dynamic s) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        _SectionLabel(label: s.provider),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: LlmProvider.values.map((p) {
            final selected = _draft.provider == p;
            return _ProviderChip(
              label: p.label,
              selected: selected,
              onTap: () => setState(() {
                _draft = _draft.copyWith(provider: p);
                if (p == LlmProvider.openai) {
                  _apiBaseUrl.text = 'https://api.openai.com/v1';
                } else if (p == LlmProvider.openrouter) {
                  _apiBaseUrl.text = 'https://openrouter.ai/api/v1';
                }
              }),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        if (_draft.provider == LlmProvider.ollama) ...[
          _styledField(label: s.ollamaUrl, controller: _ollamaUrl),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: state.isDiscovering ? null : () => state.fetchModels(scanNetwork: true),
            icon: Icon(state.isDiscovering ? Icons.hourglass_empty : Icons.wifi_find, size: 16),
            label: Text(state.isDiscovering ? s.searching : s.discoverOllama),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.borderMd),
            ),
          ),
        ] else ...[
          _styledField(label: s.baseUrl, controller: _apiBaseUrl),
          const SizedBox(height: 12),
          _SectionLabel(label: s.apiKeys),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedProfileId.isEmpty ? null : _selectedProfileId,
            decoration: _dropdownDecoration(s.savedKey),
            dropdownColor: AppColors.bgPanel,
            items: [
              DropdownMenuItem(value: null, child: Text(s.newKey)),
              ..._draft.apiKeyProfiles.map(
                (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
              ),
            ],
            onChanged: (id) {
              setState(() {
                _selectedProfileId = id ?? '';
                if (id != null) {
                  final p = _draft.apiKeyProfiles.firstWhere((x) => x.id == id);
                  _apiKey.text = p.key;
                  _apiKeyName.text = p.name;
                } else {
                  _apiKey.clear();
                  _apiKeyName.clear();
                }
              });
            },
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _styledField(label: s.keyName, controller: _apiKeyName)),
              const SizedBox(width: 8),
              _DangerIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: s.deleteKey,
                onPressed: _selectedProfileId.isEmpty ? null : _deleteApiKeyProfile,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _styledField(label: s.apiKey, controller: _apiKey, obscure: true),
          const SizedBox(height: 10),
          _styledField(
            label: s.manualModelName,
            controller: _manualModel,
            onChanged: (v) => state.selectModel(v),
          ),
        ],
        const SizedBox(height: 16),
        _numField(s.requestTimeout, _requestTimeout, (v) {
          setState(() => _draft = _draft.copyWith(requestTimeout: v));
        }),
        _styledField(
          label: s.customHeaders,
          controller: _customHeaders,
          maxLines: 3,
          monospace: true,
        ),
      ],
    );
  }

  Widget _extractTab(AppState state, dynamic s) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.18)),
          ),
          child: Text(
            s.autoExtractDescription,
            style: const TextStyle(color: AppColors.text2, fontSize: 13, height: 1.5),
          ),
        ),
        const SizedBox(height: 12),
        _SettingsSwitch(
          title: s.autoExtract,
          subtitle: s.autoExtractSubtitle,
          value: _draft.autoExtract,
          onChanged: (v) => setState(() => _draft = _draft.copyWith(autoExtract: v)),
        ),
        const SizedBox(height: 16),
        _SectionLabel(label: s.extractProvider),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ExtractProvider.values.map((p) {
            final selected = _draft.extractProvider == p;
            return _ProviderChip(
              label: p.name,
              selected: selected,
              onTap: () => setState(() => _draft = _draft.copyWith(extractProvider: p)),
            );
          }).toList(),
        ),
        if (_draft.extractProvider == ExtractProvider.openai ||
            _draft.extractProvider == ExtractProvider.openrouter) ...[
          const SizedBox(height: 12),
          _styledField(label: s.baseUrl, controller: _extractBase),
          const SizedBox(height: 8),
          _styledField(label: s.apiKey, controller: _extractKey, obscure: true),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _draft.extractModel.isEmpty ? null : _draft.extractModel,
          decoration: _dropdownDecoration(s.extractModel),
          dropdownColor: AppColors.bgPanel,
          items: [
            DropdownMenuItem(value: null, child: Text(s.sameChatModel)),
            ...state.models.map((m) => DropdownMenuItem(value: m.name, child: Text(m.name))),
          ],
          onChanged: (v) => setState(() => _draft = _draft.copyWith(extractModel: v ?? '')),
        ),
        const SizedBox(height: 8),
        _styledField(label: s.extractModelManual, controller: _extractModelManual),
        const SizedBox(height: 8),
        _styledField(label: s.extractionPrompt, controller: _extractPrompt, maxLines: 5),
      ],
    );
  }

  Widget _advancedTab(dynamic s) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.red.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.red.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 15, color: AppColors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.advancedWarning,
                  style: const TextStyle(color: AppColors.text2, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () async {
            final appState = context.read<AppState>();
            final close = widget.onClose;
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(s.clearAllData),
                content: Text(s.clearAllDataConfirm),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.red),
                    child: Text(s.clear),
                  ),
                ],
              ),
            );
            if (ok == true) {
              await appState.clearAllData();
              close();
            }
          },
          icon: const Icon(Icons.delete_forever_outlined, size: 16),
          label: Text(s.clearAllData),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.red,
            side: const BorderSide(color: AppColors.red),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteApiKeyProfile() async {
    final id = _selectedProfileId;
    if (id.isEmpty) return;
    final profile = _draft.apiKeyProfiles.where((p) => p.id == id).firstOrNull;
    if (profile == null) return;

    final s = context.s;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteApiKey),
        content: Text(s.deleteApiKeyConfirm(profile.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _draft = _draft.copyWith(
        apiKeyProfiles: _draft.apiKeyProfiles.where((p) => p.id != id).toList(),
        selectedApiKeyProfileId: '',
        apiKey: '',
      );
      _selectedProfileId = '';
      _apiKey.clear();
      _apiKeyName.clear();
    });
    context.read<AppState>().showToast(s.apiKeyDeleted, type: ToastType.ok);
  }

  Widget _numField(String label, TextEditingController controller, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _styledField(
        label: label,
        controller: controller,
        keyboardType: TextInputType.number,
        onChanged: (v) {
          final n = int.tryParse(v);
          if (n != null) onChanged(n);
        },
      ),
    );
  }

  Widget _styledField({
    required String label,
    required TextEditingController controller,
    bool obscure = false,
    int maxLines = 1,
    bool monospace = false,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      maxLines: obscure ? 1 : maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: TextStyle(
        fontFamily: monospace ? 'monospace' : null,
        fontSize: monospace ? 12 : 14,
        color: AppColors.text1,
      ),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.bgCode,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderMd),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderMd),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.bgCode,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderMd),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderMd),
      ),
    );
  }
}

// ── Shared dialog components ──────────────────────────────────────

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.icon, required this.title, required this.onClose});
  final IconData icon;
  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.accent),
          const SizedBox(width: 10),
          Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.text1)),
          const Spacer(),
          _CloseBtn(onPressed: onClose),
        ],
      ),
    );
  }
}

class _CloseBtn extends StatelessWidget {
  const _CloseBtn({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return HoverIconButton(
      icon: Icons.close_rounded,
      onPressed: onPressed,
      iconSize: 16,
    );
  }
}

class _StyledTabBar extends StatelessWidget {
  const _StyledTabBar({required this.controller, required this.tabs});
  final TabController controller;
  final List<String> tabs;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.bgCode,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          color: AppColors.bgHover,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppColors.borderMd),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.text1,
        unselectedLabelColor: AppColors.text3,
        labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontSize: 12.5),
        padding: const EdgeInsets.all(4),
        tabs: tabs.map((t) => Tab(text: t, height: 32)).toList(),
      ),
    );
  }
}

class _DialogFooter extends StatelessWidget {
  const _DialogFooter({required this.onSave, required this.label});
  final VoidCallback onSave;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onSave,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        color: AppColors.text3,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _ValueBadge extends StatelessWidget {
  const _ValueBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.bgCode,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.accent),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgCode,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 13, color: AppColors.text1, fontWeight: FontWeight.w500)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.text3)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.accent,
            activeTrackColor: AppColors.accentGlow,
            inactiveTrackColor: AppColors.bgHover,
            inactiveThumbColor: AppColors.text4,
          ),
        ],
      ),
    );
  }
}

class _ProviderChip extends StatelessWidget {
  const _ProviderChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverSurface(
      onTap: onTap,
      builder: (context, hovered) => HoverBox(
        hovered: hovered,
        active: selected,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        borderRadius: BorderRadius.circular(10),
        baseColor: AppColors.bgCode,
        activeColor: AppColors.accentGlow,
        hoverColor: AppColors.bgHover,
        showBorder: true,
        accentBorder: selected || hovered,
        child: AnimatedDefaultTextStyle(
          duration: AppHover.duration,
          curve: AppHover.curve,
          style: TextStyle(
            fontSize: 13,
            color: selected
                ? AppColors.accent
                : (hovered ? AppColors.text1 : AppColors.text2),
            fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _DangerIconButton extends StatelessWidget {
  const _DangerIconButton({required this.icon, required this.onPressed, this.tooltip});
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return HoverIconButton(
      icon: icon,
      onPressed: onPressed,
      tooltip: tooltip,
      danger: true,
      enabled: onPressed != null,
      padding: const EdgeInsets.all(9),
      borderRadius: 10,
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
