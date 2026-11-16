import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/motion.dart';
import 'core/window_chrome.dart';
import 'l10n/app_locale.dart';
import 'l10n/app_strings.dart';
import 'screens/home_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/app_logo.dart';
import 'widgets/toast_overlay.dart';
import 'widgets/window_title_bar.dart';

class MindGridApp extends StatelessWidget {
  const MindGridApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: Selector<AppState, ({bool ready, AppLocale locale})>(
        selector: (_, state) => (ready: state.ready, locale: state.locale),
        builder: (context, shell, _) {
          final state = context.read<AppState>();
          final textDirection = shell.locale == AppLocale.fa
              ? TextDirection.rtl
              : TextDirection.ltr;

          return MaterialApp(
            title: 'MindGrid',
            debugShowCheckedModeBanner: false,
            locale: Locale(shell.locale.code),
            supportedLocales: const [
              Locale('en'),
              Locale('fa', 'IR'),
              Locale('fa'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.dark(),
            builder: (context, child) {
              return ColoredBox(
                color: AppColors.bgSidebar,
                child: Directionality(
                  textDirection: textDirection,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Column(
                        children: [
                          if (WindowChrome.enabled) const WindowTitleBar(),
                          Expanded(child: child ?? const SizedBox.shrink()),
                        ],
                      ),
                      const ToastOverlay(),
                    ],
                  ),
                ),
              );
            },
            home: AnimatedSwitcher(
              duration: AppMotion.slow,
              switchInCurve: AppMotion.emphasized,
              child: shell.ready
                  ? const HomeScreen(key: ValueKey('home'))
                  : _LoadingScreen(
                      key: const ValueKey('loading'),
                      strings: state.strings,
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({super.key, required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: Center(
        child: FadeSlideIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 56, borderRadius: 16, padding: 0),
              const SizedBox(height: 22),
              const SizedBox(
                width: 120,
                child: SmoothProgressBar(height: 3),
              ),
              const SizedBox(height: 14),
              Text(
                strings.loading,
                style: const TextStyle(color: AppColors.text3, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
