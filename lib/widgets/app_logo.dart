import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 60,
    this.borderRadius = 18,
    this.showBackground = true,
    this.padding = 8,
    this.streaming = false,
  });

  final double size;
  final double borderRadius;
  final bool showBackground;
  final double padding;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(
        showBackground ? borderRadius - 2 : borderRadius,
      ),
      child: Image.asset(
        'assets/images/app_logo.jpg',
        width: size - padding * 2,
        height: size - padding * 2,
        fit: BoxFit.cover,
      ),
    );

    if (!showBackground) {
      return SizedBox(
        width: size,
        height: size,
        child: Padding(padding: EdgeInsets.all(padding), child: image),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.bgHover,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: streaming
              ? AppColors.accent.withValues(alpha: 0.5)
              : AppColors.borderMd,
        ),
      ),
      child: Padding(padding: EdgeInsets.all(padding), child: image),
    );
  }
}
