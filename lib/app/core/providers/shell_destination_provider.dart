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
  myRecommendedCourses,
  learningPaths,
  badges,
  redeemPoints,
}

/// Which shell tab is currently showing.
final currentShellDestinationProvider = StateProvider<ShellDestination>(
  (ref) => ShellDestination.dashboard,
);

/// Every shell tab visited before the current one, oldest first - lets the
/// header's back button reverse through tab switches the same way it
/// reverses through a normal push/pop stack, since switching shell tabs
/// never touches Navigator and so leaves no trace there on its own. Always
/// go through [navigateShell]/[goBackInShell] below rather than writing
/// [currentShellDestinationProvider] directly, or this falls out of sync.
final shellHistoryProvider = StateProvider<List<ShellDestination>>((ref) => []);

/// Switches the active shell tab, recording the tab being left so the back
/// button can return to it later. No-ops if [destination] is already
/// current (e.g. re-tapping the already-selected nav item).
void navigateShell(WidgetRef ref, ShellDestination destination) {
  final current = ref.read(currentShellDestinationProvider);
  if (current == destination) return;
  ref.read(shellHistoryProvider.notifier).state = [
    ...ref.read(shellHistoryProvider),
    current,
  ];
  ref.read(currentShellDestinationProvider.notifier).state = destination;
}

/// Pops the most recent tab off the shell history and makes it current
/// again. Returns false (no-op) if there's nothing to go back to - the
/// caller should treat that as "hide/disable the back button".
bool goBackInShell(WidgetRef ref) {
  final history = ref.read(shellHistoryProvider);
  if (history.isEmpty) return false;
  final previous = history.last;
  ref.read(shellHistoryProvider.notifier).state = history.sublist(
    0,
    history.length - 1,
  );
  ref.read(currentShellDestinationProvider.notifier).state = previous;
  return true;
}

/// Whatever the currently-visible tab's own `AppScaffold(...)` call passed
/// as its header params - published by AppScaffold (see app_scaffold.dart)
/// so MainShell's single persistent LmsAppBar can render the right
/// title/selected-nav-highlight/refresh-button for whichever tab is active,
/// without each tab owning its own AppBar.
final shellHeaderConfigProvider = StateProvider<ShellHeaderConfig>(
  (ref) => const ShellHeaderConfig(),
);

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
