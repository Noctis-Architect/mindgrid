import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/backup_dialog.dart';
import '../widgets/chat_input_area.dart';
import '../widgets/chat_top_bar.dart';
import '../widgets/image_generation_panel.dart';
import '../widgets/messages_view.dart';
import '../widgets/ollama_manager_dialog.dart';
import '../widgets/prompt_panel.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/user_profile_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _inputKey = GlobalKey<ChatInputAreaState>();

  bool _isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileBreakpoint;

  void _openPrompt() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: PromptPanel(onClose: () => Navigator.pop(ctx)),
      ),
    );
  }

  void _openSettings() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => SettingsDialog(onClose: () => Navigator.pop(ctx)),
    );
  }

  void _openUserProfile() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => UserProfileDialog(onClose: () => Navigator.pop(ctx)),
    );
  }

  void _openOllamaManager() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => OllamaManagerDialog(onClose: () => Navigator.pop(ctx)),
    );
  }

  void _openBackup() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => BackupDialog(onClose: () => Navigator.pop(ctx)),
    );
  }

  void _openImageGen() {
    final mobile = _isMobile(context);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(mobile ? 8 : 16),
        child: ImageGenerationPanel(onClose: () => Navigator.pop(ctx)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = _isMobile(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bgApp,
      drawer: mobile
          ? Drawer(
              backgroundColor: AppColors.bgSidebar,
              child: AppSidebar(
                onClose: () => Navigator.of(context).pop(),
                onPrompt: () {
                  Navigator.of(context).pop();
                  _openPrompt();
                },
                onSettings: () {
                  Navigator.of(context).pop();
                  _openSettings();
                },
                onUserProfile: () {
                  Navigator.of(context).pop();
                  _openUserProfile();
                },
                onOllamaManager: () {
                  Navigator.of(context).pop();
                  _openOllamaManager();
                },
                onBackup: () {
                  Navigator.of(context).pop();
                  _openBackup();
                },
                onImageGen: () {
                  Navigator.of(context).pop();
                  _openImageGen();
                },
              ),
            )
          : null,
      body: Row(
        children: [
          if (!mobile)
            SizedBox(
              width: 260,
              child: AppSidebar(
                onPrompt: _openPrompt,
                onSettings: _openSettings,
                onUserProfile: _openUserProfile,
                onOllamaManager: _openOllamaManager,
                onBackup: _openBackup,
                onImageGen: _openImageGen,
              ),
            ),
          Expanded(
            child: Column(
              children: [
                ChatTopBar(
                  onMenu: mobile
                      ? () => _scaffoldKey.currentState?.openDrawer()
                      : null,
                  onPrompt: _openPrompt,
                  onSettings: _openSettings,
                  onUserProfile: _openUserProfile,
                ),
                Expanded(
                  child: MessagesView(
                    onSuggestion: (text) =>
                        _inputKey.currentState?.setText(text),
                  ),
                ),
                ChatInputArea(key: _inputKey),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
