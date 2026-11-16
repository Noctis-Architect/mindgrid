import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/hover_surface.dart';
import '../core/motion.dart';
import '../core/text_direction.dart';
import '../l10n/app_strings.dart';
import '../l10n/l10n.dart';
import '../models/welcome_suggestion.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'app_logo.dart';
import 'message_bubble.dart';

class MessagesView extends StatefulWidget {
  const MessagesView({super.key, this.onSuggestion});

  final void Function(String text)? onSuggestion;

  @override
  State<MessagesView> createState() => _MessagesViewState();
}

class _MessagesViewState extends State<MessagesView> {
  final _scroll = ScrollController();
  int _lastMessageCount = 0;
  String _lastContent = '';
  String? _lastChatId;
  bool _stick = true;
  bool _showJump = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final distance = pos.maxScrollExtent - pos.pixels;
    _stick = distance < 80;
    final show = distance > 240;
    if (show != _showJump) setState(() => _showJump = show);
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      if (animate) {
        _scroll.animateTo(
          max,
          duration: AppMotion.slow,
          curve: AppMotion.emphasized,
        );
      } else {
        _scroll.jumpTo(max);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final last = state.messages.isNotEmpty ? state.messages.last : null;
    final lastContent = last?.content ?? '';
    final chatChanged = state.currentChatId != _lastChatId;

    if (chatChanged) {
      _lastChatId = state.currentChatId;
      _lastMessageCount = state.messages.length;
      _lastContent = lastContent;
      _stick = true;
      _scrollToBottom(animate: false);
    } else if (state.messages.length != _lastMessageCount) {
      final grew = state.messages.length > _lastMessageCount;
      _lastMessageCount = state.messages.length;
      _lastContent = lastContent;
      if (grew) _stick = true;
      _scrollToBottom(animate: true);
    } else if (state.isStreaming && lastContent != _lastContent) {
      _lastContent = lastContent;
      if (_stick) _scrollToBottom(animate: false);
    }

    final mobile = MediaQuery.sizeOf(context).width < mobileBreakpoint;
    final Widget body;

    if (state.messages.isEmpty) {
      body = _WelcomeScreen(
        key: const ValueKey('welcome'),
        title: state.welcomeTitle,
        suggestions: state.welcomeSuggestions,
        refreshing: state.welcomeSuggestionsRefreshing,
        onSuggestion: widget.onSuggestion,
      );
    } else {
      final now = DateTime.now().millisecondsSinceEpoch;
      final alignFallback = state.messages
              .where((m) => m.isUser && m.content.trim().isNotEmpty)
              .map((m) => m.content)
              .lastOrNull ??
          '';
      // Message alignment uses visual left/right; isolate from app-wide RTL.
      body = Directionality(
        key: ValueKey('chat-${state.currentChatId}'),
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            ListView.builder(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(
                mobile ? 12 : 24,
                mobile ? 8 : 16,
                mobile ? 12 : 24,
                16,
              ),
              itemCount: state.messages.length,
              itemBuilder: (context, index) {
                final msg = state.messages[index];
                final streaming = state.isStreaming &&
                    index == state.messages.length - 1 &&
                    msg.isAssistant;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: FadeSlideIn(
                      key: ValueKey(msg.id),
                      enabled: now - msg.createdAt < 2500,
                      offset: const Offset(0, 14),
                      child: MessageBubble(
                        message: msg,
                        streaming: streaming,
                        stopped: state.stoppedMessageIds.contains(msg.id),
                        alignFallback: alignFallback,
                        onRetry: (model) =>
                            state.retryMessage(msg.id, model: model),
                        onCopy: () {},
                        onEdit: () {
                          state.loadMessageToInput(
                            msg.id,
                            (t) => widget.onSuggestion?.call(t),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedScale(
                  scale: _showJump ? 1 : 0.6,
                  duration: AppMotion.base,
                  curve: AppMotion.emphasized,
                  child: AnimatedOpacity(
                    opacity: _showJump ? 1 : 0,
                    duration: AppMotion.base,
                    child: IgnorePointer(
                      ignoring: !_showJump,
                      child: _JumpButton(
                        onTap: () {
                          _stick = true;
                          _scrollToBottom();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return FadeThrough(duration: AppMotion.slow, child: body);
  }
}

class _JumpButton extends StatelessWidget {
  const _JumpButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverSurface(
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: AppHover.duration,
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: hovered ? AppColors.bgActive : AppColors.bgElevated,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.borderMd),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.arrow_downward_rounded,
            size: 16, color: AppColors.text1),
      ),
    );
  }
}

class _WelcomeScreen extends StatelessWidget {
  const _WelcomeScreen({
    super.key,
    required this.title,
    required this.suggestions,
    required this.refreshing,
    this.onSuggestion,
  });

  final String title;
  final List<WelcomeSuggestionItem> suggestions;
  final bool refreshing;
  final void Function(String)? onSuggestion;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final mobile = MediaQuery.sizeOf(context).width < mobileBreakpoint;
    final items =
        suggestions.isNotEmpty ? suggestions : _fallbackSuggestions(s);
    final heading = title.isNotEmpty ? title : s.welcomeTitle;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: mobile ? 18 : 24,
          vertical: mobile ? 20 : 32,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FadeSlideIn(
                child: AppLogo(size: 54, borderRadius: 15),
              ),
              const SizedBox(height: 22),
              FadeSlideIn(
                delay: const Duration(milliseconds: 60),
                child: Text(
                  heading,
                  style: TextStyle(
                    fontSize: mobile ? 22 : 27,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text1,
                    height: 1.3,
                    letterSpacing: -0.2,
                  ),
                  textAlign: TextAlign.center,
                  textDirection: detectTextDirection(heading),
                ),
              ),
              const SizedBox(height: 8),
              FadeSlideIn(
                delay: const Duration(milliseconds: 110),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        s.welcomeSubtitle,
                        style: const TextStyle(
                          color: AppColors.text3,
                          fontSize: 14,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                        textDirection: detectTextDirection(s.welcomeSubtitle),
                      ),
                    ),
                    AnimatedSize(
                      duration: AppMotion.base,
                      child: refreshing
                          ? const Padding(
                              padding: EdgeInsetsDirectional.only(start: 10),
                              child: SizedBox(
                                width: 11,
                                height: 11,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.4,
                                  color: AppColors.text4,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              SizedBox(height: mobile ? 26 : 34),
              LayoutBuilder(
                builder: (context, c) {
                  final columns = c.maxWidth > 480 ? 2 : 1;
                  const gap = 10.0;
                  final w = (c.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (var i = 0; i < items.length; i++)
                        SizedBox(
                          width: w,
                          child: FadeSlideIn(
                            key: ValueKey('${items[i].label}-$i'),
                            delay: Duration(milliseconds: 160 + i * 45),
                            child: _SuggestionCard(
                              item: items[i],
                              onTap: () =>
                                  onSuggestion?.call(items[i].prompt),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<WelcomeSuggestionItem> _fallbackSuggestions(AppStrings s) {
    return s.welcomeSuggestions
        .map(
          (item) => WelcomeSuggestionItem(
            label: item.label,
            icon: item.icon,
            prompt: item.prompt,
          ),
        )
        .toList();
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.item, required this.onTap});

  final WelcomeSuggestionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dir = detectTextDirection(item.label);
    return HoverSurface(
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: AppHover.duration,
        curve: AppHover.curve,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: hovered ? AppColors.bgHover : AppColors.bgPanel,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: hovered ? AppColors.borderFocus : AppColors.border,
          ),
        ),
        child: Row(
          textDirection: dir,
          children: [
            Icon(
              item.icon,
              size: 17,
              color: hovered ? AppColors.accent : AppColors.text3,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: dir,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.text1,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.prompt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: detectTextDirection(item.prompt),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.text3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _LastOrNull<E> on Iterable<E> {
  E? get lastOrNull {
    if (isEmpty) return null;
    return last;
  }
}
