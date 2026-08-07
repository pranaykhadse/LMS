import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The desktop nav bar's top-level destinations that live inside
/// [MainShell] (see main_shell.dart) - switching between these no longer
/// goes through Modular's navigator, so the header doesn't get torn down
/// and rebuilt (and the page doesn't slide) on every click.
enum ShellDestination {
  dashboard,
  courseCatalog,
  myEnrolledCourses,
  myCompletedCourses,
  myDevelopmentPlan,
  myRequiredCourses,
  learningPaths,
  badges,
  redeemPoints,
}

/// Which shell tab is currently showing.
final currentShellDestinationProvider =
    StateProvider<ShellDestination>((ref) => ShellDestination.dashboard);

/// Whatever the currently-visible tab's own `AppScaffold(...)` call passed
/// as its header params - published by AppScaffold (see app_scaffold.dart)
/// so MainShell's single persistent LmsAppBar can render the right
/// title/selected-nav-highlight/refresh-button for whichever tab is active,
/// without each tab owning its own AppBar.
final shellHeaderConfigProvider =
    StateProvider<ShellHeaderConfig>((ref) => const ShellHeaderConfig());

class ShellHeaderConfig {
  const ShellHeaderConfig({
    this.title,
    this.centerTitle = true,
    this.selectedLabel,
    this.selectedSubLabel,
    this.onBack,
    this.hideBack = false,
    this.bottom,
    this.backgroundColor,
    this.onRefresh,
  });

  final String? title;
  final bool centerTitle;
  final String? selectedLabel;
  final String? selectedSubLabel;
  final VoidCallback? onBack;
  final bool hideBack;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final VoidCallback? onRefresh;
}

/// Marks the subtree as living inside [MainShell] - `AppScaffold` checks
/// this to decide whether to render its own full header (normal
/// push/pop drill-down pages, e.g. course detail) or just publish its
/// config and render its body only (shell-hosted tabs).
class ShellMarker extends InheritedWidget {
  const ShellMarker({super.key, required super.child});

  static bool isInShell(BuildContext context) {
    return context.getElementForInheritedWidgetOfExactType<ShellMarker>() !=
        null;
  }

  @override
  bool updateShouldNotify(ShellMarker oldWidget) => false;
}
