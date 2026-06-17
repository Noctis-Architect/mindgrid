import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class UserProfileDialog extends StatefulWidget {
  const UserProfileDialog({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<UserProfileDialog> {
  late TextEditingController _controller;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: context.read<AppState>().userInfo);
    _controller.addListener(() {
      final changed = _controller.text != context.read<AppState>().userInfo;
      if (changed != _hasChanges) setState(() => _hasChanges = changed);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await context.read<AppState>().saveUserInfo(_controller.text);
    widget.onClose();
  }

  Future<void> _clear() async {
    final appState = context.read<AppState>();
    final s = context.s;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.clearProfile),
        content: Text(s.clearProfileConfirm),
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
    if (ok == true) {
      _controller.clear();
      await appState.saveUserInfo('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Dialog(
      backgroundColor: AppColors.bgPanel,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _dialogHeader(s),
            const Divider(height: 1, color: AppColors.border),
            _dialogBody(s),
            const Divider(height: 1, color: AppColors.border),
            _dialogActions(s),
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
            child: const Icon(Icons.person_rounded,
                color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            s.userProfile,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.text1,
            ),
          ),
          const Spacer(),
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

  Widget _dialogBody(dynamic s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentGlow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accent.withAlpha(50)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.accent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.profileDescription,
                    style: const TextStyle(color: AppColors.accent, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 8,
            decoration: InputDecoration(
              labelText: s.profileInfo,
              hintText: s.profileHint,
              alignLabelWithHint: true,
            ),
          ),
          if (_hasChanges) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.edit_rounded,
                    size: 13, color: AppColors.yellow),
                const SizedBox(width: 4),
                Text(
                  s.unsavedChanges,
                  style: const TextStyle(
                      color: AppColors.yellow, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _dialogActions(dynamic s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _clear,
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            label: Text(s.clear),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: const BorderSide(color: AppColors.red),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded, size: 16),
            label: Text(s.saveProfile),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
