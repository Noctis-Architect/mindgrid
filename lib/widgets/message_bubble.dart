import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';

import '../core/hover_surface.dart';
import 'app_logo.dart';
import '../core/markdown_sanitize.dart';
import '../core/text_direction.dart';
import '../models/chat_models.dart';
import '../l10n/l10n.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'code_block_widget.dart';

class MessageBubble extends StatefulWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.streaming = false,
    this.stopped = false,
    this.alignFallback = '',
    required this.onRetry,
    required this.onCopy,
    required this.onEdit,
  });

  final ChatMessage message;
  final bool streaming;
  final bool stopped;
  final String alignFallback;
  final void Function(String? model) onRetry;
  final VoidCallback onCopy;
  final VoidCallback onEdit;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _thinkingExpanded = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;
    final isUser = msg.isUser;
    final state = context.watch<AppState>();
    final dir = alignDirectionFor(
      msg.content,
      fallback: widget.alignFallback,
      defaultDirection: localeTextDirection(state.locale),
    );
    final alignRight = dir == TextDirection.rtl;
    final mobile = MediaQuery.sizeOf(context).width < mobileBreakpoint;
    final screenW = MediaQuery.sizeOf(context).width;
    final horizontalPad = mobile ? 12.0 : 40.0;
    final avatarGutter = mobile ? 42.0 : (isUser ? 84.0 : 42.0);
    final maxBubbleW =
        (screenW - horizontalPad * 2 - avatarGutter).clamp(120.0, 860.0);
    final metaInset = mobile ? 0.0 : 46.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment:
              alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:
                  alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!alignRight) ...[
                  isUser ? _UserAvatar() : _AiAvatar(streaming: widget.streaming),
                  const SizedBox(width: 12),
                ],
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxBubbleW),
                    child: isUser
                        ? _UserBubble(msg: msg, dir: dir)
                        : _AiBubble(
                            msg: msg,
                            dir: dir,
                            streaming: widget.streaming,
                            stopped: widget.stopped,
                            thinkingExpanded: _thinkingExpanded,
                            onToggleThinking: () => setState(
                              () => _thinkingExpanded = !_thinkingExpanded,
                            ),
                            showThinking: state.settings.thinkEnabled,
                          ),
                  ),
                ),
                if (alignRight) ...[
                  const SizedBox(width: 12),
                  isUser ? _UserAvatar() : _AiAvatar(streaming: widget.streaming),
                ],
              ],
            ),
            const SizedBox(height: 6),
            AnimatedOpacity(
              opacity: _hovered || widget.streaming || mobile ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: alignRight ? 0 : metaInset,
                  end: alignRight ? metaInset : 0,
                ),
                child: _MessageMeta(
                  msg: msg,
                  isUser: isUser,
                  alignRight: alignRight,
                  mobile: mobile,
                  state: state,
                  onRetry: widget.onRetry,
                  onEdit: widget.onEdit,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.msg, required this.dir});
  final ChatMessage msg;
  final TextDirection dir;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgMsgUser,
        borderRadius: dir == TextDirection.rtl
            ? const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              )
            : const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
        border: Border.all(color: AppColors.borderMd),
      ),
      child: Column(
        crossAxisAlignment: dir == TextDirection.rtl
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (msg.images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: msg.images.map((img) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      Uint8List.fromList(base64Decode(img.base64)),
                      width: 180,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 180,
                        height: 100,
                        color: AppColors.bgHover,
                        alignment: Alignment.center,
                        child: Text(
                          img.name,
                          style: const TextStyle(
                            color: AppColors.text4,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          if (msg.files.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: msg.files
                    .map((f) => _FileChip(name: f.name))
                    .toList(),
              ),
            ),
          if (msg.content.isNotEmpty)
            Text(
              msg.content,
              textDirection: dir,
              textAlign: textAlignFor(msg.content),
              style: const TextStyle(
                color: AppColors.text1,
                fontSize: 14,
                height: 1.6,
              ),
            ),
        ],
      ),
    );
  }
}

class _AiBubble extends StatelessWidget {
  const _AiBubble({
    required this.msg,
    required this.dir,
    required this.streaming,
    required this.stopped,
    required this.thinkingExpanded,
    required this.onToggleThinking,
    required this.showThinking,
  });

