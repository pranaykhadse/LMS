import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/features/courses/viewmodel/calendar_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/course_catalog_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/completed_courses_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/dashboard_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/development_plan_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/enrolled_courses_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/my_courses_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/required_courses_view_model.dart';

/// Invalidates every screen's main data provider so whichever of them is
/// currently on screen (or gets navigated back to) refetches fresh data
/// instead of continuing to show whatever it had cached from before the
/// device went offline - called whenever connectivity comes back, whether
/// that's the user switching the manual "Offline Mode" toggle off or a real
/// network reconnect. Mirrors CourseJoinDetailViewModel's own
/// _refreshRelatedScreens, which does the same thing after an enroll/cancel.
void refreshAllOnReconnect(Ref ref) {
  ref.invalidate(CourseCatalogViewModel.provider);
  ref.invalidate(MyCoursesViewModel.provider);
  ref.invalidate(EnrolledCoursesViewModel.provider);
  ref.invalidate(CompletedCoursesViewModel.provider);
  ref.invalidate(RequiredCoursesViewModel.provider);
  ref.invalidate(DashboardViewModel.provider);
  ref.invalidate(DevelopmentPlanViewModel.provider);
  ref.invalidate(CalendarViewModel.provider);
}
