import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

extension DateFormatExtension on DateTime {
  String toFormattedString(String format, BuildContext context) {
    return DateFormat(format, context.locale.languageCode).format(this);
  }
}

extension ApiUtcDateParsing on String {
  /// Parses this string as a moment coming from the API and converts it to
  /// the device's local timezone for display.
  ///
  /// The backend sends all date/time values as UTC (GMT+0) without an
  /// explicit 'Z'/offset marker, so `DateTime.tryParse` would otherwise treat
  /// them as already-local values and display the wrong time. This always
  /// re-anchors the parsed value to UTC before converting, so it's correct
  /// whether or not the source string happens to carry a timezone marker.
  DateTime? parseApiUtc() {
    final value = trim();
    if (value.isEmpty) return null;
    final dt = DateTime.tryParse(value);
    if (dt == null) return null;
    if (dt.isUtc) return dt.toLocal();
    return DateTime.utc(
      dt.year,
      dt.month,
      dt.day,
      dt.hour,
      dt.minute,
      dt.second,
      dt.millisecond,
      dt.microsecond,
    ).toLocal();
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

