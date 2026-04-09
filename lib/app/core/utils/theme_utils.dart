import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../design/app_color_scheme.dart';

extension ThemeExtention on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  AppColorScheme get appColorScheme =>
      Theme.of(this).extension<AppColorScheme>()!;
}

extension HexColor on String {
  Color toColor() {
    // Remove the '#' if it's present
    String hex = replaceAll('#', '');

    // If the string doesn't have exactly 6 characters, it is invalid
    if (hex.length != 6) {
      throw FormatException(
          'Invalid hex color format. Expected a 6-character hex string.');
    }

    // Parse the hex string to an integer (RGB values)
    int hexInt = int.parse(hex, radix: 16);

    // Return a color with RGB values
    return Color(0xFF000000 |
        hexInt); // The 0xFF000000 ensures that the alpha channel is set to fully opaque.
  }

  DateTime? toTime() {
    if (isEmpty) {
      return null;
    }
    try {
      var parse = DateFormat("HH:mm:ss").parse(this);
      return DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        parse.hour,
        parse.minute,
        parse.second,
      );
    } catch (e) {
      return null;
    }
  }

  Duration? toDuration() {
    if (isEmpty) {
      return null;
    }
    try {
      var parse = DateFormat("HH:mm:ss").parse(this);
      return Duration(
        hours: parse.hour,
        minutes: parse.minute,
        seconds: parse.second,
      );
    } catch (e) {
      return null;
    }
  }
}
