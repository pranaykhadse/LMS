import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

extension DateFormatExtension on DateTime {
  String toFormattedString(String format, BuildContext context) {
    return DateFormat(format, context.locale.languageCode).format(this);
  }
}

extension HtmlStringExtension on String {
  /// Strips HTML tags and decodes common HTML entities, returning plain text.
  ///
  /// Example:
  ///   '<p>test description - data</p>'  →  'test description - data'
  ///   '<b>Bold</b> &amp; plain'         →  'Bold & plain'
  String get stripHtml {
    // Remove all HTML tags (e.g. <p>, </p>, <br />, etc.)
    final withoutTags = replaceAll(RegExp(r'<[^>]*>'), '');

    // Decode common HTML entities
    return withoutTags
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}

