import 'package:flutter/material.dart';

import '../core/window_chrome.dart';
import '../theme/app_theme.dart';
import 'app_logo.dart';

/// App-drawn title bar: drag to move, double-click to maximize, and window
/// buttons that match the rest of the interface.
class WindowTitleBar extends StatefulWidget {
  const WindowTitleBar({super.key});

  static const height = 38.0;

  @override
  State<WindowTitleBar> createState() => _WindowTitleBarState();
}

class _WindowTitleBarState extends State<WindowTitleBar>
    with WidgetsBindingObserver {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The window size changes whenever it is maximized, restored or snapped.
  @override
  void didChangeMetrics() => _sync();

  Future<void> _sync() async {
    final value = await WindowChrome.isMaximized();
    if (mounted && value != _maximized) setState(() => _maximized = value);
  }

  Future<void> _toggleMaximize() async {
    await WindowChrome.toggleMaximize();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _sync();
  }

  @override
  Widget build(BuildContext context) {
    // Window buttons keep their physical side regardless of text direction.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: AppColors.bgSidebar,
        child: SizedBox(
          height: WindowTitleBar.height,
          child: Stack(
            children: [
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (_) => WindowChrome.startDrag(),
                      onDoubleTap: _toggleMaximize,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 14),
                        child: Row(
                          children: [
                            AppLogo(size: 18, borderRadius: 5),
                            SizedBox(width: 9),
                            Text(
                              'MindGrid',
                              style: TextStyle(
                                color: AppColors.text2,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _WindowButton(
                    icon: Icons.remove_rounded,
                    onTap: WindowChrome.minimize,
                  ),
                  _WindowButton(
                    icon: _maximized
                        ? Icons.filter_none_rounded
                        : Icons.crop_square_rounded,
                    iconSize: _maximized ? 12 : 14,
                    onTap: _toggleMaximize,
                  ),
                  _WindowButton(
                    icon: Icons.close_rounded,
                    danger: true,
                    onTap: WindowChrome.close,
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              if (WindowChrome.needsTopResizeHandle && !_maximized)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 4,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeUp,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (_) => WindowChrome.startResize('top'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.icon,
    required this.onTap,
    this.danger = false,
    this.iconSize = 15,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool danger;
  final double iconSize;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = !_hovered
        ? Colors.transparent
        : widget.danger
            ? AppColors.red
            : AppColors.bgActive;
    final fg = !_hovered
        ? AppColors.text3
        : widget.danger
            ? Colors.white
            : AppColors.text1;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.curve,
            width: 34,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, size: widget.iconSize, color: fg),
          ),
        ),
      ),
    );
  }
}
