import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/hover_surface.dart';
import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class ModelSelector extends StatelessWidget {
  const ModelSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = context.s;

    return Row(
      children: [
        Expanded(
          child: PopupMenuButton<String>(
            tooltip: s.selectModel,
            offset: const Offset(0, 44),
            color: AppColors.bgPanel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.borderMd),
            ),
            onSelected: state.selectModel,
            itemBuilder: (context) {
              if (state.models.isEmpty) {
                return [
                  PopupMenuItem(
                    enabled: false,
                    child: Text(
                      s.noModelsFound,
                      style: const TextStyle(
                          color: AppColors.text4, fontSize: 13),
                    ),
                  ),
                ];
              }
              return state.models.map((m) {
                final selected = m.name == state.selectedModel;
                return PopupMenuItem(
                  value: m.name,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          m.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: selected
                                ? AppColors.accent
                                : AppColors.text1,
                            fontWeight: selected
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (selected)
                        const Icon(Icons.check_rounded,
                            size: 14, color: AppColors.accent),
                    ],
                  ),
                );
              }).toList();
            },
            child: _ModelDisplay(state: state),
          ),
        ),
        const SizedBox(width: 4),
        _RefreshButton(state: state),
      ],
    );
  }
}

class _ModelDisplay extends StatelessWidget {
  const _ModelDisplay({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return HoverSurface(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => HoverBox(
        hovered: hovered,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        borderRadius: BorderRadius.circular(10),
        baseColor: AppColors.bgCode,
        showBorder: true,
        accentBorder: hovered,
        child: Row(
          children: [
            Icon(
              Icons.hub_outlined,
              size: 13,
              color: state.selectedModel.isNotEmpty
                  ? (hovered ? AppColors.accent : AppColors.accentDim)
                  : AppColors.text4,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.isDiscovering
                    ? s.search
                    : (state.selectedModel.isEmpty
                        ? s.noModelSelected
                        : state.selectedModel),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: hovered
                      ? AppColors.text1
                      : (state.selectedModel.isNotEmpty
                          ? AppColors.text2
                          : AppColors.text4),
                ),
              ),
            ),
            Icon(
              Icons.unfold_more_rounded,
              size: 14,
              color: hovered ? AppColors.text2 : AppColors.text4,
            ),
          ],
        ),
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.isDiscovering) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.bgCode,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: AppColors.accent,
          ),
        ),
      );
    }

    return HoverSurface(
      onTap: () => state.fetchModels(scanNetwork: true),
      builder: (context, hovered) => HoverBox(
        hovered: hovered,
        padding: const EdgeInsets.all(8),
        borderRadius: BorderRadius.circular(10),
        baseColor: AppColors.bgCode,
        showBorder: true,
        child: Icon(
          Icons.refresh_rounded,
          size: 15,
          color: hovered ? AppColors.accent : AppColors.text3,
        ),
      ),
    );
  }
}
