import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared hover timing and decoration helpers.
class AppHover {
  static const duration = Duration(milliseconds: 200);
  static const curve = Curves.easeOutCubic;
  static const subtleScale = 1.006;

  static Color bg(bool hovered, {Color? base, Color? hover, bool active = false}) {
    if (active) return AppColors.bgActive;
    if (hovered) return hover ?? AppColors.bgHover;
    return base ?? Colors.transparent;
  }

  static Color border(bool hovered, {bool active = false, bool accent = false}) {
    if (active) return AppColors.accent.withValues(alpha: 0.35);
    if (hovered && accent) return AppColors.accent.withValues(alpha: 0.3);
    if (hovered) return AppColors.borderFocus;
    return AppColors.border;
  }

  static List<BoxShadow>? shadow(bool hovered, {bool elevated = false}) {
    if (!hovered || !elevated) return null;
    return [
      BoxShadow(
        color: AppColors.accentGlow,
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.25),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }
}

/// Tracks hover state and forwards it to [builder].
class HoverSurface extends StatefulWidget {
  const HoverSurface({
    super.key,
    required this.builder,
    this.onTap,
    this.enabled = true,
    this.cursor = SystemMouseCursors.click,
  });

  final Widget Function(BuildContext context, bool hovered) builder;
  final VoidCallback? onTap;
  final bool enabled;
  final MouseCursor cursor;

  @override
  State<HoverSurface> createState() => _HoverSurfaceState();
}

class _HoverSurfaceState extends State<HoverSurface> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.enabled ? widget.cursor : SystemMouseCursors.basic,
      onEnter: widget.enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: widget.enabled ? (_) => setState(() => _hovered = false) : null,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        behavior: HitTestBehavior.opaque,
        child: widget.builder(context, _hovered),
      ),
    );
  }
}

/// Animated container with polished hover background, border, and optional lift.
class HoverBox extends StatelessWidget {
  const HoverBox({
    super.key,
    required this.hovered,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.baseColor = Colors.transparent,
    this.hoverColor,
    this.activeColor,
    this.active = false,
    this.baseBorder = AppColors.border,
    this.hoverBorder,
    this.showBorder = false,
    this.accentBorder = false,
    this.elevated = false,
    this.scaleOnHover = false,
    this.width,
    this.height,
  });

  final bool hovered;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final Color baseColor;
  final Color? hoverColor;
  final Color? activeColor;
  final bool active;
  final Color baseBorder;
  final Color? hoverBorder;
  final bool showBorder;
  final bool accentBorder;
  final bool elevated;
  final bool scaleOnHover;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final resolvedHoverColor = hoverColor ?? AppColors.bgHover;
    final bg = active
        ? (activeColor ?? AppColors.bgActive)
        : hovered
            ? resolvedHoverColor
            : baseColor;

    final borderColor = hoverBorder ??
        AppHover.border(hovered, active: active, accent: accentBorder);

    Widget box = AnimatedContainer(
      duration: AppHover.duration,
      curve: AppHover.curve,
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: borderRadius,
        border: showBorder || hovered || active
            ? Border.all(color: borderColor)
            : null,
        boxShadow: AppHover.shadow(hovered, elevated: elevated),
      ),
      child: child,
    );

    if (scaleOnHover) {
      box = AnimatedScale(
        scale: hovered && !active ? AppHover.subtleScale : 1.0,
        duration: AppHover.duration,
        curve: AppHover.curve,
        child: box,
      );
    }

    return box;
  }
}

/// Icon button with smooth hover color, background, and optional tooltip.
class HoverIconButton extends StatelessWidget {
  const HoverIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.iconSize = 16,
    this.padding = const EdgeInsets.all(7),
    this.borderRadius = 8,
    this.active = false,
    this.danger = false,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool active;
  final bool danger;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final canInteract = enabled && onPressed != null;
    final radius = BorderRadius.circular(borderRadius);

    Widget button = HoverSurface(
      enabled: canInteract,
      onTap: onPressed,
      builder: (context, hovered) {
        final Color bg;
        final Color iconColor;
        final Color? borderColor;

        if (danger) {
          bg = hovered && canInteract
              ? AppColors.red.withValues(alpha: 0.14)
              : AppColors.bgCode;
          iconColor = canInteract ? AppColors.red : AppColors.text4;
          borderColor = hovered && canInteract
              ? AppColors.red.withValues(alpha: 0.35)
              : AppColors.borderMd;
        } else if (active) {
          bg = AppColors.accent.withValues(alpha: 0.15);
          iconColor = AppColors.accent;
          borderColor = AppColors.accent.withValues(alpha: 0.3);
        } else {
          bg = hovered ? AppColors.bgHover : Colors.transparent;
          iconColor = hovered ? AppColors.text1 : AppColors.text3;
          borderColor = hovered ? AppColors.borderFocus : null;
        }

        return AnimatedContainer(
          duration: AppHover.duration,
          curve: AppHover.curve,
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: borderColor != null ? Border.all(color: borderColor) : null,
          ),
          child: Icon(icon, size: iconSize, color: iconColor),
        );
      },
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}

/// List-row hover item for sidebar footer and similar surfaces.
class HoverListItem extends StatelessWidget {
  const HoverListItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return HoverSurface(
      onTap: onTap,
      builder: (context, hovered) {
        final highlight = hovered || active;
        return HoverBox(
          hovered: hovered,
          active: active,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          borderRadius: BorderRadius.circular(8),
          showBorder: highlight,
          accentBorder: active,
          child: Row(
            children: [
              AnimatedContainer(
                duration: AppHover.duration,
                curve: AppHover.curve,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: highlight
                      ? AppColors.accent.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  size: 15,
                  color: highlight ? AppColors.accent : AppColors.text3,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: AppHover.duration,
                  curve: AppHover.curve,
                  style: TextStyle(
                    color: highlight ? AppColors.text1 : AppColors.text2,
                    fontSize: 13,
                  ),
                  child: Text(label),
                ),
              ),
              ?trailing,
            ],
          ),
        );
      },
    );
  }
}
