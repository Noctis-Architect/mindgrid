import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/hover_surface.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

class CodeBlockWidget extends StatefulWidget {
  const CodeBlockWidget({
    super.key,
    required this.code,
    this.language,
  });

  final String code;
  final String? language;

  @override
  State<CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<CodeBlockWidget> {
  bool _collapsed = false;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    final lines = widget.code.split('\n').length;
    _collapsed = lines > 15;
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  static Color _langColor(String lang) {
    return switch (lang.toLowerCase()) {
      'python' || 'py' => const Color(0xFF3B82F6),
      'javascript' || 'js' || 'jsx' => const Color(0xFFF59E0B),
      'typescript' || 'ts' || 'tsx' => const Color(0xFF60A5FA),
      'dart' => const Color(0xFF4ADE80),
      'rust' || 'rs' => const Color(0xFFF97316),
      'go' => const Color(0xFF2DD4BF),
      'bash' || 'sh' || 'shell' => const Color(0xFFA78BFA),
      'json' => const Color(0xFFFBBF24),
      'html' => const Color(0xFFF87171),
      'css' || 'scss' => const Color(0xFF818CF8),
      'sql' => const Color(0xFF34D399),
      _ => AppColors.text4,
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final lines = widget.code.split('\n').length;
    final isLong = lines > 15;
    final label =
        widget.language?.isNotEmpty == true ? widget.language! : 'code';
    final langColor = _langColor(label);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgCode,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: langColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                        color: langColor.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: langColor,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  s.lineCount(lines),
                  style: const TextStyle(
                      fontSize: 10.5, color: AppColors.text4),
                ),
                const Spacer(),
                if (isLong)
                  _HeaderBtn(
                    label: _collapsed ? s.expand : s.collapse,
                    icon: _collapsed
                        ? Icons.unfold_more_rounded
                        : Icons.unfold_less_rounded,
                    onTap: () => setState(() => _collapsed = !_collapsed),
                  ),
                const SizedBox(width: 4),
                _HeaderBtn(
                  label: _copied ? s.copied : s.copy,
                  icon: _copied
                      ? Icons.check_rounded
                      : Icons.copy_outlined,
                  onTap: _copy,
                  active: _copied,
                ),
              ],
            ),
          ),
          // Code body
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.all(14),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  widget.code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: AppColors.text1,
                    height: 1.55,
                  ),
                ),
              ),
            ),
            crossFadeState: _collapsed
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  const _HeaderBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return HoverSurface(
      onTap: onTap,
      builder: (context, hovered) {
        final highlight = active || hovered;
        return HoverBox(
          hovered: hovered,
          active: active,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          borderRadius: BorderRadius.circular(6),
          activeColor: AppColors.green.withValues(alpha: 0.12),
          showBorder: highlight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 12,
                color: active
                    ? AppColors.green
                    : (hovered ? AppColors.text2 : AppColors.text3),
              ),
              const SizedBox(width: 5),
              AnimatedDefaultTextStyle(
                duration: AppHover.duration,
                curve: AppHover.curve,
                style: TextStyle(
                  fontSize: 11,
                  color: active
                      ? AppColors.green
                      : (hovered ? AppColors.text2 : AppColors.text3),
                ),
                child: Text(label),
              ),
            ],
          ),
        );
      },
    );
  }
}
