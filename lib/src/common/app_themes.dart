import 'package:flutter/material.dart';

/// Uygulama tema seçenekleri.
enum AppTheme {
  system('Sistem', Icons.brightness_auto),
  light('Açık', Icons.light_mode),
  dark('Koyu', Icons.dark_mode),
  ocean('Okyanus (Mavi)', Icons.water),
  midnight('Gece Mavisi', Icons.nights_stay);

  const AppTheme(this.label, this.icon);

  final String label;
  final IconData icon;
}

class AppThemes {
  const AppThemes._();

  /// Aydınlık tema (mavi vurgulu).
  static ThemeData get light => _build(
    brightness: Brightness.light,
    seed: const Color(0xFF2563EB),
    scaffold: const Color(0xFFF4F6FB),
    surface: Colors.white,
  );

  /// Standart koyu tema.
  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    seed: const Color(0xFF3B82F6),
    scaffold: const Color(0xFF121417),
    surface: const Color(0xFF1B1F24),
  );

  /// Verilen ekran görüntüsündeki gibi mavimsi koyu tema.
  static ThemeData get ocean => _build(
    brightness: Brightness.dark,
    seed: const Color(0xFF4F9CF9),
    scaffold: const Color(0xFF0D1B2A),
    surface: const Color(0xFF13293D),
    surfaceLow: const Color(0xFF1B3A54),
    primary: const Color(0xFF5AA9FF),
  );

  /// Daha koyu, gece mavisi varyant.
  static ThemeData get midnight => _build(
    brightness: Brightness.dark,
    seed: const Color(0xFF6C8CFF),
    scaffold: const Color(0xFF0A0E1A),
    surface: const Color(0xFF141B2E),
    surfaceLow: const Color(0xFF1D2740),
    primary: const Color(0xFF8AA4FF),
  );

  /// [AppTheme] için (light, dark) tema çifti ve ThemeMode döndürür.
  /// MaterialApp'e theme + darkTheme + themeMode olarak verilir.
  static (ThemeData lightTheme, ThemeData darkTheme, ThemeMode mode) resolve(
    AppTheme theme,
  ) {
    switch (theme) {
      case AppTheme.system:
        return (light, dark, ThemeMode.system);
      case AppTheme.light:
        return (light, dark, ThemeMode.light);
      case AppTheme.dark:
        return (light, dark, ThemeMode.dark);
      case AppTheme.ocean:
        return (light, ocean, ThemeMode.dark);
      case AppTheme.midnight:
        return (light, midnight, ThemeMode.dark);
    }
  }

  static ThemeData _build({
    required Brightness brightness,
    required Color seed,
    required Color scaffold,
    required Color surface,
    Color? surfaceLow,
    Color? primary,
  }) {
    var scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness)
        .copyWith(
          surface: surface,
          // Bu koyu temalarda iki konteyner tonu bilinçli olarak birleştirilir
          // (surfaceLow null olan light/dark'ta tohumdan gelen değerler korunur).
          surfaceContainerLow: surfaceLow,
          surfaceContainerLowest: surfaceLow,
        );
    if (primary != null) {
      scheme = scheme.copyWith(primary: primary);
    }
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
