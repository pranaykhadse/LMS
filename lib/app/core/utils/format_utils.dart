import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

extension DateFormatExtension on DateTime {
  String toFormattedString(String format, BuildContext context) {
    return DateFormat(format, context.locale.languageCode).format(this);
  }
}

