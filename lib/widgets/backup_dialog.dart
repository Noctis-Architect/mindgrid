import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class BackupDialog extends StatefulWidget {
  const BackupDialog({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends State<BackupDialog> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = context.s;

    return Dialog(
      backgroundColor: AppColors.bgPanel,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _dialogHeader(s),
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatsRow(chatCount: state.chats.length, label: s.savedConversations(state.chats.length)),
                  const SizedBox(height: 20),
                  _SectionHeading(s.exportSection),
                  const SizedBox(height: 10),
                  _ActionCard(
                    icon: Icons.upload_file_rounded,
                    iconColor: AppColors.accent,
                    title: s.exportAllChats,
                    subtitle: s.exportAllChatsSubtitle,
                    enabled: !_busy && state.chats.isNotEmpty,
                    onTap: () => _run(() => state.exportAllChats()),
                  ),
                  const SizedBox(height: 8),
                  _ActionCard(
                    icon: Icons.chat_bubble_outline_rounded,
                    iconColor: AppColors.teal,
                    title: s.exportCurrentChat,
                    subtitle: s.exportCurrentChatSubtitle,
                    enabled: !_busy && state.currentChatId != null,
                    onTap: () => _run(() => state.exportCurrentChat()),
                  ),
                  const SizedBox(height: 20),
                  _SectionHeading(s.importSection),
                  const SizedBox(height: 10),
                  _ActionCard(
                    icon: Icons.merge_rounded,
                    iconColor: AppColors.purple,
                    title: s.importMerge,
                    subtitle: s.importMergeSubtitle,
                    enabled: !_busy,
                    onTap: () => _run(() => state.importChats(merge: true)),
                  ),
                  const SizedBox(height: 8),
                  _ActionCard(
                    icon: Icons.swap_horiz_rounded,
                    iconColor: AppColors.red,
                    title: s.importReplace,
                    subtitle: s.importReplaceSubtitle,
                    enabled: !_busy,
                    destructive: true,
                    onTap: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(s.replaceAllChats),
                          content: Text(s.replaceAllChatsConfirm),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(s.cancel),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.red),
                              child: Text(s.replace),
                            ),
                          ],
                        ),
                      );
                      if (ok == true && mounted) {
                        await _run(() => state.importChats(merge: false));
                      }
                    },
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 20),
                    _BusyIndicator(label: s.processing),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogHeader(dynamic s) {
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
            child: const Icon(Icons.backup_rounded,
                color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            s.backupRestore,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.text1,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _busy ? null : widget.onClose,
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
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.chatCount, required this.label});

  final int chatCount;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.chat_bubble_outline_rounded,
              size: 16, color: AppColors.text3),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: AppColors.text2, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.text3,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _BusyIndicator extends StatelessWidget {
  const _BusyIndicator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bgHover,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: AppColors.text3)),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = enabled ? iconColor : AppColors.text4;
    final effectiveTitleColor = enabled ? AppColors.text1 : AppColors.text4;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: enabled
                ? (destructive
                    ? AppColors.red.withAlpha(10)
                    : AppColors.bgInput)
                : AppColors.bgInput.withAlpha(128),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: destructive && enabled
                  ? AppColors.red.withAlpha(60)
                  : AppColors.borderMd,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: effectiveIconColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: effectiveIconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: effectiveTitleColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.text3,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: enabled ? AppColors.text3 : AppColors.text4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
