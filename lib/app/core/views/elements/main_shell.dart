import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/core/providers/shell_destination_provider.dart';
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

/// Desktop entry point for the app's top-level nav destinations (Dashboard,
/// Course Catalog, My Courses submenu, Learning Paths, Points & Badges
/// submenu). Renders ONE persistent LmsAppBar/Scaffold and swaps only the
/// body underneath when the nav bar changes [currentShellDestinationProvider]
/// - unlike the old approach of each destination being its own Modular
/// route (which tore down and rebuilt the whole header, sliding the entire
/// screen, on every nav-bar click).
///
/// Drill-down pages reached from within a tab (course detail, notifications,
/// account settings, etc.) still push as normal Modular/Navigator routes on
/// top of this shell, with their own header and back button, same as before.
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
    // Tab-switching without navigation is a desktop nav-bar concept only -
    // mobile keeps its normal AppDrawer + per-page AppScaffold behavior.
    if (!Responsive.isTablet(context)) {
      return const DashboardPage();
    }

    final destination = ref.watch(currentShellDestinationProvider);
    final config = ref.watch(shellHeaderConfigProvider);

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
        // Key forces a fresh subtree per tab (own State, own scroll
        // position) while still keeping the header above untouched -
        // that's the whole point: only this swaps, not the header. The
        // tab's own AppScaffold still applies the usual top:14 padding.
        body: KeyedSubtree(
          key: ValueKey(destination),
          child: _bodyFor(destination),
        ),
      ),
    );
  }
}
