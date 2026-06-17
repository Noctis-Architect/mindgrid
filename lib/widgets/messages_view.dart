import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/hover_surface.dart';
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

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      if (animate) {
        _scroll.animateTo(
          max,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
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

    if (state.messages.length != _lastMessageCount ||
        (state.isStreaming && lastContent != _lastContent)) {
      _lastMessageCount = state.messages.length;
      _lastContent = lastContent;
      _scrollToBottom(animate: !state.isStreaming);
    }

    if (state.messages.isEmpty) {
      return _WelcomeScreen(
        title: state.welcomeTitle,
        suggestions: state.welcomeSuggestions,
        refreshing: state.welcomeSuggestionsRefreshing,
        onSuggestion: widget.onSuggestion,
      );
    }

    final mobile = MediaQuery.sizeOf(context).width < mobileBreakpoint;

    // Message alignment uses visual left/right; isolate from app-wide RTL.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ListView.builder(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(
          mobile ? 12 : 20,
          mobile ? 12 : 20,
          mobile ? 12 : 20,
          12,
        ),
        itemCount: state.messages.length,
        itemBuilder: (context, index) {
          final msg = state.messages[index];
          final streaming = state.isStreaming &&
              index == state.messages.length - 1 &&
              msg.isAssistant;
          final alignFallback = state.messages
              .where((m) => m.isUser && m.content.trim().isNotEmpty)
              .map((m) => m.content)
              .lastOrNull ??
              '';
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: MessageBubble(
                message: msg,
                streaming: streaming,
                stopped: state.stoppedMessageIds.contains(msg.id),
                alignFallback: alignFallback,
                onRetry: (model) => state.retryMessage(msg.id, model: model),
                onCopy: () {},
                onEdit: () {
                  state.loadMessageToInput(
                      msg.id, (t) => widget.onSuggestion?.call(t));
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WelcomeScreen extends StatelessWidget {
  const _WelcomeScreen({
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
    final items = suggestions.isNotEmpty
        ? suggestions
        : _fallbackSuggestions(context.s);

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: mobile ? 16 : 24,
          vertical: mobile ? 24 : 40,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: mobile ? double.infinity : 520),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const AppLogo(size: 56),
              const SizedBox(height: 18),
              Text(
                title.isNotEmpty ? title : s.welcomeTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text1,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
                textDirection: detectTextDirection(
                  title.isNotEmpty ? title : s.welcomeTitle,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                s.welcomeSubtitle,
                style: const TextStyle(
                  color: AppColors.text3,
                  fontSize: 13,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
                textDirection: detectTextDirection(s.welcomeSubtitle),
              ),
              SizedBox(height: mobile ? 22 : 28),
              if (refreshing)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppColors.text4.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final item in items)
                    _SuggestionChip(
                      label: item.label,
                      onTap: () => onSuggestion?.call(item.prompt),
                    ),
                ],
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

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverSurface(
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: AppHover.duration,
        curve: AppHover.curve,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: hovered ? AppColors.bgHover : AppColors.bgPanel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hovered ? AppColors.borderFocus : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: hovered ? AppColors.text1 : AppColors.text2,
            fontWeight: FontWeight.w400,
            height: 1.3,
          ),
          textDirection: detectTextDirection(label),
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
