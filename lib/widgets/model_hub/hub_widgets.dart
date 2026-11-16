import 'package:flutter/material.dart';

import '../../core/hover_surface.dart';
import '../../core/motion.dart';
import '../../l10n/app_strings.dart';
import '../../models/ollama_models.dart';
import '../../services/model_hub_controller.dart';
import '../../theme/app_theme.dart';

class HubCard extends StatelessWidget {
  const HubCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.base,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(AppRadius.md + 2),
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      child: child,
    );
  }
}

class HubTag extends StatelessWidget {
  const HubTag(this.label, {super.key, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.text3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: c),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: c,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class HubEmpty extends StatelessWidget {
  const HubEmpty({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeSlideIn(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.bgHover,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 24, color: AppColors.text3),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.text3,
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HubSectionTitle extends StatelessWidget {
  const HubSectionTitle(this.label, {super.key, this.trailing});
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.text3,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

String hubStageLabel(HubTask t, AppStrings s) {
  switch (t.stage) {
    case HubTaskStage.queued:
      return s.downloadQueued;
    case HubTaskStage.paused:
      return s.downloadPaused;
    case HubTaskStage.hashing:
      return s.stageHashing;
    case HubTaskStage.uploading:
      return s.stageUploading;
    case HubTaskStage.creating:
      return s.stageCreating;
    case HubTaskStage.completed:
      return t.kind == HubTaskKind.whisperModel
          ? s.downloadComplete
          : s.installSuccess;
    case HubTaskStage.failed:
      return t.error ?? s.genericError;
    case HubTaskStage.downloading:
      final st = t.status?.toLowerCase() ?? '';
      if (st.contains('manifest')) return s.pullingManifest;
      if (st.contains('verifying')) return s.verifyingChecksum;
      if (st.contains('reconnect')) return s.reconnecting;
      if (t.kind == HubTaskKind.whisperModel) return s.downloading;
      return s.downloadingLayers;
  }
}

/// One row in the downloads list.
class HubTaskTile extends StatelessWidget {
  const HubTaskTile({
    super.key,
    required this.task,
    required this.strings,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onRetry,
  });

  final HubTask task;
  final AppStrings strings;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final t = task;
    final failed = t.stage == HubTaskStage.failed;
    final done = t.stage == HubTaskStage.completed;
    final paused = t.stage == HubTaskStage.paused;
    final queued = t.stage == HubTaskStage.queued;

    final (kindIcon, kindLabel) = switch (t.kind) {
      HubTaskKind.pull => (Icons.cloud_download_outlined, 'Ollama'),
      HubTaskKind.huggingFace => (Icons.hub_outlined, 'Hugging Face'),
      HubTaskKind.localFile => (Icons.insert_drive_file_outlined, 'GGUF'),
      HubTaskKind.whisperModel => (Icons.graphic_eq_rounded, 'Whisper'),
    };
    final color = failed
        ? AppColors.red
        : done
            ? AppColors.green
            : AppColors.accent;
    final pct = t.fraction == null ? null : (t.fraction! * 100).floor();
    const mono = TextStyle(
      color: AppColors.text3,
      fontSize: 11,
      fontFeatures: [FontFeature.tabularFigures()],
    );

    return HubCard(
      borderColor: failed
          ? AppColors.red.withValues(alpha: 0.35)
          : t.isActive
              ? AppColors.accent.withValues(alpha: 0.35)
              : null,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        t.model,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: AppColors.text1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        HubTag(kindLabel, icon: kindIcon),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            hubStageLabel(t, s),
                            maxLines: failed ? 3 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: failed ? AppColors.red : AppColors.text3,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (pct != null && !done && !failed && !queued)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '$pct%',
                    style: TextStyle(
                      color: paused ? AppColors.text3 : AppColors.text1,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              if (done)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.check_circle_rounded,
                      size: 18, color: AppColors.green),
                ),
              if (t.canPause)
                HoverIconButton(
                  icon: Icons.pause_rounded,
                  tooltip: s.pauseDownload,
                  onPressed: onPause,
                ),
              if (paused)
                HoverIconButton(
                  icon: Icons.play_arrow_rounded,
                  tooltip: s.resumeDownload,
                  onPressed: onResume,
                ),
              if (failed)
                HoverIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: s.retry,
                  onPressed: onRetry,
                ),
              HoverIconButton(
                icon: Icons.close_rounded,
                tooltip: done || failed ? s.close : s.cancelDownload,
                onPressed: onCancel,
              ),
            ],
          ),
          if (!done && !failed && !queued) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: SmoothProgressBar(
                value: t.stage == HubTaskStage.creating ? null : t.fraction,
                color: color,
                paused: paused,
              ),
            ),
            const SizedBox(height: 7),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  if (t.total > 0)
                    Text(
                      '${formatBytes(t.received)} / ${formatBytes(t.total)}',
                      style: mono,
                    ),
                  const Spacer(),
                  if (t.speed > 0) Text(formatSpeed(t.speed), style: mono),
                  if (t.etaSeconds != null && t.speed > 0) ...[
                    const Text('  ·  ', style: mono),
                    Text(formatEta(t.etaSeconds!, s), style: mono),
                  ],
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
