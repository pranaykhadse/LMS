import 'package:flutter/material.dart';

/// Pins a fixed-height table header row to the top of a CustomScrollView
/// while the rows below it keep scrolling - used for every "sticky table
/// header" screen. The header itself still needs its own horizontal
/// scroll handling if the table is wider than the viewport; that's a
/// separate concern (see LinkedScrollControllers), this only handles the
/// vertical pinning.
class StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  const StickyHeaderDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(height: height, child: child);
  }

  @override
  bool shouldRebuild(covariant StickyHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}
