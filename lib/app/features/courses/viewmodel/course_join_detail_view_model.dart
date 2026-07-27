import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/authentication/model/auth_state.dart';
import 'package:lms/app/features/courses/model/course_join_detail.dart';
import 'package:lms/app/features/courses/repository/course_join_detail_repository.dart';
import 'package:lms/app/features/courses/viewmodel/calendar_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/course_catalog_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/offline_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/completed_courses_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/dashboard_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/development_plan_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/enrolled_courses_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/my_courses_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/required_courses_view_model.dart';

class CourseJoinDetailViewModel
    extends StateNotifier<DataState<CourseJoinDetail>> {
  CourseJoinDetailViewModel({
    required this.repository,
    required this.userId,
    required this.courseId,
    required this.ref,
  }) : super(DataState.idle<CourseJoinDetail>()) {
    fetch();
  }

  static final provider = StateNotifierProvider.autoDispose
      .family<CourseJoinDetailViewModel, DataState<CourseJoinDetail>, int>((
        ref,
        courseId,
      ) {
        final auth = ref.watch(AuthStateNotifier.provider);
        return CourseJoinDetailViewModel(
          repository: ref.watch(CourseJoinDetailRepository.provider),
          userId: _loggedInUserId(auth),
          courseId: courseId,
          ref: ref,
        );
      });

  final CourseJoinDetailRepository repository;
  final int? userId;
  final int courseId;
  final Ref ref;

  Future<void> fetch() async {
    if (userId == null) {
      state = DataState.onError('The logged-in user ID is unavailable.');
      return;
    }
    state = DataState.loading<CourseJoinDetail>();
    try {
      final result = await repository.fetch(
        userId: userId!,
        courseId: courseId,
      );
      state = DataState.onData(result);
    } catch (error) {
      state = DataState.onError(_friendlyError(error));
    }
  }

  /// Registers the current user for the whole course, then refreshes the
  /// detail so `isEnrolled`/`primaryAction` reflect the new state. Skips the
  /// loading state so the screen doesn't flash back to a spinner - the
  /// button itself shows its own in-flight state.
  Future<CourseEnrollResult> enroll() async {
    final result = await repository.register(courseId: courseId);
    if (result.success) {
      await _silentRefetch();
      _refreshRelatedScreens();
    }
    return result;
  }

  /// Cancels the registration - the whole course when [classId] is null, or
  /// just that class - then refreshes the detail (see [enroll]). Cancelling
  /// the whole course also deletes any of its content that was downloaded
  /// for offline access - once unenrolled, the user is no longer entitled
  /// to it.
  Future<CourseEnrollResult> cancelRegistration({int? classId}) async {
    final result = await repository.cancel(courseId: courseId, classId: classId);
    if (result.success) {
      if (classId == null) {
        await ref.read(OfflineViewModel.provider).removeOfflineByCourseId(courseId);
      }
      await _silentRefetch();
      _refreshRelatedScreens();
    }
    return result;
  }

  Future<void> _silentRefetch() async {
    if (userId == null) return;
    try {
      final result = await repository.fetch(userId: userId!, courseId: courseId);
      state = DataState.onData(result);
    } catch (_) {
      // Keep showing the previous (now stale) data rather than replacing
      // the whole screen with an error after a successful enroll/cancel.
    }
  }

  /// Enrollment status affects every other screen that lists or filters
  /// courses (catalog, my courses, enrolled/completed/required, dashboard,
  /// development plan, calendar). Invalidate them so any that are still
  /// alive (e.g. sitting underneath this page on the nav stack) refetch
  /// immediately instead of showing stale data when the user navigates back
  /// to them; ones that aren't currently alive just fetch fresh next time
  /// they're created anyway.
  void _refreshRelatedScreens() {
    ref.invalidate(CourseCatalogViewModel.provider);
    ref.invalidate(MyCoursesViewModel.provider);
    ref.invalidate(EnrolledCoursesViewModel.provider);
    ref.invalidate(CompletedCoursesViewModel.provider);
    ref.invalidate(RequiredCoursesViewModel.provider);
    ref.invalidate(DashboardViewModel.provider);
    ref.invalidate(DevelopmentPlanViewModel.provider);
    ref.invalidate(CalendarViewModel.provider);
  }
}

int? _loggedInUserId(AuthState? auth) {
  return auth?.userProfile?.userId ?? auth?.user?.id;
}

String _friendlyError(Object error) {
  final msg = error.toString().toLowerCase();
  if (msg.contains('500') || msg.contains('server error')) {
    return 'The server encountered an error. Please try again later.';
  }
  if (msg.contains('401') || msg.contains('unauthorized') || msg.contains('invalid credentials')) {
    return 'Unauthorized';
  }
  if (msg.contains('404') || msg.contains('not found')) {
    return 'Course not found.';
  }
  if (msg.contains('socketexception') ||
      msg.contains('failed host lookup') ||
      msg.contains('connection refused') ||
      msg.contains('network is unreachable') ||
      msg.contains('no address associated')) {
    return 'No internet connection. Please check your network and try again.';
  }
  if (msg.contains('timeout') || msg.contains('timed out')) {
    return 'Request timed out. Please try again.';
  }
  return error.toString();
}
