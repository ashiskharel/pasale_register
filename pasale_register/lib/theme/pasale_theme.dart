import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Black + outlined wireframe design — lightweight, modern, simple.
class PasaleTheme {
  static const Color ink = Color(0xFFFFFFFF);
  static const Color paper = Color(0xFF000000);
  static const Color mute = Color(0xFF9CA3AF);
  static const Color hairline = Color(0xFF3F3F46);
  static const Color fill = Color(0xFF0A0A0A);

  static const double radiusSm = 6;
  static const double radiusMd = 10;
  static const double radiusLg = 12;
  static const double radiusXl = 16;

  static ThemeData light() {
    // App is dark wireframe regardless of system brightness name.
    return dark();
  }

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: ink,
      onPrimary: paper,
      secondary: mute,
      onSecondary: paper,
      tertiary: ink,
      onTertiary: paper,
      error: Color(0xFFFF6B6B),
      onError: paper,
      surface: paper,
      onSurface: ink,
      surfaceContainerHighest: fill,
      surfaceContainerLowest: paper,
      outline: hairline,
      outlineVariant: Color(0xFF27272A),
      shadow: Colors.transparent,
      scrim: Colors.black54,
      inverseSurface: ink,
      onInverseSurface: paper,
      inversePrimary: paper,
    );

    final textTheme = _textTheme(scheme);
    final outlineBorder = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMd),
      side: const BorderSide(color: hairline, width: 1),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: paper,
      canvasColor: paper,
      dividerColor: hairline,
      visualDensity: VisualDensity.standard,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.white10,
      hoverColor: Colors.white10,

      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: paper,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: ink,
        ),
        iconTheme: const IconThemeData(color: ink, size: 22),
        shape: const Border(
          bottom: BorderSide(color: hairline, width: 1),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          side: const BorderSide(color: ink, width: 1),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final on = states.contains(WidgetState.selected);
          return IconThemeData(color: on ? ink : mute, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final on = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
            color: on ? ink : mute,
            fontSize: 11,
          );
        }),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: ink,
          foregroundColor: paper,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: paper,
          foregroundColor: ink,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: outlineBorder,
          side: const BorderSide(color: ink, width: 1),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          side: const BorderSide(color: ink, width: 1),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: hairline,
          ),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        backgroundColor: paper,
        foregroundColor: ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: ink),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: ink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: mute),
        hintStyle: textTheme.bodyMedium?.copyWith(color: mute),
        prefixIconColor: mute,
        suffixIconColor: mute,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: paper,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: hairline, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      listTileTheme: ListTileThemeData(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        iconColor: ink,
        textColor: ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(color: mute),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: paper,
        selectedColor: paper,
        side: const BorderSide(color: hairline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        labelStyle: textTheme.labelMedium?.copyWith(color: ink),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),

      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          side: const BorderSide(color: ink, width: 1),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: hairline,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
          side: BorderSide(color: hairline),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: paper,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: ink),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: ink),
        ),
        insetPadding: const EdgeInsets.all(16),
      ),

      dividerTheme: const DividerThemeData(
        color: hairline,
        space: 1,
        thickness: 1,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return paper;
          return mute;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return ink;
          return paper;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(hairline),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ink,
        linearTrackColor: hairline,
        circularTrackColor: hairline,
      ),

      popupMenuTheme: PopupMenuThemeData(
        elevation: 0,
        color: paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: hairline),
        ),
        textStyle: textTheme.bodyMedium?.copyWith(color: ink),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.selected)) {
              return ink.withValues(alpha: 0.08);
            }
            return paper;
          }),
          foregroundColor: const WidgetStatePropertyAll(ink),
          side: const WidgetStatePropertyAll(BorderSide(color: hairline)),
          textStyle: WidgetStatePropertyAll(
            textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
        ),
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    // System/platform fonts only — avoids google_fonts package + runtime fetch
    // (smaller APK, no network font dependency).
    final base = ThemeData.dark().textTheme;
    return base.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ).copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        color: scheme.onSurface,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: scheme.onSurface,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        height: 1.4,
        color: scheme.onSurface,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        height: 1.4,
        color: scheme.onSurface,
      ),
      bodySmall: base.bodySmall?.copyWith(color: mute),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
