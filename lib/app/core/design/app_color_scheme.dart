import 'package:flutter/material.dart';

abstract class AppColorScheme extends ThemeExtension<AppColorScheme> {
  // static final AppColorScheme dark = _DarkColorScheme();
  static final AppColorScheme light = _LightColorScheme();

  Color get background;
  Color get textColor;
  Color get onPrimary;

  Color get primaryCard;
  Color get secondaryCard;

  ///
  /// Common Color
  ///
  Color get waring => const Color.fromARGB(255, 247, 157, 1);
  Color get error => Colors.red;
  Color get success => Colors.green;

  Color get primary => Color(0xFF754cbf);
  Color get secondary => Color(0xFF40479a);

  Color get primaryDark => Color(0xFF513ab4);
  Color get primaryLight => Color(0xFFc6b8e3);

  LinearGradient get gradient => LinearGradient(
    colors: [primaryDark, primaryLight],
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
  );
  Color get border => const Color(0xFFDCDCDC);
  Color get grey => const Color.fromARGB(255, 138, 137, 137);

  StatusColor get completed => const StatusColor(
    foreground: Color(0xFF2CA741),
    background: Color(0xFFE5FBE7),
  );
  StatusColor get unresolved => const StatusColor(
    foreground: Color(0xFF2B3B90),
    background: Color(0xFFEFE6FF),
  );
  StatusColor get review => const StatusColor(
    foreground: Color(0xFF902B2B),
    background: Color(0xFFFFE6E6),
  );
  StatusColor get pending => const StatusColor(
    foreground: Color(0xFFA7612C),
    background: Color(0xFFFBF6E5),
  );

  @override
  ThemeExtension<AppColorScheme> copyWith() {
    return this;
  }

  @override
  ThemeExtension<AppColorScheme> lerp(
    covariant ThemeExtension<AppColorScheme>? other,
    double t,
  ) {
    return this;
  }
}

// class _DarkColorScheme extends AppColorScheme {
//   @override
//   Color get background => const Color(0xFF111426);
//   @override
//   Color get textColor => Colors.white;
//   @override
//   Color get onPrimary => Colors.white;

//   @override
//   Color get primaryCard => const Color(0xFF1A1D2E);

//   @override
//   Color get secondaryCard => const Color(0xFF282A3F);
// }

class _LightColorScheme extends AppColorScheme {
  @override
  Color get background => const Color(0xFFF1F1EF);
  @override
  Color get textColor => const Color(0XFF494949);
  @override
  Color get onPrimary => Colors.white;
  @override
  Color get primaryCard => Colors.white;

  @override
  Color get secondaryCard => const Color(0xFFF6F6F6);
}

class StatusColor {
  final Color foreground;
  final Color background;
  const StatusColor({required this.foreground, required this.background});
}
