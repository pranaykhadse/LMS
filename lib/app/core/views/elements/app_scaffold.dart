import 'package:flutter/material.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/features/courses/view/lms_app_bar.dart';
import 'package:lms/app/features/dashboard/view/app_drawer.dart';

/// Shared page shell for every top-level screen. On a phone it behaves the
/// same as before (hamburger + slide-out AppDrawer); on a tablet/desktop
/// window navigation moves into a horizontal nav bar under the top app
/// bar instead (see LmsAppBar's `isWide` mode), and the body's width is
/// capped so content doesn't stretch edge-to-edge on very wide windows.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.centerTitle = true,
    this.selectedLabel,
    this.selectedSubLabel,
    this.onBack,
    this.hideBack = false,
    this.bottom,
    this.backgroundColor,
    this.maxContentWidth = 1100,
    this.onRefresh,
  });

  final Widget body;
  final String? title;
  final bool centerTitle;
  final String? selectedLabel;
  final String? selectedSubLabel;
  final VoidCallback? onBack;

  /// Forces the back button off — see [LmsAppBar.hideBack].
  final bool hideBack;

  /// If provided, shows a refresh button in the app bar that re-runs
  /// whichever fetch this screen's data provider already uses (same API
  /// call it made last time), for a manual reload without a pull-to-refresh
  /// gesture (e.g. on desktop with a mouse).
  final VoidCallback? onRefresh;

  /// Optional app-bar bottom widget (e.g. a nav-tab bar or calendar toolbar).
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;

  /// Body content is centered and capped at this width on tablet/desktop
  /// so text/cards don't stretch uncomfortably wide.
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.isTablet(context);

    final content = isTablet
        ? Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: body,
              ),
            ),
          )
        : body;

    if (!isTablet) {
      return Scaffold(
        backgroundColor: backgroundColor,
        drawer: AppDrawer(
          selectedLabel: selectedLabel,
          selectedSubLabel: selectedSubLabel,
        ),
        appBar: LmsAppBar(
          title: title,
          centerTitle: centerTitle,
          onBack: onBack,
          hideBack: hideBack,
          bottom: bottom,
          onRefresh: onRefresh,
        ),
        body: content,
      );
    }

    // Desktop/tablet navigate via LmsAppBar's own horizontal nav bar
    // (isWide) instead of a persistent sidebar.
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: LmsAppBar(
        title: title,
        centerTitle: centerTitle,
        onBack: onBack,
        hideBack: hideBack,
        bottom: bottom,
        isWide: true,
        onRefresh: onRefresh,
        selectedLabel: selectedLabel,
        selectedSubLabel: selectedSubLabel,
      ),
      body: content,
    );
  }
}
