import 'package:flutter/material.dart';

/// Design tokens for the "Soft & Friendly" redesign.
///
/// Rules applied (mobile-app-ui-design skill):
///  - 60/30/10 color: blue base + neutral text + ONE warm accent (amber),
///    used sparingly for badges / empty states / celebration moments.
///  - 4 font sizes total (32 / 20 / 16 / 13), 2 weights (400 / 600).
///  - 8-point spacing grid is enforced at page level; radii here are the
///    friendly part: cards 20, buttons 16, sheets & dialogs 24.
///  - Every component reads from [ColorScheme] — nothing is hardcoded, so
///    light and dark stay correct without per-widget fixes.
abstract final class AppTheme {
  /// Finance/trust base (user choice over the old deepPurple).
  static const Color seed = Colors.blue;

  /// The 10% warm accent — friendly amber for playful highlights.
  static const Color warmAccent = Color(0xFFFFB74D);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  /// Money looks wrong when digits jitter — tabular figures keep columns aligned.
  static const List<FontFeature> _figures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static ThemeData _build(Brightness brightness) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    final TextTheme t = _textTheme(scheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: _textTheme(scheme),
      splashFactory: InkRipple.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: _textTheme(scheme).titleLarge,
      ),

      // Friendly = big soft cards, lifted by tonal color instead of heavy shadow.
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: _textTheme(scheme).labelLarge,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: _textTheme(scheme).labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: _textTheme(scheme).labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: _textTheme(scheme).labelLarge,
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 2,
      ),

      // For the Event page's tab bar.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll<TextStyle>(
          t.labelSmall ?? const TextStyle(fontSize: 13),
        ),
        iconTheme: WidgetStatePropertyAll<IconThemeData>(
          IconThemeData(size: 24, color: scheme.onSurfaceVariant),
        ),
      ),

      chipTheme: ChipThemeData(
        shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        labelStyle: t.labelSmall ?? const TextStyle(fontSize: 13),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: _textTheme(scheme).titleLarge,
        contentTextStyle: _textTheme(scheme).bodyLarge,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: _textTheme(
          scheme,
        ).bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        iconColor: scheme.onSurfaceVariant,
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
    );
  }

  /// Exactly four sizes, two weights — hierarchy from size/weight, not clutter.
  static TextTheme _textTheme(ColorScheme scheme) {
    const FontWeight regular = FontWeight.w400;
    const FontWeight strong = FontWeight.w600;

    return TextTheme(
      // 32 — balances, the one number that matters per screen
      displayLarge: const TextStyle(
        fontSize: 32,
        fontWeight: strong,
        height: 1.2,
      ).copyWith(color: scheme.onSurface, fontFeatures: _figures),
      displayMedium: const TextStyle(
        fontSize: 32,
        fontWeight: strong,
        height: 1.2,
      ).copyWith(color: scheme.onSurface, fontFeatures: _figures),
      // 20 — screen & section titles
      titleLarge: const TextStyle(
        fontSize: 20,
        fontWeight: strong,
      ).copyWith(color: scheme.onSurface),
      titleMedium: const TextStyle(
        fontSize: 20,
        fontWeight: strong,
      ).copyWith(color: scheme.onSurface),
      // 16 — body & card titles
      bodyLarge: const TextStyle(
        fontSize: 16,
        fontWeight: regular,
        height: 1.4,
      ).copyWith(color: scheme.onSurface),
      bodyMedium: const TextStyle(
        fontSize: 16,
        fontWeight: regular,
        height: 1.4,
      ).copyWith(color: scheme.onSurfaceVariant),
      // 13 — labels, chips, metadata
      labelLarge: const TextStyle(
        fontSize: 13,
        fontWeight: strong,
        letterSpacing: 0.2,
      ).copyWith(color: scheme.onSurface),
      labelMedium: const TextStyle(
        fontSize: 13,
        fontWeight: regular,
      ).copyWith(color: scheme.onSurfaceVariant),
      labelSmall: const TextStyle(
        fontSize: 13,
        fontWeight: regular,
      ).copyWith(color: scheme.onSurfaceVariant),
    );
  }

  /// Foreground for icons/text sitting ON a warmAccent surface. Always dark:
  /// warmAccent is a fixed amber in both modes, so onSurface would go
  /// white-on-amber (~1.9:1) in dark mode.
  static const Color onWarm = Color(0xFF33250A);
}
