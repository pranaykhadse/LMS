import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/authentication/model/auth_state.dart';
import 'package:lms/app/features/courses/model/course_join_detail.dart';
import 'package:lms/app/features/courses/repository/course_join_detail_repository.dart';

class CourseJoinDetailViewModel
    extends StateNotifier<DataState<CourseJoinDetail>> {
  CourseJoinDetailViewModel({
    required this.repository,
    required this.userId,
    required this.courseId,
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
        );
      });

  final CourseJoinDetailRepository repository;
  final int? userId;
  final int courseId;

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
    if (result.success) await _silentRefetch();
    return result;
  }

  /// Cancels the registration - the whole course when [classId] is null, or
  /// just that class - then refreshes the detail (see [enroll]).
  Future<CourseEnrollResult> cancelRegistration({int? classId}) async {
    final result = await repository.cancel(courseId: courseId, classId: classId);
    if (result.success) await _silentRefetch();
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
