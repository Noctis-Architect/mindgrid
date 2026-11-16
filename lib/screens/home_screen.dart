import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_page.dart';
import '../core/motion.dart';
import '../core/window_chrome.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/backup_dialog.dart';
import '../widgets/chat_input_area.dart';
import '../widgets/chat_top_bar.dart';
import '../widgets/image_generation_panel.dart';
import '../widgets/messages_view.dart';
import '../widgets/model_hub/model_hub_dialog.dart';
import '../widgets/nav_rail.dart';
import '../widgets/prompt_panel.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/speech/speech_page.dart';
import '../widgets/user_profile_dialog.dart';

/// App shell: navigation rail, conversation list and a floating content
/// panel that hosts each section as a full page.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _listWidth = 268.0;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _inputKey = GlobalKey<ChatInputAreaState>();
  AppPage _page = AppPage.chat;
  bool _listOpen = true;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    final whisper = context.read<AppState>().whisper;
    // Never leave the speech engine running after the window closes.
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        await whisper.stop();
        return AppExitResponse.exit;
      },
      onDetach: whisper.stop,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  bool _isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileBreakpoint;

  void _go(AppPage page) {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    if (page != _page) setState(() => _page = page);
  }

  void _toggleList() {
    if (_isMobile(context)) {
      _scaffoldKey.currentState?.openDrawer();
    } else {
      setState(() => _listOpen = !_listOpen);
    }
  }

  void _newChat() {
    context.read<AppState>().newChat();
    _go(AppPage.chat);
  }

  Widget _pageFor(AppPage page, bool mobile) {
    void close() => _go(AppPage.chat);
    Widget framed(Widget child) => Center(
          child: Padding(
            padding: EdgeInsets.all(mobile ? 8 : 20),
            child: child,
          ),
        );
    return switch (page) {
      AppPage.chat => const SizedBox.shrink(),
      AppPage.models => ModelHubDialog(onClose: close, embedded: true),
      AppPage.speech => SpeechPage(onClose: close),
      AppPage.images => framed(ImageGenerationPanel(onClose: close)),
      AppPage.prompts => framed(PromptPanel(onClose: close)),
      AppPage.profile => UserProfileDialog(onClose: close),
      AppPage.backup => BackupDialog(onClose: close),
      AppPage.settings => SettingsDialog(onClose: close),
    };
  }

  @override
  Widget build(BuildContext context) {
    final mobile = _isMobile(context);
    final onChat = _page == AppPage.chat;
    final showList = !mobile && _listOpen && onChat;

    final chatPage = Column(
      children: [
        ChatTopBar(
          onMenu: mobile || !_listOpen ? _toggleList : null,
          onPrompt: () => _go(AppPage.prompts),
          onSettings: () => _go(AppPage.settings),
          onUserProfile: () => _go(AppPage.profile),
          onModelHub: () => _go(AppPage.models),
        ),
        Expanded(
          child: MessagesView(
            onSuggestion: (text) => _inputKey.currentState?.setText(text),
          ),
        ),
        ChatInputArea(key: _inputKey),
      ],
    );

    // The chat stays mounted so drafts and scroll position survive a visit
    // to another section.
    final content = Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          ignoring: !onChat,
          child: AnimatedOpacity(
            opacity: onChat ? 1 : 0,
            duration: AppMotion.base,
            curve: AppMotion.curve,
            child: AnimatedSlide(
              offset: onChat ? Offset.zero : const Offset(0, 0.015),
              duration: AppMotion.slow,
              curve: AppMotion.emphasized,
              child: chatPage,
            ),
          ),
        ),
        FadeThrough(
          duration: AppMotion.slow,
          child: KeyedSubtree(
            key: ValueKey(_page),
            child: onChat ? const SizedBox.expand() : _pageFor(_page, mobile),
          ),
        ),
      ],
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyB, control: true):
            _toggleList,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): _newChat,
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: mobile ? AppColors.bgApp : AppColors.bgSidebar,
        drawerScrimColor: Colors.black.withValues(alpha: 0.55),
        drawer: mobile
            ? Drawer(
                width: 304,
                child: SafeArea(
                  child: AppSidebar(
                    page: _page,
                    drawer: true,
                    onNavigate: _go,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                ),
              )
            : null,
        body: SafeArea(
          child: mobile
              ? content
              : Row(
                  children: [
                    NavRail(page: _page, onSelect: _go, onNewChat: _newChat),
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: showList ? 1.0 : 0.0),
                      duration: AppMotion.slow,
                      curve: AppMotion.emphasized,
                      builder: (context, t, child) {
                        if (t == 0) return const SizedBox.shrink();
                        return ClipRect(
                          child: SizedBox(
                            width: _listWidth * t,
                            child: OverflowBox(
                              alignment: AlignmentDirectional.centerEnd,
                              minWidth: _listWidth,
                              maxWidth: _listWidth,
                              child: Opacity(opacity: t, child: child),
                            ),
                          ),
                        );
                      },
                      child: AppSidebar(
                        page: _page,
                        onNavigate: _go,
                        onCollapse: _toggleList,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                          0,
                          WindowChrome.enabled ? 0 : 8,
                          8,
                          8,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.bgApp,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(17),
                            child: content,
                          ),
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
