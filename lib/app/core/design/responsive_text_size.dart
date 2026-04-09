import 'package:flutter/material.dart';

class ResponseTextSize {
  static TextTheme getCorrectSizedTextTheme(BuildContext context) {
    final deviceSize = MediaQuery.of(context).size;
    final fontSizes = _fontSizes.keys.firstWhere((element) {
      final deviceSizeRange = _deviceSize[element]!;
      return deviceSizeRange.min <= deviceSize.width &&
          deviceSizeRange.max >= deviceSize.width;
    });
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: _fontSizes[fontSizes]!.displayLarge,
        fontWeight: FontWeight.w300,
      ),
      displayMedium: TextStyle(
        fontSize: _fontSizes[fontSizes]!.displayMedium,
        fontWeight: FontWeight.w300,
      ),
      displaySmall: TextStyle(
        fontSize: _fontSizes[fontSizes]!.displaySmall,
        fontWeight: FontWeight.w300,
      ),
      headlineLarge: TextStyle(
        fontSize: _fontSizes[fontSizes]!.headlineLarge,
        fontWeight: FontWeight.w400,
      ),
      headlineMedium: TextStyle(
        fontSize: _fontSizes[fontSizes]!.headlineMedium,
        fontWeight: FontWeight.w400,
      ),
      headlineSmall: TextStyle(
        fontSize: _fontSizes[fontSizes]!.headlineSmall,
        fontWeight: FontWeight.w400,
      ),
      titleLarge: TextStyle(
        fontSize: _fontSizes[fontSizes]!.titleLarge,
        fontWeight: FontWeight.w500,
      ),
      titleMedium: TextStyle(
        fontSize: _fontSizes[fontSizes]!.titleMedium,
      ),
      titleSmall: TextStyle(
        fontSize: _fontSizes[fontSizes]!.titleSmall,
      ),
      labelLarge: TextStyle(
        fontSize: _fontSizes[fontSizes]!.labelLarge,
      ),
      labelMedium: TextStyle(
        fontSize: _fontSizes[fontSizes]!.labelMedium,
      ),
      labelSmall: TextStyle(
        fontSize: _fontSizes[fontSizes]!.labelSmall,
      ),
      bodyLarge: TextStyle(
        fontSize: _fontSizes[fontSizes]!.bodyLarge,
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: TextStyle(
        fontSize: _fontSizes[fontSizes]!.bodyMedium,
      ),
      bodySmall: TextStyle(
        fontSize: _fontSizes[fontSizes]!.bodySmall,
      ),
    );
  }

  static const _deviceSize = {
    'small': (min: 0, max: 600),
    'medium': (min: 600, max: double.infinity),
    // 'large': (min: 900, max: 1200),
    // 'xlarge': (min: 1200, max: double.infinity),
  };

  static const _fontSizes = {
    'small': (
      displayLarge: 75.0,
      displayMedium: 50.0,
      displaySmall: 41.0,
      headlineLarge: 30.0,
      headlineMedium: 25.0,
      headlineSmall: 21.0,
      titleLarge: 20.0,
      titleMedium: 17.0,
      titleSmall: 14.0,
      labelLarge: 14.0,
      labelMedium: 12.0,
      labelSmall: 11.0,
      bodyLarge: 14.0,
      bodyMedium: 13.0,
      bodySmall: 11.0,
    ),
    'medium': (
      displayLarge: 100.0,
      displayMedium: 75.0,
      displaySmall: 60.0,
      headlineLarge: 45.0,
      headlineMedium: 36.0,
      headlineSmall: 30.0,
      titleLarge: 16.0,
      titleMedium: 14.0,
      titleSmall: 12.0,
      labelLarge: 14.0,
      labelMedium: 14.0,
      labelSmall: 12.0,
      bodyLarge: 16.0,
      bodyMedium: 12.0,
      bodySmall: 10.0,
    ),
    'large': (
      displayLarge: 125.0,
      displayMedium: 100.0,
      displaySmall: 75.0,
      headlineLarge: 60.0,
      headlineMedium: 45.0,
      headlineSmall: 30.0,
      titleLarge: 36.0,
      titleMedium: 30.0,
      titleSmall: 24.0,
      labelLarge: 22.0,
      labelMedium: 18.0,
      labelSmall: 16.0,
      bodyLarge: 18.0,
      bodyMedium: 12.0,
      bodySmall: 10.0,
    ),
    'xlarge': (
      displayLarge: 150.0,
      displayMedium: 125.0,
      displaySmall: 100.0,
      headlineLarge: 75.0,
      headlineMedium: 60.0,
      headlineSmall: 45.0,
      titleLarge: 45.0,
      titleMedium: 36.0,
      titleSmall: 30.0,
      labelLarge: 24.0,
      labelMedium: 20.0,
      labelSmall: 18.0,
      bodyLarge: 20.0,
      bodyMedium: 18.0,
      bodySmall: 16.0,
    ),
  };
}
