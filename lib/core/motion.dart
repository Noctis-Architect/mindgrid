import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Fades and slides its child in once, optionally after a delay.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.slow,
    this.offset = const Offset(0, 12),
    this.enabled = true,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Starting offset in logical pixels.
  final Offset offset;
  final bool enabled;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _a =
      CurvedAnimation(parent: _c, curve: AppMotion.emphasized);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) {
      _c.value = 1;
    } else if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      child: widget.child,
      builder: (context, child) {
        final t = _a.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: widget.offset * (1 - t),
            child: child,
          ),
        );
      },
    );
  }
}

/// Scales down slightly while pressed — tactile feedback for custom buttons.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: active ? (_) => _set(true) : null,
      onTapUp: active ? (_) => _set(false) : null,
      onTapCancel: active ? () => _set(false) : null,
      onTap: active ? widget.onTap : null,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        child: widget.child,
      ),
    );
  }
}

/// Dialog route with a soft scale + fade + rise transition.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, _, _) => SafeArea(child: Builder(builder: builder)),
    transitionBuilder: (ctx, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.emphasized,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: AnimatedBuilder(
          animation: curved,
          child: child,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, 14 * (1 - curved.value)),
            child: Transform.scale(
              scale: 0.965 + 0.035 * curved.value,
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

/// Cross-fades between children with a small vertical shift.
class FadeThrough extends StatelessWidget {
  const FadeThrough({super.key, required this.child, this.duration});

  final Widget child;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration ?? AppMotion.base,
      switchInCurve: AppMotion.emphasized,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        fit: StackFit.passthrough,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.012),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Smooth determinate / indeterminate progress bar.
class SmoothProgressBar extends StatefulWidget {
  const SmoothProgressBar({
    super.key,
    this.value,
    this.height = 6,
    this.color = AppColors.accent,
    this.paused = false,
  });

  /// Null renders an indeterminate shimmer.
  final double? value;
  final double height;
  final Color color;
  final bool paused;

  @override
  State<SmoothProgressBar> createState() => _SmoothProgressBarState();
}

class _SmoothProgressBarState extends State<SmoothProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant SmoothProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final run = !widget.paused;
    if (run && !_shimmer.isAnimating) {
      _shimmer.repeat();
    } else if (!run && _shimmer.isAnimating) {
      _shimmer.stop();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.paused ? AppColors.text4 : widget.color;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.height),
      child: SizedBox(
        height: widget.height,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              return Stack(
                children: [
                  const Positioned.fill(
                    child: ColoredBox(color: AppColors.bgActive),
                  ),
                  if (widget.value != null)
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: widget.value!.clamp(0.0, 1.0)),
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOut,
                      builder: (context, v, _) => Container(
                        width: w * v,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(widget.height),
                        ),
                      ),
                    ),
                  if (!widget.paused)
                    AnimatedBuilder(
                      animation: _shimmer,
                      builder: (context, _) {
                        final band = w * 0.3;
                        final limit = widget.value == null
                            ? w
                            : w * widget.value!.clamp(0.0, 1.0);
                        final left = widget.value == null
                            ? (w + band) * _shimmer.value - band
                            : limit * _shimmer.value - band;
                        return Positioned(
                          left: left,
                          top: 0,
                          bottom: 0,
                          width: band,
                          child: ClipRect(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0),
                                    (widget.value == null
                                            ? color
                                            : Colors.white)
                                        .withValues(
                                      alpha: widget.value == null ? 0.9 : 0.28,
                                    ),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
