import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_page.dart';
import '../core/hover_surface.dart';
import '../core/motion.dart';
import '../core/text_direction.dart';
import '../l10n/l10n.dart';
import '../models/chat_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'app_logo.dart';

class AppSidebar extends StatefulWidget {
  const AppSidebar({
    super.key,
    required this.page,
    required this.onNavigate,
    this.drawer = false,
    this.onClose,
    this.onCollapse,
  });

  final AppPage page;
  final ValueChanged<AppPage> onNavigate;

  /// Mobile drawer: includes branding and section navigation.
  final bool drawer;
  final VoidCallback? onClose;

  /// Desktop: collapses the docked conversation list.
  final VoidCallback? onCollapse;

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int _bucket(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 0;
    if (diff == 1) return 1;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = context.s;
    final q = _query.trim().toLowerCase();
    final chats = q.isEmpty
        ? state.chats
        : state.chats.where((c) => c.title.toLowerCase().contains(q)).toList();

    final rows = <Widget>[];
    int? lastBucket;
    for (final chat in chats) {
      final bucket = _bucket(chat.updatedAt);
      if (bucket != lastBucket) {
        lastBucket = bucket;
        rows.add(
          _SectionLabel(
            label: switch (bucket) {
              0 => s.today,
              1 => s.yesterday,
              _ => s.earlier,
            },
          ),
        );
      }
      rows.add(
        _ChatItem(
          key: ValueKey(chat.id),
          chat: chat,
          active: chat.id == state.currentChatId,
          deleteTooltip: s.delete,
          onTap: () {
            state.loadChat(chat.id);
            widget.onNavigate(AppPage.chat);
          },
          onDelete: () async {
            final ok = await showAppDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(s.deleteConversation),
                content: Text(s.deleteConversationConfirm),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(s.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style:
                        FilledButton.styleFrom(backgroundColor: AppColors.red),
                    child: Text(s.delete),
                  ),
                ],
              ),
            );
            if (ok == true) await state.deleteChat(chat.id);
          },
        ),
      );
    }

    void nav(AppPage p) => widget.onNavigate(p);

    return Container(
      color: AppColors.bgSidebar,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 16, 8, 10),
            child: Row(
              children: [
                if (widget.drawer) ...[
                  const AppLogo(size: 28, borderRadius: 9),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    widget.drawer ? s.appName : s.conversations,
                    style: TextStyle(
                      color: AppColors.text1,
                      fontSize: widget.drawer ? 15 : 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (widget.drawer)
                  HoverIconButton(
                    icon: Icons.edit_square,
                    tooltip: s.newChat,
                    iconSize: 17,
                    onPressed: () {
                      state.newChat();
                      nav(AppPage.chat);
                    },
                  ),
                if (widget.onCollapse != null)
                  HoverIconButton(
                    icon: Icons.view_sidebar_outlined,
                    tooltip: s.toggleSidebar,
                    iconSize: 17,
                    onPressed: widget.onCollapse,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(fontSize: 13, color: AppColors.text1),
                decoration: InputDecoration(
                  hintText: s.searchChats,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  fillColor: AppColors.bgInput,
                  prefixIcon: const Icon(Icons.search_rounded, size: 16),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  suffixIcon: _query.isEmpty
                      ? null
                      : GestureDetector(
                          onTap: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                          child: const Icon(Icons.close_rounded, size: 14),
                        ),
                ),
              ),
            ),
          ),
          Expanded(
            child: FadeThrough(
              child: chats.isEmpty
                  ? _EmptyChats(
                      key: const ValueKey('empty'),
                      message: q.isEmpty ? s.noConversationsYet : s.noResults,
                    )
                  : ListView(
                      key: const ValueKey('list'),
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      children: rows,
                    ),
            ),
          ),
          if (widget.drawer)
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  HoverListItem(
                    icon: Icons.view_in_ar_outlined,
                    label: s.ollamaManager,
                    active: widget.page == AppPage.models,
                    onTap: () => nav(AppPage.models),
                    trailing: _HubBadge(state: state),
                  ),
                  HoverListItem(
                    icon: Icons.graphic_eq_rounded,
                    label: s.speechTitle,
                    active: widget.page == AppPage.speech,
                    onTap: () => nav(AppPage.speech),
                  ),
                  HoverListItem(
                    icon: Icons.auto_awesome_outlined,
                    label: s.imageGeneration,
                    active: widget.page == AppPage.images,
                    onTap: () => nav(AppPage.images),
                  ),
                  HoverListItem(
                    icon: Icons.tune_rounded,
                    label: s.promptEngineering,
                    active: widget.page == AppPage.prompts,
                    onTap: () => nav(AppPage.prompts),
                  ),
                  HoverListItem(
                    icon: Icons.person_outline_rounded,
                    label: s.userProfile,
                    active: widget.page == AppPage.profile,
                    onTap: () => nav(AppPage.profile),
                  ),
                  HoverListItem(
                    icon: Icons.inventory_2_outlined,
                    label: s.backupExport,
                    active: widget.page == AppPage.backup,
                    onTap: () => nav(AppPage.backup),
                  ),
                  HoverListItem(
                    icon: Icons.settings_outlined,
                    label: s.settings,
                    active: widget.page == AppPage.settings,
                    onTap: () => nav(AppPage.settings),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Live count of running model downloads / imports.
class _HubBadge extends StatelessWidget {
  const _HubBadge({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state.hub,
      builder: (context, _) {
        final n = state.hub.pendingCount;
        return AnimatedSwitcher(
          duration: AppMotion.base,
          transitionBuilder: (child, a) =>
              ScaleTransition(scale: a, child: child),
          child: n == 0
              ? const SizedBox.shrink()
              : Container(
                  key: ValueKey(n),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$n',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 12, 10, 6),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.text4,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.forum_outlined, size: 26, color: AppColors.text4),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(color: AppColors.text4, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _ChatItem extends StatelessWidget {
  const _ChatItem({
    super.key,
    required this.chat,
    required this.active,
    required this.deleteTooltip,
    required this.onTap,
    required this.onDelete,
  });

  final Chat chat;
  final bool active;
  final String deleteTooltip;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return HoverSurface(
      onTap: onTap,
      builder: (context, hovered) {
        final highlight = hovered || active;
        return AnimatedContainer(
          duration: AppHover.duration,
          curve: AppHover.curve,
          margin: const EdgeInsets.only(bottom: 1),
          height: 38,
          decoration: BoxDecoration(
            color: active
                ? AppColors.bgActive
                : hovered
                    ? AppColors.bgHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: AppMotion.base,
                curve: AppMotion.emphasized,
                width: 3,
                height: active ? 16 : 0,
                margin: const EdgeInsetsDirectional.only(start: 4, end: 7),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Text(
                  chat.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: detectTextDirection(chat.title),
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    color: highlight ? AppColors.text1 : AppColors.text2,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
              AnimatedOpacity(
                duration: AppHover.duration,
                opacity: hovered || active ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !(hovered || active),
                  child: HoverIconButton(
                    icon: Icons.delete_outline_rounded,
                    onPressed: onDelete,
                    tooltip: deleteTooltip,
                    iconSize: 15,
                    padding: const EdgeInsets.all(6),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        );
      },
    );
  }
}
