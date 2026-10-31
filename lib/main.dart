import 'package:flutter/material.dart' as flutter;
import 'package:dynamic_color/dynamic_color.dart';

import 'package:preplist/app/main_screen.dart';
import 'package:preplist/app/food_bootstrapper.dart';

void main() {
  flutter.WidgetsFlutterBinding.ensureInitialized();
  flutter.runApp(const PrepListApp());
}

class PrepListApp extends flutter.StatelessWidget {
  const PrepListApp({super.key});

  static const _seedColor = flutter.Colors.green;

  flutter.ColorScheme _fallbackScheme(flutter.Brightness brightness) {
    return flutter.ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );
  }

  flutter.ColorScheme _convertScheme(
    dynamic source,
    flutter.Brightness brightness,
  ) {
    if (source == null) {
      return _fallbackScheme(brightness);
    }

    return flutter.ColorScheme(
      brightness: brightness,
      primary: source.primary,
      onPrimary: source.onPrimary,
      primaryContainer: source.primaryContainer,
      onPrimaryContainer: source.onPrimaryContainer,
      secondary: source.secondary,
      onSecondary: source.onSecondary,
      secondaryContainer: source.secondaryContainer,
      onSecondaryContainer: source.onSecondaryContainer,
      tertiary: source.tertiary,
      onTertiary: source.onTertiary,
      tertiaryContainer: source.tertiaryContainer,
      onTertiaryContainer: source.onTertiaryContainer,
      error: source.error,
      onError: source.onError,
      errorContainer: source.errorContainer,
      onErrorContainer: source.onErrorContainer,
      surface: source.surface,
      onSurface: source.onSurface,
      surfaceContainerLowest: source.surfaceContainerLowest,
      surfaceContainerLow: source.surfaceContainerLow,
      surfaceContainer: source.surfaceContainer,
      surfaceContainerHigh: source.surfaceContainerHigh,
      surfaceContainerHighest: source.surfaceContainerHighest,
      onSurfaceVariant: source.onSurfaceVariant,
      outline: source.outline,
      outlineVariant: source.outlineVariant,
      shadow: source.shadow,
      scrim: source.scrim,
      inverseSurface: source.inverseSurface,
      onInverseSurface: source.onInverseSurface,
      inversePrimary: source.inversePrimary,
    );
  }

  @override
  flutter.Widget build(flutter.BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightScheme = _convertScheme(
          lightDynamic,
          flutter.Brightness.light,
        );

        final darkScheme = _convertScheme(darkDynamic, flutter.Brightness.dark);

        return flutter.MaterialApp(
          title: 'PrepList',
          debugShowCheckedModeBanner: false,
          theme: flutter.ThemeData(
            useMaterial3: true,
            colorScheme: lightScheme,
          ),
          darkTheme: flutter.ThemeData(
            useMaterial3: true,
            colorScheme: darkScheme,
          ),
          themeMode: flutter.ThemeMode.system,
          home: const FoodBootstrapper(child: MainScreen()),
        );
      },
    );
  }
}
