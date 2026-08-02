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
  ref.invalidate(MyCoursesViewModel.provider);
  ref.invalidate(EnrolledCoursesViewModel.provider);
  ref.invalidate(CompletedCoursesViewModel.provider);
  ref.invalidate(RequiredCoursesViewModel.provider);
  ref.invalidate(DashboardViewModel.provider);
  ref.invalidate(DevelopmentPlanViewModel.provider);
  ref.invalidate(CalendarViewModel.provider);
  ref.invalidate(CourseJoinDetailViewModel.provider);
  ref.invalidate(CourseClassViewModel.provider);
  ref.invalidate(ViewCompetencyViewModel.provider);
  ref.invalidate(ItemInventoryViewModel.provider);
  ref.invalidate(LearningPathsViewModel.provider);
  ref.invalidate(LearningProgressViewModel.provider);
  ref.invalidate(RedeemHistoryViewModel.provider);
  ref.invalidate(DevPlanMembershipViewModel.provider);
  ref.invalidate(BadgesViewModel.provider);
  ref.invalidate(AccountSettingsViewModel.provider);
}
