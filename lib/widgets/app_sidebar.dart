import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/hover_surface.dart';
import '../core/text_direction.dart';
import '../l10n/l10n.dart';
import '../models/chat_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'model_selector.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    this.onClose,
    this.onPrompt,
    this.onSettings,
    this.onUserProfile,
    this.onOllamaManager,
    this.onBackup,
    this.onImageGen,
  });

  final VoidCallback? onClose;
  final VoidCallback? onPrompt;
  final VoidCallback? onSettings;
  final VoidCallback? onUserProfile;
  final VoidCallback? onOllamaManager;
  final VoidCallback? onBackup;
  final VoidCallback? onImageGen;

  String _fmtDate(BuildContext context, int ts) {
    final s = context.s;
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    final t = DateTime.now();
    if (d.year == t.year && d.month == t.month && d.day == t.day) {
      return s.today;
    }
    final y = DateTime(t.year, t.month, t.day - 1);
    if (d.year == y.year && d.month == y.month && d.day == y.day) {
      return s.yesterday;
    }
    return '${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = context.s;

    return Container(
      color: AppColors.bgSidebar,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: _NewChatButton(
                    label: s.newChat,
                    onPressed: () {
                      state.newChat();
                      onClose?.call();
                    },
                  ),
                ),
                if (onClose != null) ...[
                  const SizedBox(width: 6),
                  _SidebarIconButton(
                    icon: Icons.keyboard_tab,
                    onPressed: onClose!,
                    tooltip: s.close,
                  ),
                ],
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: ModelSelector(),
          ),
          const SizedBox(height: 12),
          _SectionLabel(label: s.conversations),
          const SizedBox(height: 4),
          Expanded(
            child: state.chats.isEmpty
                ? _EmptyChats(message: s.noConversationsYet)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: state.chats.length,
                    itemBuilder: (context, index) {
                      final chat = state.chats[index];
                      final active = chat.id == state.currentChatId;
                      return _ChatItem(
                        chat: chat,
                        active: active,
                        dateLabel: _fmtDate(context, chat.updatedAt),
                        deleteTooltip: s.delete,
                        onTap: () {
                          state.loadChat(chat.id);
                          onClose?.call();
                        },
                        onDelete: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => _DeleteDialog(
                              title: s.deleteConversation,
                              content: s.deleteConversationConfirm,
                              cancel: s.cancel,
                              deleteLabel: s.delete,
                            ),
                          );
                          if (ok == true) await state.deleteChat(chat.id);
                        },
                      );
                    },
                  ),
          ),
          _SidebarFooter(
            state: state,
            onBackup: () {
              onClose?.call();
              onBackup?.call();
            },
            onImageGen: () {
              onClose?.call();
              onImageGen?.call();
            },
            onOllamaManager: () {
              onClose?.call();
              onOllamaManager?.call();
            },
            onPrompt: onPrompt ?? () {},
            onUserProfile: () {
              onClose?.call();
              onUserProfile?.call();
            },
            onSettings: () {
              onClose?.call();
              onSettings?.call();
            },
          ),
        ],
      ),
    );
  }
}

class _NewChatButton extends StatelessWidget {
  const _NewChatButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return HoverSurface(
      onTap: onPressed,
      builder: (context, hovered) => HoverBox(
        hovered: hovered,
        borderRadius: BorderRadius.circular(10),
        baseColor: AppColors.bgCode,
        hoverColor: AppColors.bgHover,
        showBorder: true,
        accentBorder: hovered,
        scaleOnHover: true,
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add,
              size: 16,
              color: hovered ? AppColors.accent : AppColors.text2,
            ),
            const SizedBox(width: 8),
            AnimatedDefaultTextStyle(
              duration: AppHover.duration,
              curve: AppHover.curve,
              style: TextStyle(
                color: hovered ? AppColors.text1 : AppColors.text2,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarIconButton extends StatelessWidget {
  const _SidebarIconButton({
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
      iconSize: 16,
      padding: const EdgeInsets.all(8),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.text4,
            fontSize: 10,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.forum_outlined, size: 28, color: AppColors.text4),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(color: AppColors.text4, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ChatItem extends StatelessWidget {
  const _ChatItem({
    required this.chat,
    required this.active,
    required this.dateLabel,
    required this.deleteTooltip,
    required this.onTap,
    required this.onDelete,
  });

  final Chat chat;
  final bool active;
  final String dateLabel;
  final String deleteTooltip;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return HoverSurface(
      onTap: onTap,
      builder: (context, hovered) {
        final highlight = hovered || active;
        return HoverBox(
          hovered: hovered,
          active: active,
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          borderRadius: BorderRadius.circular(10),
          showBorder: highlight,
          accentBorder: active,
          hoverColor: AppColors.hoverTint,
          child: Row(
            children: [
              AnimatedContainer(
                duration: AppHover.duration,
                curve: AppHover.curve,
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.accent.withValues(alpha: 0.15)
                      : hovered
                          ? AppColors.bgHover
                          : AppColors.bgCode,
                  borderRadius: BorderRadius.circular(7),
                  border: hovered && !active
                      ? Border.all(color: AppColors.borderMd)
                      : null,
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 13,
                  color: highlight ? AppColors.accent : AppColors.text4,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: AppHover.duration,
                      curve: AppHover.curve,
                      style: TextStyle(
                        color: highlight ? AppColors.text1 : AppColors.text2,
                        fontSize: 13,
                        fontWeight:
                            active ? FontWeight.w500 : FontWeight.normal,
                      ),
                      child: Text(
                        chat.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: detectTextDirection(chat.title),
                        textAlign: TextAlign.start,
                      ),
                    ),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        color: AppColors.text4,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                duration: AppHover.duration,
                curve: AppHover.curve,
                opacity: highlight ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !highlight,
                  child: _SidebarIconButton(
                    icon: Icons.delete_outline_rounded,
                    onPressed: onDelete,
                    tooltip: deleteTooltip,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({
    required this.title,
    required this.content,
    required this.cancel,
    required this.deleteLabel,
  });

  final String title;
  final String content;
  final String cancel;
  final String deleteLabel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.red),
          child: Text(deleteLabel),
        ),
      ],
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({
    required this.state,
    required this.onBackup,
    required this.onImageGen,
    required this.onOllamaManager,
    required this.onPrompt,
    required this.onUserProfile,
    required this.onSettings,
  });

  final AppState state;
  final VoidCallback onBackup;
  final VoidCallback onImageGen;
  final VoidCallback onOllamaManager;
  final VoidCallback onPrompt;
  final VoidCallback onUserProfile;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          _FooterItem(
            icon: Icons.palette_outlined,
            label: s.imageGeneration,
            onTap: onImageGen,
          ),
          _FooterItem(
            icon: Icons.cloud_download_outlined,
            label: s.backupExport,
            onTap: onBackup,
          ),
          if (state.isOllama)
            _FooterItem(
              icon: Icons.memory_outlined,
              label: s.ollamaManager,
              onTap: onOllamaManager,
            ),
          _FooterItem(
            icon: Icons.tune_outlined,
            label: s.promptEngineering,
            onTap: onPrompt,
          ),
          _FooterItem(
            icon: Icons.person_outline_rounded,
            label: s.userProfile,
            onTap: onUserProfile,
          ),
          _FooterItem(
            icon: Icons.settings_outlined,
            label: s.settings,
            onTap: onSettings,
          ),
        ],
      ),
    );
  }
}

class _FooterItem extends StatelessWidget {
  const _FooterItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverListItem(
      icon: icon,
      label: label,
      onTap: onTap,
    );
  }
}
