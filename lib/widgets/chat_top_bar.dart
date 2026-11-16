import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/hover_surface.dart';
import '../core/motion.dart';
import '../l10n/app_locale.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'model_selector.dart';

class ChatTopBar extends StatelessWidget {
  const ChatTopBar({
    super.key,
    this.onMenu,
    required this.onPrompt,
    required this.onSettings,
    required this.onUserProfile,
    this.onModelHub,
  });

  /// Shown when the sidebar is hidden (mobile drawer or collapsed).
  final VoidCallback? onMenu;
  final VoidCallback onPrompt;
  final VoidCallback onSettings;
  final VoidCallback onUserProfile;
  final VoidCallback? onModelHub;

  Future<void> _confirmClear(BuildContext context) async {
    final state = context.read<AppState>();
    final s = state.strings;
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.clearConversation),
        content: Text(s.clearConversationConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: Text(s.clear),
          ),
        ],
      ),
    );
    if (ok == true) await state.clearCurrentChat();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.strings;
    final mobile = MediaQuery.sizeOf(context).width < mobileBreakpoint;

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          AnimatedSize(
            duration: AppMotion.base,
            curve: AppMotion.emphasized,
            child: onMenu == null
                ? const SizedBox(height: 34)
                : Padding(
                    padding: const EdgeInsetsDirectional.only(end: 4),
                    child: HoverIconButton(
                      icon: mobile
                          ? Icons.menu_rounded
                          : Icons.view_sidebar_outlined,
                      tooltip: s.toggleSidebar,
                      iconSize: 18,
                      onPressed: onMenu,
                    ),
                  ),
          ),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: ModelSelector(onModelHub: onModelHub),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (!mobile) ...[
            if (state.hasPayloadOverride) ...[
              const _InfoPill('custom payload', color: AppColors.yellow),
              const SizedBox(width: 6),
            ],
            _InfoPill(
              '${state.contextSentCount()} / ${state.settings.contextWindow}',
              icon: Icons.layers_outlined,
              tooltip: s.contextWindow,
            ),
            const SizedBox(width: 6),
          ],
          PopupMenuButton<AppLocale>(
            tooltip: s.language,
            position: PopupMenuPosition.under,
            onSelected: state.setLocale,
            itemBuilder: (context) => [
              for (final (locale, label) in [
                (AppLocale.en, s.languageEn),
                (AppLocale.fa, s.languageFa),
              ])
                PopupMenuItem(
                  value: locale,
                  height: 40,
                  child: Row(
                    children: [
                      Expanded(child: Text(label)),
                      if (state.locale == locale)
                        const Icon(Icons.check_rounded,
                            size: 16, color: AppColors.accent),
                    ],
                  ),
                ),
            ],
            child: const _StaticIcon(Icons.translate_rounded),
          ),
          HoverIconButton(
            icon: Icons.cleaning_services_outlined,
            tooltip: s.clearConversation,
            iconSize: 17,
            onPressed: () => _confirmClear(context),
          ),
          if (mobile)
            PopupMenuButton<String>(
              position: PopupMenuPosition.under,
              onSelected: (v) {
                switch (v) {
                  case 'prompt':
                    onPrompt();
                  case 'profile':
                    onUserProfile();
                  case 'settings':
                    onSettings();
                }
              },
              itemBuilder: (context) => [
                _menuItem('prompt', Icons.tune_rounded, s.promptEngineering),
                _menuItem(
                    'profile', Icons.person_outline_rounded, s.userProfile),
                _menuItem('settings', Icons.settings_outlined, s.settings),
              ],
              child: const _StaticIcon(Icons.more_horiz_rounded),
            ),
          if (!mobile) const SizedBox(width: 4),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
    return PopupMenuItem(
      value: value,
      height: 42,
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.text3),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }
}

class _StaticIcon extends StatelessWidget {
  const _StaticIcon(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return HoverSurface(
      builder: (context, hovered) => AnimatedContainer(
        duration: AppHover.duration,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: hovered ? AppColors.bgHover : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 17,
          color: hovered ? AppColors.text1 : AppColors.text3,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill(this.text, {this.tooltip, this.color, this.icon});

  final String text;
  final String? tooltip;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.text3;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: c),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: c,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}
