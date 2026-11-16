import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/hover_surface.dart';
import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Compact model picker shown in the top bar.
class ModelSelector extends StatelessWidget {
  const ModelSelector({super.key, this.onModelHub});

  final VoidCallback? onModelHub;

  static const _refresh = '\u0000refresh';
  static const _hub = '\u0000hub';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = context.s;

    return PopupMenuButton<String>(
      tooltip: s.selectModel,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 380),
      onSelected: (value) {
        if (value == _refresh) {
          state.fetchModels(scanNetwork: true);
        } else if (value == _hub) {
          onModelHub?.call();
        } else {
          state.selectModel(value);
        }
      },
      itemBuilder: (context) => [
        if (state.models.isEmpty)
          PopupMenuItem(
            enabled: false,
            height: 40,
            child: Text(
              s.noModelsFound,
              style: const TextStyle(color: AppColors.text4, fontSize: 13),
            ),
          ),
        for (final m in state.models)
          PopupMenuItem(
            value: m.name,
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: m.name == state.selectedModel
                          ? AppColors.text1
                          : AppColors.text2,
                      fontWeight: m.name == state.selectedModel
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (m.name == state.selectedModel)
                  const Icon(Icons.check_rounded,
                      size: 16, color: AppColors.accent),
              ],
            ),
          ),
        const PopupMenuDivider(height: 8),
        PopupMenuItem(
          value: _refresh,
          height: 40,
          child: _MenuAction(Icons.refresh_rounded, s.refreshModels),
        ),
        if (state.isOllama && onModelHub != null)
          PopupMenuItem(
            value: _hub,
            height: 40,
            child: _MenuAction(Icons.view_in_ar_outlined, s.ollamaManager),
          ),
      ],
      child: HoverSurface(
        builder: (context, hovered) => AnimatedContainer(
          duration: AppHover.duration,
          curve: AppHover.curve,
          padding: const EdgeInsetsDirectional.fromSTEB(10, 7, 8, 7),
          decoration: BoxDecoration(
            color: hovered ? AppColors.bgHover : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.isDiscovering)
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 1.6),
                )
              else
                AnimatedContainer(
                  duration: AppMotion.base,
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: state.selectedModel.isEmpty
                        ? AppColors.text4
                        : AppColors.green,
                  ),
                ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  state.selectedModel.isEmpty
                      ? s.noModelSelected
                      : state.selectedModel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: state.selectedModel.isEmpty
                        ? AppColors.text3
                        : AppColors.text1,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: AppColors.text3),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuAction extends StatelessWidget {
  const _MenuAction(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.text3),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppColors.text2)),
      ],
    );
  }
}
