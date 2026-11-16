import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 60,
    this.borderRadius = 18,
    this.showBackground = true,
    this.padding = 0,
    this.streaming = false,
  });

  final double size;
  final double borderRadius;
  final bool showBackground;
  final double padding;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final inner = size - padding * 2;
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(
        (borderRadius - padding).clamp(0, borderRadius),
      ),
      child: Image.asset(
        'assets/images/app_logo.jpg',
        width: inner,
        height: inner,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      ),
    );

    return AnimatedContainer(
      duration: AppMotion.slow,
      curve: AppMotion.curve,
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: showBackground ? AppColors.bgHover : Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: streaming
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.45),
                  blurRadius: 14,
                ),
              ]
            : const [],
      ),
      child: image,
    );
  }
}
