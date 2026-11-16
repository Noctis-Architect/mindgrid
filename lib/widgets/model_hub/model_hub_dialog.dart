import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/hover_surface.dart';
import '../../core/motion.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/l10n.dart';
import '../../models/ollama_models.dart';
import '../../services/model_capabilities.dart';
import '../../services/model_hub_controller.dart';
import '../../services/ollama_manager_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../ollama_hardware_guide.dart';
import 'hub_widgets.dart';
import 'import_view.dart';
import 'modelfile_editor.dart';

enum _Section { library, import, downloads, installed, hardware }

/// Model Hub: browse the Ollama library, import GGUF files, track downloads
/// and manage installed models.
class ModelHubDialog extends StatefulWidget {
  const ModelHubDialog({
    super.key,
    required this.onClose,
    this.embedded = false,
  });

  final VoidCallback onClose;

  /// Rendered inline as a page instead of a modal dialog.
  final bool embedded;

  @override
  State<ModelHubDialog> createState() => _ModelHubDialogState();
}

class _ModelHubDialogState extends State<ModelHubDialog> {
  late final OllamaManagerService _manager;
  late final ModelHubController _hub;

  _Section _section = _Section.library;
  OllamaLocalStatus _status = OllamaLocalStatus.notInstalled;
  bool _loading = true;
  bool _busy = false;
  String? _log;
  List<OllamaModelFamily> _families = [];
  Map<String, List<OllamaModelVariant>> _variantsCache = {};
  Set<String> _expanded = {};
  Set<String> _loadingVariants = {};
  List<InstalledModel> _installed = [];
  String _search = '';
  int _completedSeen = 0;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _manager = state.ollamaManager;
    _hub = state.hub;
    _completedSeen = _completedCount;
    _hub.addListener(_onHubChanged);
    if (_hub.pendingCount > 0) _section = _Section.downloads;
    _refreshAll();
  }

  @override
  void dispose() {
    _hub.removeListener(_onHubChanged);
    super.dispose();
  }

  int get _completedCount =>
      _hub.tasks.where((t) => t.stage == HubTaskStage.completed).length;

  void _onHubChanged() {
    if (!mounted) return;
    final completed = _completedCount;
    if (completed > _completedSeen) _reloadInstalled();
    _completedSeen = completed;
    setState(() {});
  }

  Future<void> _reloadInstalled() async {
    final state = context.read<AppState>();
    final installed = await _manager.fetchInstalledModels(state.settings);
    if (mounted) setState(() => _installed = installed);
  }

  Future<void> _refreshAll() async {
    setState(() {
      _loading = true;
      _log = null;
    });
    final state = context.read<AppState>();
    final status = await _manager.checkConnection(state.settings);
    var installed = <InstalledModel>[];
    if (status == OllamaLocalStatus.running) {
      installed = await _manager.fetchInstalledModels(state.settings);
    }
    if (!mounted) return;
    setState(() {
      _status = status;
      _installed = installed;
      _loading = false;
    });
    if (status == OllamaLocalStatus.running) {
      final families = await _manager.fetchLibraryFamilies();
      if (!mounted) return;
      setState(() {
        _families = families;
        _variantsCache = {};
        _expanded = {};
        _loadingVariants = {};
      });
    }
  }

  Future<void> _toggleFamily(String name) async {
    if (_expanded.contains(name)) {
      setState(() => _expanded = {..._expanded}..remove(name));
      return;
    }
    setState(() {
      _expanded = {..._expanded, name};
      if (!_variantsCache.containsKey(name)) {
        _loadingVariants = {..._loadingVariants, name};
      }
    });
    if (_variantsCache.containsKey(name)) return;
    final variants = await _manager.fetchModelVariants(name);
    if (!mounted) return;
    setState(() {
      _variantsCache = {..._variantsCache, name: variants};
      _loadingVariants = {..._loadingVariants}..remove(name);
    });
  }

  Future<void> _runSetup(
    Future<({bool success, String message})> Function(AppStrings s) action,
  ) async {
    final state = context.read<AppState>();
    setState(() {
      _busy = true;
      _log = '';
    });
    final result = await action(state.strings);
    if (!mounted) return;
    state.showToast(
      result.message,
      type: result.success ? ToastType.ok : ToastType.err,
    );
    setState(() => _busy = false);
    await _refreshAll();
    if (_status == OllamaLocalStatus.running) {
      await state.fetchModels(silent: true);
    }
  }

  void _onLog(String line) {
    if (mounted) setState(() => _log = line);
  }

  Future<void> _installLinux() => _runSetup((s) async {
    final r = await _manager.installOnLinux(s: s, onLog: _onLog);
    return (success: r.success, message: r.message);
  });

  Future<void> _enableService() => _runSetup((s) async {
    var r = await _manager.enableSystemdService(s: s, onLog: _onLog);
    if (!r.success) {
      r = await _manager.startOllamaServe(s: s, onLog: _onLog);
    }
    return (success: r.success, message: r.message);
  });

  Future<void> _openUrl(String url) async {
    final state = context.read<AppState>();
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      state.showToast(state.strings.failedToOpenLink, type: ToastType.err);
    }
  }

  bool _isInstalled(String name) =>
      _installed.any((i) => ollamaModelNamesMatch(i.name, name));

  Future<void> _deleteModel(String name) async {
    final state = context.read<AppState>();
    final s = state.strings;
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteModel),
        content: Text(s.deleteModelConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _manager.deleteModel(name, state.settings);
      state.showToast(s.modelRemoved(name), type: ToastType.ok);
      await state.fetchModels(silent: true);
      await _reloadInstalled();
    } catch (e) {
      state.showToast(s.error('$e'), type: ToastType.err);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showModelfile(String name) async {
    final state = context.read<AppState>();
    try {
      final info = await _manager.showModel(name, state.settings);
      if (!mounted) return;
      var text = info['modelfile']?.toString() ?? '';
      final lic = text.indexOf('\nLICENSE """');
      if (lic >= 0) text = '${text.substring(0, lic)}\nLICENSE """…"""';
      final caps =
          (info['capabilities'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[];
      await showAppDialog<void>(
        context: context,
        builder: (ctx) =>
            _ModelfileDialog(name: name, modelfile: text, capabilities: caps),
      );
    } catch (e) {
      state.showToast(state.strings.error('$e'), type: ToastType.err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final size = MediaQuery.sizeOf(context);
    final mobile = size.width < mobileBreakpoint;
    final running = !_loading && _status == OllamaLocalStatus.running;

    final Widget content;
    if (_loading) {
      content = Center(
        key: const ValueKey('loading'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 140, child: SmoothProgressBar(height: 3)),
            const SizedBox(height: 14),
            Text(
              s.loading,
              style: const TextStyle(color: AppColors.text3, fontSize: 13),
            ),
          ],
        ),
      );
    } else if (!running) {
      content = KeyedSubtree(
        key: const ValueKey('setup'),
        child: _setupPanel(s),
      );
    } else {
      content = KeyedSubtree(
        key: ValueKey(_section),
        child: switch (_section) {
          _Section.library => _libraryView(s),
          _Section.import => ImportView(
            installed: _installed,
            onQueued: () => setState(() => _section = _Section.downloads),
          ),
          _Section.downloads => _downloadsView(s),
          _Section.installed => _installedView(s),
          _Section.hardware => const OllamaHardwareGuide(),
        },
      );
    }

    final nav = <(_Section, IconData, String, int)>[
      (_Section.library, Icons.explore_outlined, s.library, 0),
      (_Section.import, Icons.add_box_outlined, s.hubImport, 0),
      (
        _Section.downloads,
        Icons.downloading_rounded,
        s.downloadingTab,
        _hub.pendingCount,
      ),
      (
        _Section.installed,
        Icons.inventory_2_outlined,
        s.installed,
        _installed.length,
      ),
      (_Section.hardware, Icons.memory_rounded, s.hardwareGuide, 0),
    ];

    return _HubFrame(
      embedded: widget.embedded,
      mobile: mobile,
      size: size,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(s),
          const Divider(),
          if (running && mobile)
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                children: [
                  for (final (sec, icon, label, count) in nav)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _NavItem(
                        icon: icon,
                        label: label,
                        count: count,
                        active: _section == sec,
                        compact: true,
                        onTap: () => setState(() => _section = sec),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (running && !mobile)
                  Container(
                    width: 196,
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      border: BorderDirectional(
                        end: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: Column(
                      children: [
                        for (final (sec, icon, label, count) in nav)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: _NavItem(
                              icon: icon,
                              label: label,
                              count: count,
                              active: _section == sec,
                              onTap: () => setState(() => _section = sec),
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(child: FadeThrough(child: content)),
              ],
            ),
          ),
          if (_log != null && _log!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.bgCode,
              child: Text(
                _log!,
                style: hubMono.copyWith(fontSize: 11, color: AppColors.text3),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _header(AppStrings s) {
    final (label, color) = switch (_status) {
      OllamaLocalStatus.running => (s.running, AppColors.green),
      OllamaLocalStatus.installedNotRunning => (
        s.stoppedStatus,
        AppColors.yellow,
      ),
      OllamaLocalStatus.notInstalled => (s.notInstalled, AppColors.red),
      OllamaLocalStatus.unsupported => (s.unsupported, AppColors.text3),
    };
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 12, 14),
      child: Row(
        children: [
          const Icon(
            Icons.view_in_ar_outlined,
            color: AppColors.accent,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    s.ollamaManagerTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text1,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (!_loading)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(label, style: TextStyle(color: color, fontSize: 12)),
                    ],
                  ),
              ],
            ),
          ),
          HoverIconButton(
            icon: Icons.refresh_rounded,
            tooltip: s.refresh,
            iconSize: 17,
            enabled: !_loading && !_busy,
            onPressed: _refreshAll,
          ),
          if (!widget.embedded ||
              MediaQuery.sizeOf(context).width < mobileBreakpoint)
            HoverIconButton(
              icon: Icons.close_rounded,
              tooltip: s.close,
              iconSize: 17,
              onPressed: widget.onClose,
            ),
        ],
      ),
    );
  }

  // ── Library ───────────────────────────────────────────────────────────────

  Widget _searchField(AppStrings s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: SizedBox(
        height: 40,
        child: TextField(
          decoration: InputDecoration(
            hintText: s.searchModels,
            prefixIcon: const Icon(Icons.search_rounded, size: 17),
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          style: const TextStyle(fontSize: 13),
          onChanged: (v) => setState(() => _search = v),
        ),
      ),
    );
  }

  Widget _libraryView(AppStrings s) {
    final q = _search.trim().toLowerCase();
    final items = q.isEmpty
        ? _families
        : _families.where((f) {
            if (f.name.toLowerCase().contains(q)) return true;
            final variants = _variantsCache[f.name] ?? f.featuredVariants;
            return variants.any((v) => v.fullName.toLowerCase().contains(q));
          }).toList();

    return Column(
      children: [
        _searchField(s),
        Expanded(
          child: _families.isEmpty
              ? const Center(
                  child: SizedBox(
                    width: 140,
                    child: SmoothProgressBar(height: 3),
                  ),
                )
              : items.isEmpty
              ? HubEmpty(
                  icon: Icons.search_off_rounded,
                  message: s.noModelsFound,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final family = items[index];
                    final variants =
                        _variantsCache[family.name] ?? family.featuredVariants;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _FamilyTile(
                        family: family,
                        expanded: _expanded.contains(family.name),
                        loading: _loadingVariants.contains(family.name),
                        variants: variants,
                        hub: _hub,
                        isInstalled: _isInstalled,
                        onToggle: () => _toggleFamily(family.name),
                        onInstall: _hub.enqueuePull,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Downloads ─────────────────────────────────────────────────────────────

  Widget _downloadsView(AppStrings s) {
    final tasks = _hub.tasks.reversed.toList();
    if (tasks.isEmpty) {
      return HubEmpty(
        icon: Icons.downloading_rounded,
        message: s.noActiveDownloads,
      );
    }
    final hasFinished = tasks.any((t) => !t.isPending);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (hasFinished)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: _hub.clearFinished,
              icon: const Icon(Icons.clear_all_rounded, size: 16),
              label: Text(s.clearFinished),
            ),
          ),
        for (final t in tasks)
          Padding(
            key: ValueKey(t.id),
            padding: const EdgeInsets.only(bottom: 8),
            child: FadeSlideIn(
              offset: const Offset(0, 8),
              child: HubTaskTile(
                task: t,
                strings: s,
                onPause: () => _hub.pause(t.id),
                onResume: () => _hub.resume(t.id),
                onCancel: () => _hub.cancel(t.id),
                onRetry: () => _hub.retry(t.id),
              ),
            ),
          ),
      ],
    );
  }

  // ── Installed ─────────────────────────────────────────────────────────────

  Widget _installedView(AppStrings s) {
    final q = _search.trim().toLowerCase();
    final items = q.isEmpty
        ? _installed
        : _installed.where((m) => m.name.toLowerCase().contains(q)).toList();
    return Column(
      children: [
        _searchField(s),
        Expanded(
          child: items.isEmpty
              ? HubEmpty(
                  icon: Icons.inventory_2_outlined,
                  message: s.noModelsInstalledHint,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final m = items[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: HubCard(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          14,
                          11,
                          8,
                          11,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(
                                      m.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13.5,
                                        color: AppColors.text1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      if (m.size > 0)
                                        HubTag(
                                          formatBytes(m.size),
                                          icon: Icons.sd_storage_outlined,
                                        ),
                                      if (m.parameterSize != null)
                                        HubTag(
                                          m.parameterSize!,
                                          color: AppColors.teal,
                                        ),
                                      if (m.quantization != null)
                                        HubTag(
                                          m.quantization!,
                                          color: AppColors.purple,
                                        ),
                                      if (m.family != null) HubTag(m.family!),
                                      if (ModelCapabilities.isVisionModel(
                                        m.name,
                                      ))
                                        HubTag(
                                          s.vision,
                                          color: AppColors.accent,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            HoverIconButton(
                              icon: Icons.article_outlined,
                              tooltip: 'Modelfile',
                              onPressed: () => _showModelfile(m.name),
                            ),
                            HoverIconButton(
                              icon: Icons.delete_outline_rounded,
                              tooltip: s.delete,
                              enabled: !_busy,
                              onPressed: () => _deleteModel(m.name),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Setup (Ollama not reachable) ──────────────────────────────────────────

  Widget _setupPanel(AppStrings s) {
    final (icon, color, title, subtitle) = switch (_status) {
      OllamaLocalStatus.running => (
        Icons.check_circle_rounded,
        AppColors.green,
        s.ollamaRunning,
        s.ollamaRunningSubtitle,
      ),
      OllamaLocalStatus.installedNotRunning => (
        Icons.pause_circle_outline_rounded,
        AppColors.yellow,
        s.ollamaStopped,
        s.ollamaStoppedSubtitle,
      ),
      OllamaLocalStatus.notInstalled => (
        Icons.error_outline_rounded,
        AppColors.red,
        s.ollamaNotInstalled,
        s.ollamaNotInstalledSubtitle,
      ),
      OllamaLocalStatus.unsupported => (
        Icons.info_outline_rounded,
        AppColors.text3,
        s.platformNotSupported,
        s.platformNotSupportedSubtitle,
      ),
    };
    const body = TextStyle(color: AppColors.text3, fontSize: 13, height: 1.7);
    const heading = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 15,
      color: AppColors.text1,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            FadeSlideIn(
              child: HubCard(
                borderColor: color.withValues(alpha: 0.3),
                child: Row(
                  children: [
                    Icon(icon, color: color, size: 26),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.text1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: AppColors.text3,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_manager.isDesktopLinux) ...[
              Text(s.installOnLinux, style: heading),
              const SizedBox(height: 8),
              Text(s.installLinuxDescription, style: body),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (_status == OllamaLocalStatus.installedNotRunning)
                    FilledButton.icon(
                      onPressed: _busy ? null : _enableService,
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(s.startSystemdService),
                    ),
                  if (_status == OllamaLocalStatus.notInstalled)
                    FilledButton.icon(
                      onPressed: _busy ? null : _installLinux,
                      icon: _busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                              ),
                            )
                          : const Icon(Icons.download_rounded, size: 16),
                      label: Text(s.installOllama),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Text(s.manualCommands, style: heading),
              const SizedBox(height: 8),
              const _Command(OllamaManagerService.linuxInstallCmd),
              const SizedBox(height: 6),
              const _Command('sudo systemctl enable --now ollama'),
            ] else if (_manager.isDesktopWindows) ...[
              Text(s.installOnWindows, style: heading),
              const SizedBox(height: 8),
              Text(s.installWindowsSteps, style: body),
              const SizedBox(height: 16),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  onPressed: () =>
                      _openUrl(OllamaManagerService.windowsDownloadUrl),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(s.downloadFromGitHub),
                ),
              ),
            ] else if (_manager.isDesktopMac) ...[
              Text(s.installOnMac, style: heading),
              const SizedBox(height: 8),
              Text(s.installMacSteps, style: body),
              const SizedBox(height: 16),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  onPressed: () =>
                      _openUrl(OllamaManagerService.macDownloadUrl),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(s.downloadForMac),
                ),
              ),
            ] else ...[
              Text(s.ollamaNotAvailable, style: heading),
              const SizedBox(height: 8),
              Text(s.ollamaNotAvailableDescription, style: body),
            ],
          ],
        ),
      ),
    );
  }
}

class _HubFrame extends StatelessWidget {
  const _HubFrame({
    required this.embedded,
    required this.mobile,
    required this.size,
    required this.child,
  });

  final bool embedded;
  final bool mobile;
  final Size size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (embedded) {
      return Material(color: Colors.transparent, child: child);
    }
    return Dialog(
      insetPadding: mobile
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: mobile ? const RoundedRectangleBorder() : null,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: mobile
            ? BoxConstraints.tight(size)
            : const BoxConstraints(maxWidth: 980, maxHeight: 760),
        child: child,
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool active;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverSurface(
      onTap: onTap,
      builder: (context, hovered) {
        final fg = active
            ? AppColors.text1
            : hovered
            ? AppColors.text1
            : AppColors.text3;
        final label_ = Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: fg,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          ),
        );
        return AnimatedContainer(
          duration: AppHover.duration,
          curve: AppHover.curve,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 10,
            vertical: compact ? 6 : 9,
          ),
          decoration: BoxDecoration(
            color: active
                ? AppColors.bgActive
                : hovered
                ? AppColors.bgHover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(compact ? 20 : 9),
          ),
          child: Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Icon(icon, size: 16, color: active ? AppColors.accent : fg),
              SizedBox(width: compact ? 7 : 10),
              if (compact) label_ else Expanded(child: label_),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: active ? AppColors.accent : AppColors.text4,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Command extends StatelessWidget {
  const _Command(this.code);
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.bgCode,
        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
        border: Border.all(color: AppColors.border),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            Expanded(child: SelectableText(code, style: hubMono)),
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

class _FamilyTile extends StatelessWidget {
  const _FamilyTile({
    required this.family,
    required this.expanded,
    required this.loading,
    required this.variants,
    required this.hub,
    required this.isInstalled,
    required this.onToggle,
    required this.onInstall,
  });

  final OllamaModelFamily family;
  final bool expanded;
  final bool loading;
  final List<OllamaModelVariant> variants;
  final ModelHubController hub;
  final bool Function(String name) isInstalled;
  final VoidCallback onToggle;
  final void Function(String name) onInstall;

  Map<String, List<OllamaModelVariant>> get _grouped {
    final groups = <String, List<OllamaModelVariant>>{};
    for (final v in variants) {
      groups.putIfAbsent(v.groupKey, () => []).add(v);
    }
    for (final list in groups.values) {
      list.sort((a, b) => a.displayLabel.compareTo(b.displayLabel));
    }
    return Map.fromEntries(
      groups.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final installedCount = variants
        .where((v) => isInstalled(v.fullName))
        .length;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return HubCard(
      padding: EdgeInsets.zero,
      borderColor: expanded ? AppColors.borderMd : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HoverSurface(
            onTap: onToggle,
            builder: (context, hovered) => Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 12, 14, 12),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: expanded ? (rtl ? -0.25 : 0.25) : 0,
                    duration: AppMotion.base,
                    curve: AppMotion.emphasized,
                    child: Icon(
                      rtl
                          ? Icons.chevron_left_rounded
                          : Icons.chevron_right_rounded,
                      color: hovered ? AppColors.text1 : AppColors.text3,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            family.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.text1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          variants.isEmpty
                              ? s.expandVariants
                              : s.variantsInfo(variants.length, installedCount),
                          style: const TextStyle(
                            color: AppColors.text3,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (ModelCapabilities.isAudioModel(family.name))
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 6),
                      child: HubTag(
                        s.audio,
                        icon: Icons.mic_none_rounded,
                        color: AppColors.yellow,
                      ),
                    ),
                  if (ModelCapabilities.isVisionModel(family.name))
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 6),
                      child: HubTag(
                        s.vision,
                        icon: Icons.visibility_outlined,
                        color: AppColors.accent,
                      ),
                    ),
                  if (installedCount > 0)
                    const Padding(
                      padding: EdgeInsetsDirectional.only(start: 8),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 15,
                        color: AppColors.green,
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
            child: !expanded
                ? const SizedBox(width: double.infinity)
                : Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: loading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: SizedBox(
                                width: 120,
                                child: SmoothProgressBar(height: 3),
                              ),
                            ),
                          )
                        : variants.isEmpty
                        ? Text(
                            s.noVariantsFound,
                            style: const TextStyle(
                              color: AppColors.text4,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          )
                        : Directionality(
                            textDirection: TextDirection.ltr,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final group in _grouped.entries) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 6,
                                      top: 2,
                                    ),
                                    child: Text(
                                      group.key.toUpperCase(),
                                      style: const TextStyle(
                                        color: AppColors.text4,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      for (final v in group.value)
                                        _VariantChip(
                                          variant: v,
                                          installed: isInstalled(v.fullName),
                                          task: hub.taskForModel(v.fullName),
                                          onInstall: () =>
                                              onInstall(v.fullName),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ],
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _VariantChip extends StatelessWidget {
  const _VariantChip({
    required this.variant,
    required this.installed,
    required this.task,
    required this.onInstall,
  });

  final OllamaModelVariant variant;
  final bool installed;
  final HubTask? task;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final pulling = task != null;
    final size = variant.sizeBytes != null && variant.sizeBytes! > 0
        ? formatBytes(variant.sizeBytes!)
        : null;
    final pct = task?.fraction == null ? null : (task!.fraction! * 100).floor();

    return HoverSurface(
      enabled: !installed && !pulling,
      onTap: installed || pulling ? null : onInstall,
      builder: (context, hovered) {
        final Color border;
        final Color bg;
        if (installed) {
          border = AppColors.green.withValues(alpha: 0.3);
          bg = AppColors.green.withValues(alpha: 0.07);
        } else if (pulling) {
          border = AppColors.accent.withValues(alpha: 0.4);
          bg = AppColors.accentGlow;
        } else {
          border = hovered ? AppColors.borderFocus : AppColors.borderMd;
          bg = hovered ? AppColors.bgActive : AppColors.bgHover;
        }
        return AnimatedContainer(
          duration: AppHover.duration,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pulling)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.6),
                )
              else
                Icon(
                  installed ? Icons.check_rounded : Icons.download_rounded,
                  size: 13,
                  color: installed
                      ? AppColors.green
                      : hovered
                      ? AppColors.accent
                      : AppColors.text3,
                ),
              const SizedBox(width: 7),
              Text(
                variant.displayLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: installed ? AppColors.green : AppColors.text1,
                ),
              ),
              if (pct != null || size != null) ...[
                const SizedBox(width: 7),
                Text(
                  pct != null ? '$pct%' : size!,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: pct != null ? AppColors.accent : AppColors.text4,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ModelfileDialog extends StatelessWidget {
  const _ModelfileDialog({
    required this.name,
    required this.modelfile,
    required this.capabilities,
  });

  final String name;
  final String modelfile;
  final List<String> capabilities;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 14, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text1,
                        ),
                      ),
                    ),
                  ),
                  HoverIconButton(
                    icon: Icons.copy_rounded,
                    tooltip: s.copy,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: modelfile));
                      context.read<AppState>().showToast(
                        s.copied,
                        type: ToastType.ok,
                      );
                    },
                  ),
                  HoverIconButton(
                    icon: Icons.close_rounded,
                    tooltip: s.close,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              if (capabilities.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in capabilities)
                      HubTag(c, color: AppColors.accent),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bgCode,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SingleChildScrollView(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: SelectableText(modelfile, style: hubMono),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
