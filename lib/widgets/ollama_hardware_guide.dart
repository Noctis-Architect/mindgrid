import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// Hardware guide for choosing Ollama models by RAM/VRAM.
class OllamaHardwareGuide extends StatelessWidget {
  const OllamaHardwareGuide({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoCard(
          icon: Icons.memory,
          title: s.hwHowToChoose,
          body: s.hwHowToChooseText,
        ),
        const SizedBox(height: 12),
        _infoCard(
          icon: Icons.speed,
          title: s.hwSpeed,
          body: s.hwSpeedText,
        ),
        const SizedBox(height: 12),
        _infoCard(
          icon: Icons.tune,
          title: s.hwQuantization,
          body: s.hwQuantizationText,
        ),
        const SizedBox(height: 20),
        Text(
          s.hwTable,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        ...s.hwTiers.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _tierCard(s, t),
            )),
        const SizedBox(height: 12),
        _infoCard(
          icon: Icons.lightbulb_outline,
          title: s.hwPracticalTips,
          body: s.hwPracticalTipsBody,
        ),
      ],
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppColors.text3,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tierCard(
    dynamic s,
    ({String ram, String vram, String models, String speed, String note}) tier,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${tier.ram} · ${tier.vram}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 8),
          _row(s.hwRecommendedModel, tier.models),
          _row(s.hwVramApprox, tier.vram),
          _row(s.hwApproxSpeed, tier.speed),
          const SizedBox(height: 4),
          Text(
            tier.note,
            style: const TextStyle(color: AppColors.text4, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.text4, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