  final ChatMessage msg;
  final TextDirection dir;
  final bool streaming;
  final bool stopped;
  final bool thinkingExpanded;
  final VoidCallback onToggleThinking;
  final bool showThinking;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: dir == TextDirection.rtl
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (!msg.isUser &&
            msg.thinking != null &&
            msg.thinking!.isNotEmpty &&
            showThinking)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ThinkingBlock(
              thinking: msg.thinking!,
              expanded: thinkingExpanded,
              hasContent: msg.content.isNotEmpty,
              onToggle: onToggleThinking,
            ),
          ),
        if (msg.content.isNotEmpty)
          _AiContent(msg: msg, dir: dir, streaming: streaming)
        else if (streaming)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: _ThinkingDots(),
          ),
        if (stopped && msg.content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  context.s.stopped,
                  style: const TextStyle(fontSize: 11, color: AppColors.text4),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AiContent extends StatelessWidget {
  const _AiContent({
    required this.msg,
    required this.dir,
    required this.streaming,
  });
  final ChatMessage msg;
  final TextDirection dir;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final display = msg.content + (streaming ? ' ▍' : '');
    final textStyle = const TextStyle(
      color: AppColors.text1,
      height: 1.7,
      fontSize: 14,
    );

    return Directionality(
      textDirection: dir,
      child: streaming
          ? SelectableText(display, style: textStyle)
          : MarkdownBody(
              data: sanitizeMarkdownForRender(display),
              selectable: true,
              builders: {'pre': _CodeBlockBuilder()},
              styleSheet: _aiMarkdownStyleSheet(dir, textStyle),
            ),
    );
  }

  MarkdownStyleSheet _aiMarkdownStyleSheet(TextDirection dir, TextStyle base) {
    return MarkdownStyleSheet(
      textAlign: dir == TextDirection.rtl
          ? WrapAlignment.end
          : WrapAlignment.start,
      p: base,
      code: const TextStyle(
        fontFamily: 'monospace',
        backgroundColor: AppColors.bgCode,
        fontSize: 12.5,
        color: AppColors.teal,
      ),
      codeblockDecoration: BoxDecoration(
        color: AppColors.bgCode,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      blockquote: const TextStyle(color: AppColors.text3, fontSize: 13),
      blockquoteDecoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(color: AppColors.accent, width: 3),
        ),
      ),
      h1: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.text1),
      h2: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.text1),
      h3: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.text1),
      strong: const TextStyle(
          fontWeight: FontWeight.w500, color: AppColors.text1),
      em: const TextStyle(color: AppColors.text2),
      a: const TextStyle(
          color: AppColors.accent,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.accent),
      listBullet: const TextStyle(color: AppColors.accent),
      tableHead: const TextStyle(
          fontWeight: FontWeight.w500, color: AppColors.text1),
      tableBody: const TextStyle(color: AppColors.text2),
      tableBorder: TableBorder.all(
        color: AppColors.borderMd,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _ThinkingBlock extends StatelessWidget {
  const _ThinkingBlock({
    required this.thinking,
    required this.expanded,
    required this.hasContent,
    required this.onToggle,
  });

  final String thinking;
  final bool expanded;
  final bool hasContent;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final collapsed = hasContent && !expanded;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCode,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: hasContent ? onToggle : null,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  const Icon(Icons.psychology_outlined,
                      size: 14, color: AppColors.purple),
                  const SizedBox(width: 7),
                  Text(
                    collapsed ? context.s.showThinking : context.s.hideThinking,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.text3),
                  ),
                  const Spacer(),
                  Icon(
                    collapsed ? Icons.expand_more : Icons.expand_less,
                    size: 14,
                    color: AppColors.text4,
                  ),
                ],
              ),
            ),
          ),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                thinking,
                textDirection: detectTextDirection(thinking),
                textAlign: textAlignFor(thinking),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.text3,
                  fontFamily: 'monospace',
                  height: 1.6,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageMeta extends StatelessWidget {
  const _MessageMeta({
    required this.msg,
    required this.isUser,
    required this.alignRight,
    required this.mobile,
    required this.state,
    required this.onRetry,
    required this.onEdit,
  });

  final ChatMessage msg;
  final bool isUser;
  final bool alignRight;
  final bool mobile;
  final AppState state;
  final void Function(String?) onRetry;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Wrap(
      spacing: mobile ? 4 : 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: alignRight ? WrapAlignment.end : WrapAlignment.start,
      children: [
        Text(
          _fmt(msg.createdAt) + (msg.model != null ? '  ·  ${msg.model}' : ''),
          style: const TextStyle(color: AppColors.text4, fontSize: 10.5),
        ),
        _ActionChip(
          icon: Icons.copy_outlined,
          label: s.copy,
          onTap: () {
            Clipboard.setData(ClipboardData(text: msg.content));
            state.showToast(s.copied, type: ToastType.ok);
          },
        ),
        if (!isUser) ...[
          _ActionChip(
            icon: Icons.refresh_rounded,
            label: s.retry,
            onTap: () => onRetry(null),
          ),
          if (state.models.length > 1)
            _ModelRetryButton(state: state, onRetry: onRetry),
          _ActionChip(
            icon: Icons.share_outlined,
            label: s.share,
            onTap: () {
              Clipboard.setData(
                ClipboardData(text: '**${s.appName}:**\n\n${msg.content}'),
              );
              state.showToast(s.copied, type: ToastType.ok);
            },
          ),
        ] else
          _ActionChip(
            icon: Icons.edit_outlined,
            label: s.edit,
            onTap: onEdit,
          ),
      ],
    );
  }

  String _fmt(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverSurface(
      onTap: onTap,
      builder: (context, hovered) => HoverBox(
        hovered: hovered,
        margin: const EdgeInsets.only(right: 2),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        borderRadius: BorderRadius.circular(6),
        showBorder: hovered,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 11,
              color: hovered ? AppColors.text2 : AppColors.text4,
            ),
            const SizedBox(width: 4),
            AnimatedDefaultTextStyle(
              duration: AppHover.duration,
              curve: AppHover.curve,
              style: TextStyle(
                fontSize: 11,
                color: hovered ? AppColors.text2 : AppColors.text4,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelRetryButton extends StatelessWidget {
  const _ModelRetryButton({required this.state, required this.onRetry});
  final AppState state;
  final void Function(String?) onRetry;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return PopupMenuButton<String>(
      tooltip: s.otherModel,
      color: AppColors.bgPanel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: onRetry,
      itemBuilder: (context) => state.models
          .map((m) => PopupMenuItem(value: m.name, child: Text(m.name)))
          .toList(),
      child: Container(
        margin: const EdgeInsets.only(right: 2),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hub_outlined, size: 11, color: AppColors.text4),
            const SizedBox(width: 4),
            Text(s.otherModel,
                style: const TextStyle(fontSize: 11, color: AppColors.text4)),
            const SizedBox(width: 2),
            const Icon(Icons.expand_more, size: 10, color: AppColors.text4),
          ],
        ),
      ),
    );
  }
}

