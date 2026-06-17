import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../models/ollama_models.dart';
import '../services/model_capabilities.dart';
import '../services/ollama_manager_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'ollama_hardware_guide.dart';

class OllamaManagerDialog extends StatefulWidget {
  const OllamaManagerDialog({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<OllamaManagerDialog> createState() => _OllamaManagerDialogState();
}

class _OllamaManagerDialogState extends State<OllamaManagerDialog>
    with SingleTickerProviderStateMixin {
  late final OllamaManagerService _manager;
  late TabController _tabs;

  OllamaLocalStatus _status = OllamaLocalStatus.notInstalled;
  bool _loading = true;
  bool _busy = false;
  String? _log;
  List<OllamaModelFamily> _families = [];
  Map<String, List<OllamaModelVariant>> _variantsCache = {};
  Set<String> _expandedFamilies = {};
  Set<String> _loadingVariants = {};
  Set<String> _installed = {};
  String _search = '';
  final Map<String, _DownloadEntry> _downloads = {};
  String? _activeDownloadModel;

  @override
  void initState() {
    super.initState();
    _manager = context.read<AppState>().ollamaManager;
    _tabs = TabController(length: 4, vsync: this);
    _refreshAll();
  }

  @override
  void dispose() {
    for (final entry in _downloads.values) {
      entry.session?.cancel();
      entry.sub?.cancel();
    }
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    setState(() {
      _loading = true;
      _log = null;
    });

    final state = context.read<AppState>();
    final status = await _manager.checkConnection(state.settings);
    List<OllamaModelFamily> families = [];
    Set<String> installed = {};

    if (status == OllamaLocalStatus.running) {
      families = await _manager.fetchLibraryFamilies();
      installed = await _manager.fetchInstalledModelNames(state.settings);
    }

    if (!mounted) return;
    setState(() {
      _status = status;
      _families = families;
      _variantsCache = {};
      _expandedFamilies = {};
      _loadingVariants = {};
      _installed = installed;
      _loading = false;
    });
  }

  Future<void> _toggleFamily(String name) async {
    if (_expandedFamilies.contains(name)) {
      setState(() => _expandedFamilies = {..._expandedFamilies}..remove(name));
      return;
    }

    setState(() {
      _expandedFamilies = {..._expandedFamilies, name};
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

  Future<void> _installLinux() async {
    setState(() {
      _busy = true;
      _log = '';
    });
    final result = await _manager.installOnLinux(
      s: context.read<AppState>().strings,
      onLog: (line) {
        if (mounted) setState(() => _log = line);
      },
    );
    if (!mounted) return;
    final state = context.read<AppState>();
    state.showToast(
      result.success ? '✓ ${result.message}' : '⚠ ${result.message}',
      type: result.success ? ToastType.ok : ToastType.err,
    );
    setState(() => _busy = false);
    await _refreshAll();
    if (_status == OllamaLocalStatus.running) {
      await state.fetchModels(silent: true);
    }
  }

  Future<void> _enableService() async {
    setState(() {
      _busy = true;
      _log = '';
    });
    var result = await _manager.enableSystemdService(
      s: context.read<AppState>().strings,
      onLog: (line) {
        if (mounted) setState(() => _log = line);
      },
    );
    if (!result.success) {
      result = await _manager.startOllamaServe(
        s: context.read<AppState>().strings,
        onLog: (line) {
          if (mounted) setState(() => _log = line);
        },
      );
    }
    if (!mounted) return;
    final state = context.read<AppState>();
    state.showToast(
      result.success ? '✓ ${result.message}' : '⚠ ${result.message}',
      type: result.success ? ToastType.ok : ToastType.err,
    );
    setState(() => _busy = false);
    await _refreshAll();
    if (_status == OllamaLocalStatus.running) {
      await state.fetchModels(silent: true);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        context
            .read<AppState>()
            .showToast('Failed to open link', type: ToastType.err);
      }
    }
  }

  Future<void> _pullModel(String name) async {
    if (_downloads.containsKey(name) &&
        _downloads[name]!.state != OllamaDownloadState.failed) {
      return;
    }
    if (_isInstalled(name)) return;

    setState(() {
      _downloads[name] = _DownloadEntry(
        model: name,
        state: _activeDownloadModel == null
            ? OllamaDownloadState.downloading
            : OllamaDownloadState.queued,
      );
    });

    if (_activeDownloadModel == null) {
      await _startDownload(name);
    }
  }

  Future<void> _startDownload(String name) async {
    final entry = _downloads[name];
    if (entry == null) return;

    entry.session?.cancel();
    entry.sub?.cancel();
    entry.tracker.reset();

    setState(() {
      _activeDownloadModel = name;
      entry.state = OllamaDownloadState.downloading;
      entry.progress = OllamaPullProgress(
        model: name,
        status: 'pulling manifest',
      );
    });

    final state = context.read<AppState>();
    final session = _manager.startPull(name, state.settings);
    entry.session = session;

    entry.sub = session.stream.listen((raw) async {
      if (!mounted) return;
      final progress = entry.tracker.enrich(raw);
      setState(() => entry.progress = progress);

      if (progress.done) {
        entry.sub?.cancel();
        entry.session = null;

        if (progress.error != null && progress.error!.isNotEmpty) {
          setState(() {
            entry.state = OllamaDownloadState.failed;
            entry.error = progress.error;
          });
          state.showToast('Error: ${progress.error}', type: ToastType.err);
        } else {
          state.showToast('✓ $name installed', type: ToastType.ok);
          await state.fetchModels(silent: true);
          final installed =
              await _manager.fetchInstalledModelNames(state.settings);
          if (!mounted) return;
          setState(() {
            _installed = installed;
            entry.state = OllamaDownloadState.completed;
            entry.progress = progress;
          });
          Future.delayed(const Duration(seconds: 2), () {
            if (!mounted) return;
            setState(() => _downloads.remove(name));
          });
        }

        _activeDownloadModel = null;
        await _startNextQueuedDownload();
      }
    });
  }

  Future<void> _startNextQueuedDownload() async {
    if (_activeDownloadModel != null) return;
    final next = _downloads.entries
        .where((e) => e.value.state == OllamaDownloadState.queued)
        .map((e) => e.key)
        .firstOrNull;
    if (next != null) {
      await _startDownload(next);
    }
  }

  void _pauseDownload(String name) {
    final entry = _downloads[name];
    if (entry == null || entry.state != OllamaDownloadState.downloading) {
      return;
    }
    entry.session?.cancel();
    entry.sub?.cancel();
    entry.session = null;
    entry.sub = null;
    setState(() {
      entry.state = OllamaDownloadState.paused;
      if (_activeDownloadModel == name) {
        _activeDownloadModel = null;
      }
    });
    _startNextQueuedDownload();
  }

  void _resumeDownload(String name) {
    final entry = _downloads[name];
    if (entry == null || entry.state != OllamaDownloadState.paused) return;

    setState(() {
      entry.state = _activeDownloadModel == null
          ? OllamaDownloadState.downloading
          : OllamaDownloadState.queued;
    });

    if (_activeDownloadModel == null) {
      _startDownload(name);
    }
  }

  void _cancelDownload(String name) {
    final entry = _downloads[name];
    if (entry == null) return;
    entry.session?.cancel();
    entry.sub?.cancel();
    setState(() {
      _downloads.remove(name);
      if (_activeDownloadModel == name) {
        _activeDownloadModel = null;
      }
    });
    _startNextQueuedDownload();
  }

  bool _isDownloading(String name) {
    final entry = _downloads[name];
    if (entry == null) return false;
    return entry.state == OllamaDownloadState.downloading ||
        entry.state == OllamaDownloadState.queued ||
        entry.state == OllamaDownloadState.paused;
  }

  OllamaPullProgress? _progressFor(String name) => _downloads[name]?.progress;

  int get _activeDownloadCount => _downloads.values
      .where((e) =>
          e.state == OllamaDownloadState.downloading ||
          e.state == OllamaDownloadState.queued ||
          e.state == OllamaDownloadState.paused)
      .length;

  Future<void> _deleteModel(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete model'),
        content: Text('Remove "$name" from Ollama?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final state = context.read<AppState>();
    setState(() => _busy = true);
    try {
      await _manager.deleteModel(name, state.settings);
      state.showToast('✓ $name removed', type: ToastType.ok);
      await state.fetchModels(silent: true);
      final installed = await _manager.fetchInstalledModelNames(state.settings);
      if (mounted) setState(() => _installed = installed);
    } catch (e) {
      if (mounted) {
        context.read<AppState>().showToast('Error: $e', type: ToastType.err);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _isInstalled(String name) {
    return _installed.any((i) => ollamaModelNamesMatch(i, name));
  }

  List<OllamaModelFamily> get _filteredFamilies {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _families;
    return _families.where((f) {
      if (f.name.toLowerCase().contains(q)) return true;
      final cached = _variantsCache[f.name];
      if (cached != null) {
        return cached.any(
          (v) =>
              v.fullName.toLowerCase().contains(q) ||
              (v.parameterSize?.toLowerCase().contains(q) ?? false) ||
              (v.quantization?.toLowerCase().contains(q) ?? false),
        );
      }
      return f.featuredVariants.any(
        (v) => v.fullName.toLowerCase().contains(q),
      );
    }).toList();
  }

  List<String> get _filteredInstalled {
    final q = _search.trim().toLowerCase();
    final list = _installed.toList()..sort();
    if (q.isEmpty) return list;
    return list.where((n) => n.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgPanel,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _dialogHeader(),
            const Divider(height: 1, color: AppColors.border),
            if (_loading)
              const Expanded(child: _LoadingView())
            else if (_status != OllamaLocalStatus.running)
              Expanded(child: _setupPanel())
            else ...[
              _searchBar(),
              _tabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _libraryList(),
                    _downloadingList(),
                    _installedList(),
                    const OllamaHardwareGuide(),
                  ],
                ),
              ),
            ],
            if (_log != null && _log!.isNotEmpty) _logPanel(),
          ],
        ),
      ),
    );
  }

  Widget _dialogHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 12, 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accentGlow,
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.memory_rounded, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            'Ollama Manager',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.text1,
            ),
          ),
          const SizedBox(width: 8),
          _StatusBadge(status: _loading ? null : _status),
          const Spacer(),
          IconButton(
            onPressed: _loading || _busy ? null : _refreshAll,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.bgHover,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.bgHover,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    final s = context.s;
    return TabBar(
      controller: _tabs,
      indicatorColor: AppColors.accent,
      indicatorWeight: 2,
      labelColor: AppColors.accent,
      unselectedLabelColor: AppColors.text3,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: [
        Tab(text: s.library),
        Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.downloadingTab),
              if (_activeDownloadCount > 0) ...[
                const SizedBox(width: 6),
                _CountBadge(count: _activeDownloadCount),
              ],
            ],
          ),
        ),
        Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.installed),
              if (_installed.isNotEmpty) ...[
                const SizedBox(width: 6),
                _CountBadge(count: _installed.length),
              ],
            ],
          ),
        ),
        Tab(text: s.hardwareGuide),
      ],
    );
  }

  Widget _searchBar() {
    final s = context.s;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        decoration: InputDecoration(
          hintText: s.searchModels,
          prefixIcon: const Icon(Icons.search_rounded, size: 18),
          isDense: true,
        ),
        onChanged: (v) => setState(() => _search = v),
      ),
    );
  }

  Widget _setupPanel() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _StatusCard(status: _status),
        const SizedBox(height: 24),
        if (_manager.isDesktopLinux) ...[
          const _SetupHeading('Install on Linux'),
          const SizedBox(height: 8),
          const Text(
            'Ollama will be installed automatically. Requires administrator access (sudo/pkexec). '
            'After installation, the systemd service is enabled so Ollama runs in the background.',
            style: TextStyle(color: AppColors.text3, fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _installLinux,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_rounded),
            label: const Text('Install Ollama'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (_status == OllamaLocalStatus.installedNotRunning) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : _enableService,
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Text('Start systemd service'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.borderMd),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
          if (_status == OllamaLocalStatus.installedNotRunning) ...[
            const SizedBox(height: 24),
            const _SetupHeading('Manual commands'),
            const SizedBox(height: 8),
            _CodeBlock(OllamaManagerService.linuxInstallCmd),
            const SizedBox(height: 6),
            const _CodeBlock('sudo systemctl enable --now ollama'),
          ],
        ] else if (_manager.isDesktopWindows) ...[
          const _SetupHeading('Install on Windows'),
          const SizedBox(height: 8),
          const Text(
            '1. Download OllamaSetup.exe from GitHub.\n'
            '2. Run the installer and follow the steps.\n'
            '3. After installation, Ollama runs automatically in the system tray.\n'
            '4. Come back here and press the refresh button.',
            style: TextStyle(color: AppColors.text3, fontSize: 13, height: 1.8),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openUrl(OllamaManagerService.windowsDownloadUrl),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Download from GitHub'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ] else ...[
          const _SetupHeading('Ollama not available'),
          const SizedBox(height: 8),
          const Text(
            'To use Ollama, install and run it on your system or network, '
            'then configure the Ollama URL in Settings.',
            style: TextStyle(color: AppColors.text3, fontSize: 13, height: 1.6),
          ),
        ],
      ],
    );
  }

  Widget _logPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.bgCode,
      child: Row(
        children: [
          const Icon(Icons.terminal_rounded, size: 14, color: AppColors.text3),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _log!,
              style: const TextStyle(
                color: AppColors.text3,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _libraryList() {
    final items = _filteredFamilies;
    if (items.isEmpty) {
      return _EmptyView(
        icon: Icons.search_off_rounded,
        message: context.s.noModelsFound,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final family = items[index];
        final expanded = _expandedFamilies.contains(family.name);
        final loadingVariants = _loadingVariants.contains(family.name);
        final variants = _variantsCache[family.name] ?? family.featuredVariants;
        final installedCount = variants.where((v) => _isInstalled(v.fullName)).length;

        return _ModelFamilyTile(
          family: family,
          expanded: expanded,
          loadingVariants: loadingVariants,
          variants: variants,
          installedCount: installedCount,
          installedNames: _installed,
          downloads: _downloads,
          onToggle: () => _toggleFamily(family.name),
          onInstall: (name) => _pullModel(name),
          isInstalled: _isInstalled,
          isDownloading: _isDownloading,
          progressFor: _progressFor,
        );
      },
    );
  }

  Widget _downloadingList() {
    final s = context.s;
    final items = _downloads.entries
        .where((e) =>
            e.value.state == OllamaDownloadState.downloading ||
            e.value.state == OllamaDownloadState.queued ||
            e.value.state == OllamaDownloadState.paused ||
            e.value.state == OllamaDownloadState.failed)
        .toList()
      ..sort((a, b) {
        const order = {
          OllamaDownloadState.downloading: 0,
          OllamaDownloadState.paused: 1,
          OllamaDownloadState.queued: 2,
          OllamaDownloadState.failed: 3,
        };
        return (order[a.value.state] ?? 9).compareTo(order[b.value.state] ?? 9);
      });

    if (items.isEmpty) {
      return _EmptyView(
        icon: Icons.download_outlined,
        message: s.noActiveDownloads,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = items[index].value;
        return _DownloadTile(
          entry: entry,
          onPause: () => _pauseDownload(entry.model),
          onResume: () => _resumeDownload(entry.model),
          onCancel: () => _cancelDownload(entry.model),
          onRetry: () {
            setState(() {
              entry.state = OllamaDownloadState.queued;
              entry.error = null;
            });
            if (_activeDownloadModel == null) {
              _startDownload(entry.model);
            }
          },
        );
      },
    );
  }

  Widget _installedList() {
    final s = context.s;
    final items = _filteredInstalled;
    if (items.isEmpty) {
      return _EmptyView(
        icon: Icons.inbox_rounded,
        message: s.noModelsInstalledHint,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final name = items[index];
        return _ModelTile(
          name: name,
          subtitle: 'Installed',
          installed: true,
          pulling: false,
          progress: null,
          onInstall: null,
          onDelete: _busy ? null : () => _deleteModel(name),
        );
      },
    );
  }
}

// ─── Download state ───────────────────────────────────────────────────────────

class _DownloadEntry {
  _DownloadEntry({required this.model, required this.state});

  final String model;
  OllamaDownloadState state;
  OllamaPullProgress? progress;
  String? error;
  final OllamaDownloadSpeedTracker tracker = OllamaDownloadSpeedTracker();
  OllamaPullSession? session;
  StreamSubscription<OllamaPullProgress>? sub;
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.accent),
          SizedBox(height: 12),
          Text('Loading…', style: TextStyle(color: AppColors.text3)),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: AppColors.text4),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(color: AppColors.text4, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final OllamaLocalStatus? status;

  @override
  Widget build(BuildContext context) {
    if (status == null) return const SizedBox.shrink();

    final (label, color) = switch (status!) {
      OllamaLocalStatus.running => ('Running', AppColors.green),
      OllamaLocalStatus.installedNotRunning => ('Stopped', AppColors.yellow),
      OllamaLocalStatus.notInstalled => ('Not installed', AppColors.red),
      OllamaLocalStatus.unsupported => ('Unsupported', AppColors.text3),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.accentGlow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final OllamaLocalStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, subtitle) = switch (status) {
      OllamaLocalStatus.running => (
          Icons.check_circle_rounded,
          AppColors.green,
          'Ollama is running',
          'You can install and manage models.',
        ),
      OllamaLocalStatus.installedNotRunning => (
          Icons.warning_amber_rounded,
          AppColors.yellow,
          'Ollama is installed but not running',
          'Start the service to continue.',
        ),
      OllamaLocalStatus.notInstalled => (
          Icons.error_outline_rounded,
          AppColors.red,
          'Ollama is not installed',
          'Install Ollama to get started.',
        ),
      OllamaLocalStatus.unsupported => (
          Icons.info_outline_rounded,
          AppColors.text3,
          'Platform not supported',
          'Local installation is unavailable on this platform.',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style:
                      const TextStyle(color: AppColors.text3, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupHeading extends StatelessWidget {
  const _SetupHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: AppColors.text1,
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock(this.code);

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgCode,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderMd),
      ),
      child: SelectableText(
        code,
        style: const TextStyle(
          color: AppColors.text2,
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ModelFamilyTile extends StatelessWidget {
  const _ModelFamilyTile({
    required this.family,
    required this.expanded,
    required this.loadingVariants,
    required this.variants,
    required this.installedCount,
    required this.installedNames,
    required this.downloads,
    required this.onToggle,
    required this.onInstall,
    required this.isInstalled,
    required this.isDownloading,
    required this.progressFor,
  });

  final OllamaModelFamily family;
  final bool expanded;
  final bool loadingVariants;
  final List<OllamaModelVariant> variants;
  final int installedCount;
  final Set<String> installedNames;
  final Map<String, _DownloadEntry> downloads;
  final VoidCallback onToggle;
  final void Function(String name)? onInstall;
  final bool Function(String name) isInstalled;
  final bool Function(String name) isDownloading;
  final OllamaPullProgress? Function(String name) progressFor;

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
    final activeInFamily = downloads.keys
        .where((name) =>
            name == family.name || name.startsWith('${family.name}:'))
        .where((name) {
          final st = downloads[name]!.state;
          return st == OllamaDownloadState.downloading ||
              st == OllamaDownloadState.paused;
        })
        .firstOrNull;
    final familyProgress =
        activeInFamily != null ? progressFor(activeInFamily) : null;
    final hasPullInFamily = activeInFamily != null && familyProgress != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasPullInFamily
              ? AppColors.accent.withAlpha(100)
              : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.text3,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            family.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.text1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            variants.isEmpty
                                ? s.expandVariants
                                : s.variantsInfo(variants.length, installedCount),
                            style: const TextStyle(
                              color: AppColors.text3,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (ModelCapabilities.isAudioModel(family.name))
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _CapabilityChip(
                          icon: Icons.mic_rounded,
                          label: s.audio,
                          color: AppColors.yellow,
                        ),
                      ),
                    if (ModelCapabilities.isVisionModel(family.name))
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _CapabilityChip(
                          icon: Icons.visibility_outlined,
                          label: s.vision,
                          color: AppColors.accent,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: AppColors.border),
            if (loadingVariants)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              )
            else if (variants.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  s.noVariantsFound,
                  style: const TextStyle(color: AppColors.text4, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  children: _grouped.entries.map((group) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                            child: Text(
                              group.key,
                              style: const TextStyle(
                                color: AppColors.text3,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: group.value.map((variant) {
                              final installed = isInstalled(variant.fullName);
                              final pulling = isDownloading(variant.fullName);
                              return _VariantChip(
                                variant: variant,
                                installed: installed,
                                pulling: pulling,
                                onInstall: installed
                                    ? null
                                    : () => onInstall?.call(variant.fullName),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
          if (hasPullInFamily)
            _PullProgressBar(
              progress: familyProgress,
              state: downloads[activeInFamily]!.state,
              compact: true,
            ),
        ],
      ),
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
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
    required this.pulling,
    required this.onInstall,
  });

  final OllamaModelVariant variant;
  final bool installed;
  final bool pulling;
  final VoidCallback? onInstall;

  @override
  Widget build(BuildContext context) {
    final sizeLabel = variant.sizeBytes != null && variant.sizeBytes! > 0
        ? formatBytes(variant.sizeBytes!)
        : null;

    return Material(
      color: installed
          ? AppColors.green.withAlpha(18)
          : pulling
              ? AppColors.accentGlow
              : AppColors.bgHover,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onInstall,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: installed
                  ? AppColors.green.withAlpha(60)
                  : pulling
                      ? AppColors.accent.withAlpha(80)
                      : AppColors.borderMd,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pulling)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              else if (installed)
                const Icon(Icons.check_rounded, size: 13, color: AppColors.green)
              else
                Icon(
                  Icons.download_rounded,
                  size: 13,
                  color: onInstall != null ? AppColors.accent : AppColors.text4,
                ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    variant.displayLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: installed ? AppColors.green : AppColors.text1,
                    ),
                  ),
                  if (sizeLabel != null)
                    Text(
                      sizeLabel,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.text4,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PullProgressBar extends StatefulWidget {
  const _PullProgressBar({
    required this.progress,
    required this.state,
    this.onPause,
    this.onResume,
    this.onCancel,
    this.compact = false,
  });

  final OllamaPullProgress progress;
  final OllamaDownloadState state;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;
  final bool compact;

  @override
  State<_PullProgressBar> createState() => _PullProgressBarState();
}

class _PullProgressBarState extends State<_PullProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.progress;
    final s = context.s;
    final fraction = p.fraction;
    final percent = p.percent;
    final isPaused = widget.state == OllamaDownloadState.paused;
    final statusText = isPaused
        ? s.downloadPaused
        : p.statusLabel(s);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withAlpha(12),
            AppColors.accent.withAlpha(4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.model,
                  style: const TextStyle(
                    color: AppColors.text2,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (percent != null)
                Text(
                  '$percent%',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: AppColors.bgHover),
                  if (fraction != null && !isPaused)
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: fraction,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.accent,
                              AppColors.accent.withAlpha(180),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (!isPaused)
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, _) {
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final w = constraints.maxWidth;
                            final band = w * 0.35;
                            final left = (w + band) * _pulse.value - band;
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  left: left,
                                  top: 0,
                                  bottom: 0,
                                  width: band,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.accent.withAlpha(0),
                                          AppColors.accent.withAlpha(200),
                                          AppColors.accent.withAlpha(0),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  statusText,
                  style: const TextStyle(color: AppColors.text3, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (p.speedBytesPerSec != null && p.speedBytesPerSec! > 0) ...[
                Text(
                  formatSpeed(p.speedBytesPerSec!),
                  style: const TextStyle(
                    color: AppColors.text3,
                    fontSize: 10,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (p.etaSeconds != null) ...[
                  const Text(' · ',
                      style: TextStyle(color: AppColors.text4, fontSize: 10)),
                  Text(
                    formatEta(p.etaSeconds!, s),
                    style: const TextStyle(
                      color: AppColors.text4,
                      fontSize: 10,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
              if (p.completed != null && p.total != null && p.total! > 0) ...[
                if (p.speedBytesPerSec != null) const SizedBox(width: 8),
                Text(
                  '${formatBytes(p.completed!)} / ${formatBytes(p.total!)}',
                  style: const TextStyle(
                    color: AppColors.text4,
                    fontSize: 10,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
          if (!widget.compact &&
              (widget.onPause != null ||
                  widget.onResume != null ||
                  widget.onCancel != null)) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (widget.state == OllamaDownloadState.downloading &&
                    widget.onPause != null)
                  TextButton.icon(
                    onPressed: widget.onPause,
                    icon: const Icon(Icons.pause_rounded, size: 14),
                    label: Text(s.pauseDownload),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.text2,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 30),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                  ),
                if (widget.state == OllamaDownloadState.paused &&
                    widget.onResume != null)
                  TextButton.icon(
                    onPressed: widget.onResume,
                    icon: const Icon(Icons.play_arrow_rounded, size: 14),
                    label: Text(s.resumeDownload),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 30),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                  ),
                const Spacer(),
                if (widget.onCancel != null)
                  TextButton.icon(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close_rounded, size: 14),
                    label: Text(s.cancelDownload),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 30),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({
    required this.entry,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onRetry,
  });

  final _DownloadEntry entry;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final progress = entry.progress;

    if (entry.state == OllamaDownloadState.failed) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgInput,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.red.withAlpha(80)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.model,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.text1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              entry.error ?? s.genericError,
              style: const TextStyle(color: AppColors.red, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: onRetry,
                  child: Text(s.retry),
                ),
                TextButton(
                  onPressed: onCancel,
                  child: Text(s.cancelDownload),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (entry.state == OllamaDownloadState.queued) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgInput,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.model,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.text1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.downloadQueued,
                    style: const TextStyle(color: AppColors.text3, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onCancel,
              icon: const Icon(Icons.close_rounded, size: 16),
              color: AppColors.text3,
              tooltip: s.cancelDownload,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: entry.state == OllamaDownloadState.paused
              ? AppColors.yellow.withAlpha(80)
              : AppColors.accent.withAlpha(80),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: progress != null
          ? _PullProgressBar(
              progress: progress,
              state: entry.state,
              onPause: onPause,
              onResume: onResume,
              onCancel: onCancel,
            )
          : Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.model,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.text1,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({
    required this.name,
    required this.subtitle,
    required this.installed,
    required this.pulling,
    required this.progress,
    required this.onInstall,
    required this.onDelete,
  });

  final String name;
  final String subtitle;
  final bool installed;
  final bool pulling;
  final OllamaPullProgress? progress;
  final VoidCallback? onInstall;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: pulling ? AppColors.accent.withAlpha(80) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.text1,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.text3,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (installed && !pulling)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.green.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: AppColors.green.withAlpha(60)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded,
                          size: 12, color: AppColors.green),
                      SizedBox(width: 4),
                      Text(
                        'Installed',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else if (pulling)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.accent),
                )
              else if (onInstall != null)
                FilledButton.icon(
                  onPressed: onInstall,
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: const Text('Install'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(80, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(fontSize: 12),
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              if (onDelete != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  color: AppColors.text3,
                  tooltip: 'Delete',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.bgHover,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(32, 32),
                  ),
                ),
              ],
            ],
          ),
          if (pulling && progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: progress!.fraction != null
                  ? LinearProgressIndicator(
                      value: progress!.fraction,
                      color: AppColors.accent,
                      backgroundColor: AppColors.bgHover,
                      minHeight: 4,
                    )
                  : const LinearProgressIndicator(
                      color: AppColors.accent,
                      backgroundColor: AppColors.bgHover,
                      minHeight: 4,
                    ),
            ),
            if (progress!.status != null) ...[
              const SizedBox(height: 4),
              Text(
                progress!.status!,
                style: const TextStyle(
                    color: AppColors.text3, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
