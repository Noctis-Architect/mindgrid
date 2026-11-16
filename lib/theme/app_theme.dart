import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Warm charcoal palette with a single ember accent.
class AppColors {
  // Surfaces
  static const bgSidebar = Color(0xFF100F0D); // app chrome (rail + lists)
  static const bgApp = Color(0xFF191816); // content panel
  static const bgPanel = Color(0xFF211F1C); // cards, dialogs
  static const bgElevated = Color(0xFF282623);
  static const bgInput = Color(0xFF1D1C19);
  static const bgHover = Color(0xFF2A2825);
  static const bgActive = Color(0xFF34312D);
  static const bgCode = Color(0xFF12110F);
  static const bgMsgAi = Color(0xFF1D1C19);
  static const bgMsgUser = Color(0xFF2B2926);

  // Lines
  static const border = Color(0x12FFF4E0);
  static const borderMd = Color(0x1FFFF4E0);
  static const borderFocus = Color(0x3DFFF4E0);

  // Text
  static const text1 = Color(0xFFF3EFE7);
  static const text2 = Color(0xFFC2BCAF);
  static const text3 = Color(0xFF8E887B);
  static const text4 = Color(0xFF625D53);

  // Accent
  static const accent = Color(0xFFE5794B);
  static const accentDim = Color(0xFFCF6438);
  static const accentGlow = Color(0x24E5794B);
  static const hoverTint = Color(0x0FE5794B);
  static const hoverBorder = Color(0x38E5794B);

  // Status
  static const yellow = Color(0xFFE2B455);
  static const red = Color(0xFFEA6259);
  static const green = Color(0xFF5DBE8A);
  static const purple = Color(0xFFB79BEA);
  static const teal = Color(0xFF5CC4B8);
}

/// Shared motion language: short, eased, never bouncy.
class AppMotion {
  static const fast = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 360);

  static const curve = Curves.easeOutCubic;
  static const emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
}

/// Bundled UI typeface (covers Persian/Arabic and Latin).
const appFontFamily = 'Vazirmatn';

class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 22.0;
}

class AppTheme {
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      surface: AppColors.bgApp,
      surfaceContainerHighest: AppColors.bgHover,
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.purple,
      error: AppColors.red,
      onSurface: AppColors.text1,
      onSurfaceVariant: AppColors.text3,
      outline: AppColors.borderMd,
      outlineVariant: AppColors.border,
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md - 2),
    );
    const buttonText = TextStyle(
      fontFamily: appFontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md - 2),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      canvasColor: AppColors.bgApp,
      scaffoldBackgroundColor: AppColors.bgApp,
      cardColor: AppColors.bgPanel,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      hoverColor: Colors.white.withValues(alpha: 0.04),
      dividerColor: AppColors.border,
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      fontFamily: appFontFamily,
      fontFamilyFallback: [
        GoogleFonts.notoSansSc().fontFamily,
        GoogleFonts.notoSansJp().fontFamily,
        GoogleFonts.notoSansKr().fontFamily,
      ].whereType<String>().toList(),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgApp,
        foregroundColor: AppColors.text1,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      iconTheme: const IconThemeData(color: AppColors.text3, size: 18),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: AppColors.accent.withValues(alpha: 0.32),
        selectionHandleColor: AppColors.accent,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(6),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => Colors.white.withValues(
            alpha:
                states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.dragged)
                ? 0.22
                : 0.10,
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.bgActive,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.borderMd),
        ),
        textStyle: const TextStyle(
          fontFamily: appFontFamily,
          color: AppColors.text1,
          fontSize: 12,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgInput,
        hoverColor: Colors.transparent,
        border: inputBorder(AppColors.borderMd),
        enabledBorder: inputBorder(AppColors.borderMd),
        focusedBorder: inputBorder(AppColors.accent, 1.4),
        errorBorder: inputBorder(AppColors.red),
        focusedErrorBorder: inputBorder(AppColors.red, 1.4),
        labelStyle: const TextStyle(
          fontFamily: appFontFamily,
          color: AppColors.text3,
          fontSize: 13,
        ),
        floatingLabelStyle: const TextStyle(
          fontFamily: appFontFamily,
          color: AppColors.accent,
          fontSize: 13,
        ),
        hintStyle: const TextStyle(
          fontFamily: appFontFamily,
          color: AppColors.text4,
          fontSize: 13.5,
        ),
        helperStyle: const TextStyle(
          fontFamily: appFontFamily,
          color: AppColors.text4,
          fontSize: 11.5,
        ),
        errorStyle: const TextStyle(
          fontFamily: appFontFamily,
          color: AppColors.red,
          fontSize: 11.5,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.bgHover,
          disabledForegroundColor: AppColors.text4,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text1,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          side: const BorderSide(color: AppColors.borderMd),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.text2,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.text2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? Colors.white : AppColors.text3,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.bgActive,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: const BorderSide(color: AppColors.text4, width: 1.4),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.accent,
        thumbColor: Colors.white,
        inactiveTrackColor: AppColors.bgActive,
        overlayColor: AppColors.accent.withValues(alpha: 0.12),
        trackHeight: 3,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.bgActive,
        circularTrackColor: Colors.transparent,
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: AppColors.accent,
        labelColor: AppColors.text1,
        unselectedLabelColor: AppColors.text3,
        dividerColor: AppColors.border,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.bgElevated,
        contentTextStyle: TextStyle(
          fontFamily: appFontFamily,
          color: AppColors.text1,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgPanel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl - 2),
          side: const BorderSide(color: AppColors.borderMd),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: appFontFamily,
          color: AppColors.text1,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: appFontFamily,
          color: AppColors.text2,
          fontSize: 14,
          height: 1.6,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.bgElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.borderMd),
        ),
        textStyle: const TextStyle(
          fontFamily: appFontFamily,
          color: AppColors.text1,
          fontSize: 13,
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.bgSidebar,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.text3,
        textColor: AppColors.text1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgHover,
        labelStyle: const TextStyle(
          fontFamily: appFontFamily,
          color: AppColors.text2,
          fontSize: 12,
        ),
        side: const BorderSide(color: AppColors.borderMd),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(
          fontFamily: appFontFamily,
          color: AppColors.text1,
          fontSize: 15,
        ),
        bodyMedium: TextStyle(
          fontFamily: appFontFamily,
          color: AppColors.text1,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          fontFamily: appFontFamily,
          color: AppColors.text3,
          fontSize: 12,
        ),
        titleLarge: TextStyle(
          fontFamily: appFontFamily,
          color: AppColors.text1,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          fontFamily: appFontFamily,
          color: AppColors.text1,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        labelLarge: TextStyle(
          fontFamily: appFontFamily,
          color: AppColors.text1,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: TextStyle(
          fontFamily: appFontFamily,
          color: AppColors.text3,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

const mobileBreakpoint = 720.0;
