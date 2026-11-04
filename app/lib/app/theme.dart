import 'package:flutter/material.dart';

/// Tema Material 3 ad alto contrasto, testi e pulsanti grandi.
ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0B57D0),
    brightness: brightness,
    contrastLevel: 0.5,
  );
  // Testi +10%: si parte dalla geometria tipografica M3, che definisce le
  // dimensioni (il textTheme di ThemeData non ha fontSize prima del merge).
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    textTheme: Typography.englishLike2021.apply(fontSizeFactor: 1.1),
  );
  return base.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(64, 56)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
    ),
    listTileTheme: const ListTileThemeData(minVerticalPadding: 14),
  );
}
