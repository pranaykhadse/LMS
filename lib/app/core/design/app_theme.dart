import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms/app/core/utils/utils.dart';

import 'app_color_scheme.dart';
import 'responsive_text_size.dart';

class AppTheme {
  static ThemeData getLight(BuildContext context) {
    return _constructForColorScheme(
      context,
      AppColorScheme.light,
      Brightness.light,
    );
  }

  static ThemeData _constructForColorScheme(
    BuildContext context,
    AppColorScheme appColorScheme,
    Brightness brightness,
  ) {
    var appTextTheme = getAppTextTheme(appColorScheme, context);
    return ThemeData(
      useMaterial3: false,
      colorScheme: ColorScheme.fromSeed(
        seedColor: appColorScheme.primary,
        primary: appColorScheme.primary,
        brightness: brightness,
        surface: appColorScheme.background,
        surfaceTint: appColorScheme.secondaryCard,
      ),
      brightness: brightness,
      scaffoldBackgroundColor: appColorScheme.background,
      // fontFamily: "SFProText",
      textTheme: appTextTheme,
      primaryColorDark: appColorScheme.primaryDark,
      primaryColorLight: appColorScheme.primaryLight,
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.mediumRadius),
        ),
        backgroundColor: appColorScheme.primary,
      ),
      extensions: [appColorScheme],
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.smallRadius),
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 20),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return null;
            return appColorScheme.primary;
          }),
          textStyle: WidgetStatePropertyAll(appTextTheme.bodyMedium),
          elevation: const WidgetStatePropertyAll(0),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return null;
            return appColorScheme.onPrimary;
          }),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        visualDensity: VisualDensity.compact,
        side: const BorderSide(color: Colors.grey),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return appColorScheme.primary;
          }
          return null;
        }),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(appTextTheme.labelMedium),
          elevation: const WidgetStatePropertyAll(0),
          side: WidgetStateBorderSide.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return null;

            return BorderSide(color: appColorScheme.primary);
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return null;
            return appColorScheme.primary;
          }),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        // filled: true,
        // fillColor: const Color(0xFFFAFAFA),
        border: OutlineInputBorder(),
        // border: const OutlineInputBorder(
        //   borderSide: BorderSide(color: Colors.transparent),
        // ),
        // enabledBorder: const OutlineInputBorder(
        //   borderSide: BorderSide(color: Colors.transparent),
        // ),
        // focusedBorder: OutlineInputBorder(
        //   borderSide: BorderSide(color: appColorScheme.primary),
        // ),
      ),
    );
  }

  static TextTheme getAppTextTheme(
    AppColorScheme colorScheme,
    BuildContext context,
  ) => GoogleFonts.ralewayTextTheme(
    ResponseTextSize.getCorrectSizedTextTheme(context).copyWith(
      headlineSmall: const TextStyle(fontWeight: FontWeight.bold),
      titleLarge: const TextStyle(fontWeight: FontWeight.bold),
      labelLarge: const TextStyle(fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(color: colorScheme.textColor),
    ),
  );
}
