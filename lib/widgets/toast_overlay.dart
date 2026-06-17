import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/text_direction.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class ToastOverlay extends StatelessWidget {
  const ToastOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<AppState, ToastMessage?>(
      selector: (_, state) => state.toast,
      builder: (context, toast, _) {
        return IgnorePointer(
          ignoring: toast == null,
          child: AnimatedOpacity(
            opacity: toast == null ? 0 : 1,
            duration: const Duration(milliseconds: 150),
            child: toast == null
                ? const SizedBox.shrink()
                : Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: _ToastBanner(toast: toast),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _ToastBanner extends StatelessWidget {
  const _ToastBanner({required this.toast});

  final ToastMessage toast;

  @override
  Widget build(BuildContext context) {
    final (iconColor, icon) = switch (toast.type) {
      ToastType.ok => (AppColors.green, Icons.check_circle_outline_rounded),
      ToastType.err => (AppColors.red, Icons.error_outline_rounded),
      ToastType.info => (AppColors.text3, Icons.info_outline_rounded),
    };

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgPanel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (toast.type == ToastType.info
                    ? AppColors.borderMd
                    : iconColor)
                .withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                toast.text,
                textDirection: detectTextDirection(toast.text),
                style: const TextStyle(
                  color: AppColors.text1,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
