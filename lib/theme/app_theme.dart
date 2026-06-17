import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Backgrounds — darker, more depth
  static const bgApp      = Color(0xFF0D0D0D);
  static const bgSidebar  = Color(0xFF111111);
  static const bgPanel    = Color(0xFF1A1A1A);
  static const bgInput    = Color(0xFF1A1A1A);
  static const bgHover    = Color(0xFF222222);
  static const bgActive   = Color(0xFF2A2A2A);
  static const bgCode     = Color(0xFF141414);
  static const bgMsgAi    = Color(0xFF161616);
  static const bgMsgUser  = Color(0xFF1F2937);

  // Borders
  static const border     = Color(0x14FFFFFF);
  static const borderMd   = Color(0x1FFFFFFF);
  static const borderFocus= Color(0x3FFFFFFF);

  // Text
  static const text1 = Color(0xFFF0F0F0);
  static const text2 = Color(0xFFAAAAAA);
  static const text3 = Color(0xFF666666);
  static const text4 = Color(0xFF3F3F3F);

  // Accent — electric blue instead of green
  static const accent      = Color(0xFF6C8EFF);
  static const accentDim   = Color(0xFF4B6EE8);
  static const accentGlow  = Color(0x206C8EFF);
  static const hoverTint   = Color(0x0C6C8EFF);
  static const hoverBorder = Color(0x266C8EFF);

  // Status colors
  static const yellow  = Color(0xFFEAB308);
  static const red     = Color(0xFFEF4444);
  static const green   = Color(0xFF22C55E);
  static const purple  = Color(0xFFA78BFA);
  static const teal    = Color(0xFF2DD4BF);
}

class AppTheme {
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      surface:   AppColors.bgApp,
      primary:   AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.purple,
      error:     AppColors.red,
      onSurface: AppColors.text1,
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
      hoverColor: AppColors.bgHover.withValues(alpha: 0.08),
      dividerColor: AppColors.border,
      fontFamily: GoogleFonts.vazirmatn().fontFamily,
      fontFamilyFallback: [
        GoogleFonts.notoSansSc().fontFamily,
        GoogleFonts.notoSansJp().fontFamily,
        GoogleFonts.notoSansKr().fontFamily,
      ].whereType<String>().toList(),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgApp,
        foregroundColor: AppColors.text1,
        elevation: 0,
      ),
      iconTheme: const IconThemeData(color: AppColors.text3, size: 18),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderMd),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderMd),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.text3, fontSize: 12),
        hintStyle: const TextStyle(color: AppColors.text4),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.accent,
        thumbColor: AppColors.accent,
        inactiveTrackColor: AppColors.bgHover,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.bgPanel,
        contentTextStyle: TextStyle(color: AppColors.text1),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgPanel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          color: AppColors.text1,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.text2,
          fontSize: 14,
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColors.bgPanel,
        textStyle: TextStyle(color: AppColors.text1),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.text3,
        textColor: AppColors.text1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgHover,
        labelStyle: const TextStyle(color: AppColors.text2, fontSize: 12),
        side: const BorderSide(color: AppColors.borderMd),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      textTheme: GoogleFonts.vazirmatnTextTheme(
        const TextTheme(
          bodyMedium: TextStyle(color: AppColors.text1, fontSize: 14),
          bodySmall: TextStyle(color: AppColors.text3, fontSize: 12),
          titleMedium: TextStyle(
            color: AppColors.text1,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          labelSmall: TextStyle(
            color: AppColors.text3,
            fontSize: 11,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

const mobileBreakpoint = 640.0;
