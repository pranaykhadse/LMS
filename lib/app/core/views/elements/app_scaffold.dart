import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/core/providers/shell_destination_provider.dart';
import 'package:lms/app/features/courses/view/lms_app_bar.dart';
import 'package:lms/app/features/dashboard/view/app_drawer.dart';

/// Shared page shell for every top-level screen. On a phone it behaves the
/// same as before (hamburger + slide-out AppDrawer); on a tablet/desktop
/// window navigation moves into a horizontal nav bar under the top app
/// bar instead (see LmsAppBar's `isWide` mode). The body spans the full
/// window width, same as the header above it.
///
/// When hosted inside [MainShell] (the desktop nav bar's top-level
/// destinations), this skips rendering its own header entirely and just
/// publishes its params for the shell's single persistent LmsAppBar to use
/// instead - see ShellMarker/shellHeaderConfigProvider. Pages reached via a
/// normal push (course detail, notifications, account settings, etc.)
/// aren't inside that subtree and keep their own full header as before.
class AppScaffold extends ConsumerWidget {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTablet = Responsive.isTablet(context);

    final content = isTablet
        ? Padding(
            padding: const EdgeInsets.only(top: 14),
            child: body,
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

    if (isTablet && ShellMarker.isInShell(context)) {
      // Publish this tab's header params for MainShell's single persistent
      // LmsAppBar to pick up, instead of building our own. Deferred to next
      // frame since providers can't be written mid-build.
      final config = ShellHeaderConfig(
        title: title,
        centerTitle: centerTitle,
        selectedLabel: selectedLabel,
        selectedSubLabel: selectedSubLabel,
        onBack: onBack,
        hideBack: hideBack,
        bottom: bottom,
        backgroundColor: backgroundColor,
        onRefresh: onRefresh,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(shellHeaderConfigProvider.notifier).state = config;
      });
      return Container(color: backgroundColor, child: content);
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
