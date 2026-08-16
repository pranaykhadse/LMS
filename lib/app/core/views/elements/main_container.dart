import 'package:flutter/material.dart';
import 'package:lms/app/core/design/responsive.dart';

/// Caps a page's content to [Responsive.maxContentWidth] and centers it on
/// wide windows, instead of letting it stretch edge to edge. Used by
/// [AppScaffold] so every screen gets the same main container width; wrap
/// individual page bodies with this directly only when they don't go
/// through [AppScaffold].
class MainContainer extends StatelessWidget {
  const MainContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Responsive.maxContentWidth),
        child: child,
      ),
    );
  }
}
