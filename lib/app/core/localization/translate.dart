import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

extension LocalizationExtension on String {
  String translate(BuildContext context) {
    /// TODO: If Required Translate this language. Use EasyLocalization Package for translation.
    return context.tr(this); //this.tr();
  }
}

class AppTranslations {
  static const languages = [
    Locale("en"),
  ];
}
