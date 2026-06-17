import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/hover_surface.dart';
import '../core/text_direction.dart';
import '../l10n/app_locale.dart';
import '../models/app_settings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class ChatTopBar extends StatelessWidget {
  const ChatTopBar({
    super.key,
    this.onMenu,
    required this.onPrompt,
    required this.onSettings,
    required this.onUserProfile,
  });

  final VoidCallback? onMenu;
  final VoidCallback onPrompt;
  final VoidCallback onSettings;
  final VoidCallback onUserProfile;

  void _showLanguageMenu(BuildContext context) {
    final state = context.read<AppState>();
    final s = state.strings;
    final button = context.findRenderObject() as RenderBox?;
    if (button == null || !button.hasSize) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    showMenu<AppLocale>(
      context: context,
      position: position,
      color: AppColors.bgPanel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(
          value: AppLocale.en,
          child: Row(
            children: [
              if (state.locale == AppLocale.en)
                const Icon(Icons.check, size: 16, color: AppColors.accent),
              if (state.locale == AppLocale.en) const SizedBox(width: 8),
              Text(s.languageEn),
            ],
          ),
        ),
        PopupMenuItem(
          value: AppLocale.fa,
          child: Row(
            children: [
              if (state.locale == AppLocale.fa)
                const Icon(Icons.check, size: 16, color: AppColors.accent),
              if (state.locale == AppLocale.fa) const SizedBox(width: 8),
              Text(s.languageFa),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value != null) state.setLocale(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.strings;
    final mobile = MediaQuery.sizeOf(context).width < mobileBreakpoint;

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: AppColors.bgApp,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (onMenu != null)
            _TopBarIconButton(
              icon: Icons.menu_rounded,
              onPressed: onMenu!,
            ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              state.chatTitle(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: detectTextDirection(state.chatTitle()),
              textAlign: TextAlign.start,
              style: const TextStyle(
                color: AppColors.text1,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!mobile) ...[
            const SizedBox(width: 8),
            _InfoPill(state.selectedModel),
            const SizedBox(width: 4),
            _InfoPill(state.settings.provider.label),
            const SizedBox(width: 4),
            _InfoPill(
              '${state.contextSentCount()}/${state.settings.contextWindow}',
              tooltip: s.contextWindow,
            ),
            if (state.hasPayloadOverride) ...[
              const SizedBox(width: 4),
              _InfoPill('custom', color: AppColors.yellow),
            ],
            const SizedBox(width: 8),
          ],
          Builder(
            builder: (btnContext) => _TopBarIconButton(
              icon: Icons.language_rounded,
              tooltip: s.language,
              onPressed: () => _showLanguageMenu(btnContext),
            ),
          ),
          _TopBarIconButton(
            icon: Icons.delete_sweep_outlined,
            tooltip: s.clearConversation,
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                barrierColor: Colors.black54,
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
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.red),
                      child: Text(s.clear),
                    ),
                  ],
                ),
              );
              if (ok == true) await state.clearCurrentChat();
            },
          ),
          if (mobile)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  size: 18, color: AppColors.text3),
              color: AppColors.bgPanel,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
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
                PopupMenuItem(
                    value: 'prompt', child: Text(s.promptEngineering)),
                PopupMenuItem(value: 'profile', child: Text(s.userProfile)),
                PopupMenuItem(value: 'settings', child: Text(s.settings)),
              ],
            )
          else ...[
            _TopBarIconButton(
              icon: Icons.tune_outlined,
              tooltip: s.promptEngineering,
              onPressed: onPrompt,
            ),
            _TopBarIconButton(
              icon: Icons.person_outline_rounded,
              tooltip: s.userProfile,
              onPressed: onUserProfile,
            ),
            _TopBarIconButton(
              icon: Icons.settings_outlined,
              tooltip: s.settings,
              onPressed: onSettings,
            ),
          ],
        ],
      ),
    );
  }
}

class _TopBarIconButton extends StatelessWidget {
  const _TopBarIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return HoverIconButton(
      icon: icon,
      onPressed: onPressed,
      tooltip: tooltip,
      iconSize: 17,
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill(this.text, {this.tooltip, this.color});

  final String text;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bgHover,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color ?? AppColors.text3,
          letterSpacing: 0.2,
        ),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: chip);
    }
    return chip;
  }
}
