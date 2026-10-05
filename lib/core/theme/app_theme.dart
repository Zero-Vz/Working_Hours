import 'package:flutter/material.dart';

/// Material 3 主题（浅色 / 深色）
class AppTheme {
  const AppTheme._();

  static const Color _seed = Color(0xFF3F51B5);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF111318) : const Color(0xFFF4F6FB),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF111318) : const Color(0xFFF4F6FB),
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF1B1E24) : Colors.white,
        indicatorColor: scheme.secondaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, color: scheme.onSurface),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1B1E24) : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withOpacity(0.6)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF2C3038) : const Color(0xFF2C3038),
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withOpacity(0.5),
        thickness: 0.6,
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        backgroundColor: scheme.surfaceContainerHighest.withOpacity(0.7),
        labelStyle: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        iconColor: scheme.onSurfaceVariant,
      ),
    );
  }
}