class _AiAvatar extends StatelessWidget {
  const _AiAvatar({this.streaming = false});
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    return AppLogo(
      size: 30,
      borderRadius: 9,
      padding: 4,
      streaming: streaming,
    );
  }
}

class _UserAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: AppColors.bgMsgUser,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.borderMd),
      ),
      child: Center(
        child: Text(
          context.s.me,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.text2,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _FileChip extends StatelessWidget {
  const _FileChip({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgCode,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file_outlined,
              size: 11, color: AppColors.text4),
          const SizedBox(width: 5),
          Text(
            name,
            style: const TextStyle(fontSize: 11, color: AppColors.text3),
          ),
        ],
      ),
    );
  }
}

class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    var code = '';
    String? lang;
    if (element.children != null && element.children!.isNotEmpty) {
      final child = element.children!.first;
      if (child is md.Element && child.tag == 'code') {
        code = child.textContent;
        final cls = child.attributes['class'];
        if (cls != null && cls.startsWith('language-')) {
          lang = cls.substring('language-'.length);
        }
      }
    }
    if (code.isEmpty) code = element.textContent;
    return CodeBlockWidget(code: code.trim(), language: lang);
  }
}

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final v = ((_c.value + i / 3) % 1.0);
            final scale = 0.6 + v * 0.4;
            return Transform.scale(
              scale: scale,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.4 + v * 0.6),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
