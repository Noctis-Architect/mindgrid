import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/app_locale.dart';
import 'l10n/app_strings.dart';
import 'screens/home_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/app_logo.dart';
import 'widgets/toast_overlay.dart';

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
                color: AppColors.bgApp,
                child: Directionality(
                  textDirection: textDirection,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      child ?? const SizedBox.shrink(),
                      const ToastOverlay(),
                    ],
                  ),
                ),
              );
            },
            home: shell.ready
                ? const HomeScreen()
                : _LoadingScreen(strings: state.strings),
          );
        },
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(
              size: 48,
              borderRadius: 14,
              padding: 6,
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(color: AppColors.accent),
            const SizedBox(height: 12),
            Text(
              strings.loading,
              style: const TextStyle(color: AppColors.text3),
            ),
          ],
        ),
      ),
    );
  }
}
