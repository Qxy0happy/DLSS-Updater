import 'package:material_ui/material_ui.dart';

/// Seed for the Material 3 color scheme. Deliberately new: the old Flet
/// palette is not carried over.
const Color _seedColor = Color(0xFF2F6F5E);

/// Builds the application theme for the given brightness.
ThemeData buildAppTheme(Brightness brightness) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    ),
  );
}
