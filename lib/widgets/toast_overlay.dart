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
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                28 + MediaQuery.paddingOf(context).bottom,
              ),
              child: AnimatedSwitcher(
                duration: AppMotion.base,
                switchInCurve: AppMotion.emphasized,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.6),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: toast == null
                    ? const SizedBox.shrink()
                    : _ToastBanner(key: ValueKey(toast), toast: toast),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ToastBanner extends StatelessWidget {
  const _ToastBanner({super.key, required this.toast});

  final ToastMessage toast;

  @override
  Widget build(BuildContext context) {
    final (iconColor, icon) = switch (toast.type) {
      ToastType.ok => (AppColors.green, Icons.check_circle_rounded),
      ToastType.err => (AppColors.red, Icons.error_rounded),
      ToastType.info => (AppColors.text2, Icons.info_rounded),
    };

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderMd),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                toast.text,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textDirection: detectTextDirection(toast.text),
                style: const TextStyle(
                  color: AppColors.text1,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
