import 'package:flutter/widgets.dart';
import 'package:lms/app/core/localization/translate.dart';

import 'format_utils.dart';

extension SpaceExtensions on BuildContext {
  double get minorSpace => 8;
  double get smallSpace => 16;
  double get mediumSpace => 20;
  double get largeSpace => 25;
  double get xLargeSpace => 40;
}

extension RadiusExtensions on BuildContext {
  double get minorRadius => 4;
  double get smallRadius => 8;
  double get mediumRadius => 12;
  double get largeRadius => 18;
}

extension SizeExtension on BuildContext {
  double get smallSize => 12;
  double get mediumSize => 18;
  double get largeSize => 48;
}

extension ScreenResolutionExtension on BuildContext {
  Size get screenSize => MediaQuery.of(this).size;

  double ofLargest(double percentage) {
    return screenSize.longestSide * percentage;
  }

  double ofSmallest(double percentage) {
    return screenSize.shortestSide * percentage;
  }

  double ofWidth(double percentage) {
    return screenSize.width * percentage;
  }

  double ofHeight(double percentage) {
    return screenSize.height * percentage;
  }
}

String formatDate(BuildContext context, DateTime date) {
  final now = DateTime.now();
  // final difference = date.difference(now).inDays;

  // If the date is today
  if (isSameDay(date, now)) {
    return "today".translate(context);
  }
  // If the date is tomorrow
  else if (isSameDay(date, now.add(Duration(days: 1)))) {
    return "tomorrow".translate(context);
  }
  // For other days, display "Day of the week Date" (e.g., "Thursday 12")
  else {
    // Get day of the week (e.g., "Thursday")
    final dayOfMonth = date.toFormattedString(
      'EEEE, d MMM',
      context,
    ); // Get the day of the month (e.g., "12")
    return dayOfMonth;
  }
}

bool isSameDay(DateTime date1, DateTime date2) {
  return date1.year == date2.year &&
      date1.month == date2.month &&
      date1.day == date2.day;
}
