import 'package:flutter/material.dart';

/// App theming. Theme preference is a per-user setting (deferred feature in the
/// cut-list); these are the light/dark defaults.
class AppTheme {
  const AppTheme._();

  static const Color _seed = Color(0xFF1B5E20); // Chuka green

  static ThemeData get light => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed),
    useMaterial3: true,
  );

  static ThemeData get dark => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );
}
