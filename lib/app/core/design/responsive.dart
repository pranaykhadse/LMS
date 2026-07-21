import 'package:flutter/material.dart';

/// Shared breakpoints so every screen agrees on what counts as "phone",
/// "tablet", and "desktop" instead of each page picking its own width
/// threshold.
class Responsive {
  Responsive._();

  static const double tablet = 700;
  static const double desktop = 1024;
  static const double wide = 1400;

  static double widthOf(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isTablet(BuildContext context) => widthOf(context) >= tablet;
  static bool isDesktop(BuildContext context) => widthOf(context) >= desktop;

  /// Pick a value for the current screen width. Falls back to the next
  /// smaller tier when a larger one isn't supplied.
  static T value<T>(
    BuildContext context, {
    required T phone,
    T? tablet,
    T? desktop,
  }) {
    final width = widthOf(context);
    if (width >= Responsive.desktop) return desktop ?? tablet ?? phone;
    if (width >= Responsive.tablet) return tablet ?? phone;
    return phone;
  }

  /// Grid column count for the given width, scaling smoothly from phone to
  /// a large desktop window.
  static int columnsForWidth(
    double width, {
    required int phone,
    int? tablet,
    int? desktop,
    int? wide,
  }) {
    if (width >= Responsive.wide) return wide ?? desktop ?? tablet ?? phone;
    if (width >= Responsive.desktop) return desktop ?? tablet ?? phone;
    if (width >= Responsive.tablet) return tablet ?? phone;
    return phone;
  }

  static int columns(
    BuildContext context, {
    required int phone,
    int? tablet,
    int? desktop,
    int? wide,
  }) =>
      columnsForWidth(
        widthOf(context),
        phone: phone,
        tablet: tablet,
        desktop: desktop,
        wide: wide,
      );
}
