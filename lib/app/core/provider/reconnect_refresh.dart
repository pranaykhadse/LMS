import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/features/courses/viewmodel/calendar_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/course_catalog_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/course_class_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/course_join_detail_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/account_settings_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/badges_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/completed_courses_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/dashboard_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/dev_plan_membership_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/development_plan_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/enrolled_courses_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/item_inventory_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/learning_paths_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/learning_progress_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/my_courses_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/recommended_courses_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/redeem_history_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/required_courses_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/view_competency_view_model.dart';

/// Invalidates every screen's data provider - list pages and family-keyed
/// detail pages alike - so whichever of them is currently on screen (or
/// gets navigated back to) refetches fresh data instead of continuing to
/// show whatever it had cached from before the device went offline. Called
/// whenever connectivity comes back, whether that's the user switching the
/// manual "Offline Mode" toggle off or a real network reconnect. Mirrors
/// CourseJoinDetailViewModel's own _refreshRelatedScreens, which does the
/// same thing after an enroll/cancel action.
///
/// Family providers (course detail, view competency, course structure) are
/// invalidated via the family reference itself rather than a specific key -
/// Riverpod invalidates every currently-active instance of that family when
/// you do this, without needing to know which keys are in use.
void refreshAllOnReconnect(Ref ref) {
  // Refetch rather than invalidate for the catalog - it's a kept-alive
  // provider holding whatever search/skill/behavior filter is currently
  // applied, and invalidate() would throw that away and rebuild it
  // unfiltered. fetch() reuses whatever's already in state.search/skillId/
  // behaviorId instead.
  ref.read(CourseCatalogViewModel.provider.notifier).fetch();

  // Every provider below is autoDispose. invalidate()ing one that's
  // already fully torn down (no screen currently watching it) is normally
  // a safe no-op - but if it's mid-teardown right as this fires (e.g. the
  // screen that was watching it just navigated away, or this whole
  // function is itself firing repeatedly off a flaky connectivity signal),
  // invalidate() can rebuild it, kick off its constructor's fetch(), and
  // then have it disposed again before that fetch resolves - "Bad state:
  // Tried to use X after `dispose` was called." Only touching providers
  // ref.exists() confirms are still actually alive avoids resurrecting
  // ones nobody is looking at, which was firing this crash for screens
  // completely unrelated to whatever the user was on.
  for (final provider in [
    MyCoursesViewModel.provider,
    EnrolledCoursesViewModel.provider,
    CompletedCoursesViewModel.provider,
    RequiredCoursesViewModel.provider,
    RecommendedCoursesViewModel.provider,
    DashboardViewModel.provider,
    DevelopmentPlanViewModel.provider,
    CalendarViewModel.provider,
    ItemInventoryViewModel.provider,
    LearningPathsViewModel.provider,
    LearningProgressViewModel.provider,
    RedeemHistoryViewModel.provider,
    DevPlanMembershipViewModel.provider,
    BadgesViewModel.provider,
    AccountSettingsViewModel.provider,
  ]) {
    if (ref.exists(provider)) ref.invalidate(provider);
  }
  // Family providers can't share the untyped list above (each key is a
  // distinct provider instance) - Riverpod's family-wide invalidate still
  // only affects keys that already exist, so these are already safe as-is.
  ref.invalidate(CourseJoinDetailViewModel.provider);
  ref.invalidate(CourseClassViewModel.provider);
  ref.invalidate(ViewCompetencyViewModel.provider);
}
