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
      state = DataState.onError(error.toString());
    }
  }
}

int? _loggedInUserId(AuthState? auth) {
  return auth?.userProfile?.userId ?? auth?.user?.id;
}
