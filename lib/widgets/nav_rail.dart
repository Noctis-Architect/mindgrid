import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_page.dart';
import '../core/hover_surface.dart';
import '../core/window_chrome.dart';
import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'app_logo.dart';

/// Slim vertical navigation shown on desktop.
class NavRail extends StatelessWidget {
  const NavRail({
    super.key,
    required this.page,
    required this.onSelect,
    required this.onNewChat,
  });

  final AppPage page;
  final ValueChanged<AppPage> onSelect;
  final VoidCallback onNewChat;

  static const width = 76.0;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final state = context.watch<AppState>();

    Widget item(AppPage p, IconData icon, IconData activeIcon, String label,
        {Widget? badge}) {
      return _RailItem(
        icon: icon,
        activeIcon: activeIcon,
        label: label,
        active: page == p,
        badge: badge,
        onTap: () => onSelect(p),
      );
    }

    return SizedBox(
      width: width,
      child: Column(
        children: [
          SizedBox(height: WindowChrome.enabled ? 6 : 14),
          if (!WindowChrome.enabled) ...[
            const AppLogo(size: 36, borderRadius: 11),
            const SizedBox(height: 14),
          ],
          Tooltip(
            message: s.newChat,
            child: HoverSurface(
              onTap: onNewChat,
              builder: (context, hovered) => AnimatedContainer(
                duration: AppHover.duration,
                curve: AppHover.curve,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: hovered ? AppColors.accentDim : AppColors.accent,
                  borderRadius: BorderRadius.circular(hovered ? 14 : 20),
                ),
                child: const Icon(Icons.add_rounded,
                    size: 22, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 14),
          item(AppPage.chat, Icons.chat_bubble_outline_rounded,
              Icons.chat_bubble_rounded, s.navChat),
          item(
            AppPage.models,
            Icons.view_in_ar_outlined,
            Icons.view_in_ar_rounded,
            s.navModels,
            badge: ListenableBuilder(
              listenable: state.hub,
              builder: (context, _) {
                final n = state.hub.pendingCount;
                return AnimatedScale(
                  scale: n > 0 ? 1 : 0,
                  duration: AppMotion.base,
                  curve: AppMotion.emphasized,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$n',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          item(AppPage.speech, Icons.graphic_eq_rounded,
              Icons.graphic_eq_rounded, s.navSpeech),
          item(AppPage.images, Icons.auto_awesome_outlined,
              Icons.auto_awesome_rounded, s.navImages),
          item(AppPage.prompts, Icons.tune_rounded, Icons.tune_rounded,
              s.navPrompts),
          const Spacer(),
          _RailIcon(
            icon: Icons.person_outline_rounded,
            tooltip: s.userProfile,
            active: page == AppPage.profile,
            onTap: () => onSelect(AppPage.profile),
          ),
          _RailIcon(
            icon: Icons.inventory_2_outlined,
            tooltip: s.backupExport,
            active: page == AppPage.backup,
            onTap: () => onSelect(AppPage.backup),
          ),
          _RailIcon(
            icon: Icons.settings_outlined,
            tooltip: s.settings,
            active: page == AppPage.settings,
            onTap: () => onSelect(AppPage.settings),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Widget? badge;

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
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: SizedBox(
            width: NavRail.width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: AppMotion.base,
                      curve: AppMotion.emphasized,
                      width: active ? 52 : 44,
                      height: 32,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.accentGlow
                            : hovered
                                ? AppColors.bgHover
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: AnimatedSwitcher(
                        duration: AppMotion.fast,
                        child: Icon(
                          active ? activeIcon : icon,
                          key: ValueKey(active),
                          size: 19,
                          color: active ? AppColors.accent : fg,
                        ),
                      ),
                    ),
                    if (badge != null)
                      PositionedDirectional(top: -3, end: -2, child: badge!),
                  ],
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: AppHover.duration,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: fg,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                  ),
                  child: Text(label, maxLines: 1),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RailIcon extends StatelessWidget {
  const _RailIcon({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: tooltip,
        child: HoverSurface(
          onTap: onTap,
          builder: (context, hovered) => AnimatedContainer(
            duration: AppHover.duration,
            curve: AppHover.curve,
            width: 40,
            height: 36,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.accentGlow
                  : hovered
                      ? AppColors.bgHover
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 18,
              color: active
                  ? AppColors.accent
                  : hovered
                      ? AppColors.text1
                      : AppColors.text3,
            ),
          ),
        ),
      ),
    );
  }
}
