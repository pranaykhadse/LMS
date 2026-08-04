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
      if (!mounted) return;
      state = DataState.onData(result);
    } catch (error) {
      if (!mounted) return;
      state = DataState.onError(_friendlyError(error));
    }
  }

  /// Registers the current user for the whole course, then refreshes the
  /// detail so `isEnrolled`/`primaryAction` reflect the new state. Skips the
  /// loading state so the screen doesn't flash back to a spinner - the
  /// button itself shows its own in-flight state. [classLearningEvents]
  /// should be the learner's actual picks from the Register wizard when the
  /// course has classes requiring a session selection; falls back to
  /// auto-selecting each such class's earliest upcoming session if omitted.
  Future<CourseEnrollResult> enroll({Map<int, int>? classLearningEvents}) async {
    final selections =
        classLearningEvents ?? state.data?.classLearningEventSelections ?? const {};
    final result = await repository.register(
      courseId: courseId,
      classLearningEvents: selections,
    );
    if (result.success) {
      await _silentRefetch();
      _refreshRelatedScreens();
    }
    return result;
  }

  /// Registers for a single class/session (e.g. the per-item "Register"
  /// button on a Virtual Class structure item), rather than the whole
  /// course.
  Future<CourseEnrollResult> registerClass({
    required int classId,
    int? learningEventClassId,
  }) async {
    final result = await repository.registerClass(
      courseId: courseId,
      classId: classId,
      learningEventClassId: learningEventClassId,
    );
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
        await repository.clearCachedDetail(courseId);
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
      if (!mounted) return;
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
    // Refetch rather than invalidate for the catalog specifically - it's a
    // kept-alive provider holding whatever search/skill/behavior filter is
    // currently applied (see course_catalog_view_model.dart), and
    // invalidate() would throw that state away and rebuild it from scratch
    // unfiltered. fetch() reuses whatever's already in state.search/skillId/
    // behaviorId, so the enrollment-status refresh doesn't also silently
    // clear the user's filter.
    ref.read(CourseCatalogViewModel.provider.notifier).fetch();
    // Each of these is autoDispose - only touch ones ref.exists() confirms
    // are still actually alive. invalidate()ing one nobody is watching can
    // rebuild it, kick off its constructor's own fetch(), and then have it
    // disposed again before that fetch resolves once nothing ends up
    // watching the freshly-rebuilt instance either - "Bad state: Tried to
    // use X after `dispose` was called."
    for (final provider in [
      MyCoursesViewModel.provider,
      EnrolledCoursesViewModel.provider,
      CompletedCoursesViewModel.provider,
      RequiredCoursesViewModel.provider,
      DashboardViewModel.provider,
      DevelopmentPlanViewModel.provider,
      CalendarViewModel.provider,
    ]) {
      if (ref.exists(provider)) ref.invalidate(provider);
    }
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
