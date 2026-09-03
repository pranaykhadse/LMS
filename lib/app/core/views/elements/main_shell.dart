import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/core/providers/shell_destination_provider.dart';
import 'package:lms/app/core/views/elements/tablet_nav_bar.dart';
import 'package:lms/app/features/courses/view/courses_page.dart';
import 'package:lms/app/features/courses/view/lms_app_bar.dart';
import 'package:lms/app/features/dashboard/view/badges_page.dart';
import 'package:lms/app/features/dashboard/view/completed_courses_page.dart';
import 'package:lms/app/features/dashboard/view/dashboard_page.dart';
import 'package:lms/app/features/dashboard/view/development_plan_page.dart';
import 'package:lms/app/features/dashboard/view/enrolled_courses_page.dart';
import 'package:lms/app/features/dashboard/view/item_inventory_page.dart';
import 'package:lms/app/features/dashboard/view/learning_paths_page.dart';
import 'package:lms/app/features/dashboard/view/required_courses_page.dart';

/// Top-level navigation shell. Handles three device tiers:
///
/// • **Phone  (< 700 px)** — falls straight through to [DashboardPage];
///   each page owns its own [AppScaffold] with a hamburger [AppDrawer].
///
/// • **iPad / Tablet (700 – 1023 px)** — persistent mobile-style [LmsAppBar]
///   (purple, no horizontal nav) at the top + [TabletNavBar] (bottom tab
///   bar) for primary navigation. Body swaps via
///   [currentShellDestinationProvider] without rebuilding the header.
///
/// • **Desktop (≥ 1024 px)** — persistent two-row [LmsAppBar] (`isWide`)
///   with a horizontal nav bar; no bottom bar.
///
/// Drill-down pages pushed on top of this shell (course detail,
/// notifications, account settings, etc.) still get their own full
/// header via [AppScaffold] as before.
class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static Widget _bodyFor(ShellDestination destination) {
    switch (destination) {
      case ShellDestination.dashboard:
        return const DashboardPage();
      case ShellDestination.courseCatalog:
        return const CoursesPage();
      case ShellDestination.myEnrolledCourses:
        return const EnrolledCoursesPage();
      case ShellDestination.myCompletedCourses:
        return const CompletedCoursesPage();
      case ShellDestination.myDevelopmentPlan:
        return const DevelopmentPlanPage();
      case ShellDestination.myRequiredCourses:
        return const RequiredCoursesPage();
      case ShellDestination.learningPaths:
        return const LearningPathsPage();
      case ShellDestination.badges:
        return const BadgesPage();
      case ShellDestination.redeemPoints:
        return const ItemInventoryPage();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Phone: each page manages its own scaffold + AppDrawer ──────────────
    if (!Responsive.isTablet(context)) {
      return const DashboardPage();
    }

    final destination = ref.watch(currentShellDestinationProvider);
    final config = ref.watch(shellHeaderConfigProvider);

    final body = KeyedSubtree(
      key: ValueKey(destination),
      child: _bodyFor(destination),
    );

    // ── iPad / Tablet: mobile-style top app bar + bottom tab bar ──────────
    if (Responsive.isTabletOnly(context)) {
      return ShellMarker(
        child: Scaffold(
          backgroundColor: config.backgroundColor,
          appBar: LmsAppBar(
            title: config.title,
            centerTitle: config.centerTitle,
            onBack: config.onBack,
            hideBack: config.hideBack,
            bottom: config.bottom,
            // isWide: false → renders the purple mobile-style AppBar,
            // not the two-row desktop header.
            onRefresh: config.onRefresh,
          ),
          bottomNavigationBar: TabletNavBar(
            selectedLabel: config.selectedLabel,
            selectedSubLabel: config.selectedSubLabel,
          ),
          body: body,
        ),
      );
    }

    // ── Desktop: two-row header with horizontal nav bar ────────────────────
    return ShellMarker(
      child: Scaffold(
        backgroundColor: config.backgroundColor,
        appBar: LmsAppBar(
          title: config.title,
          centerTitle: config.centerTitle,
          onBack: config.onBack,
          hideBack: config.hideBack,
          bottom: config.bottom,
          isWide: true,
          onRefresh: config.onRefresh,
          selectedLabel: config.selectedLabel,
          selectedSubLabel: config.selectedSubLabel,
        ),
        body: body,
      ),
    );
  }
}
