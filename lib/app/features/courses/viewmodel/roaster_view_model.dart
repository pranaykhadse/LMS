import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/logic/data_state/paginated_data.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/courses/model/course_class.dart';

import '../model/roaster.dart';
import '../repository/roaster_repository.dart';

class RoasterViewModel extends StateNotifier<PaginatedState<Roaster>> {
  static final provider = StateNotifierProvider.family
      .autoDispose<RoasterViewModel, PaginatedState<Roaster>, String?>((
        ref,
        courseId,
      ) {
        return RoasterViewModel(
          repository: ref.watch(RoasterRepository.provider),
          courseId: courseId,
          userId: ref.watch(AuthStateNotifier.provider)?.user?.id,
        );
      });

  final String? courseId;
  final int? userId;
  final RoasterRepository repository;

  RoasterViewModel({
    required this.repository,
    required this.courseId,
    required this.userId,
  }) : super(PaginatedState(data: DataState.idle(), pageInfo: null)) {
    fetch();
  }

  Future<void> fetch() async {
    state = state.copyWith(data: DataState.loading());
    try {
      final data = await repository.getData(
        courseId: courseId ?? "",
        userId: userId?.toString() ?? "",
      );
      state = PaginatedState(
        data: DataState.onData(data.data),
        pageInfo: data.pageInfo,
      );
    } catch (e) {
      state = state.copyWith(data: DataState.onError(e.toString()));
    }
  }

  Future<void> markAsRead(CourseClass courseClass) async {
    await repository.saveRoaster(
      courseId ?? "",
      courseClass.classInfo?.id ?? "",
      userId?.toString() ?? "",
      courseClass.id ?? "",
    );
    fetch();
  }

  Roaster? getForClass(CourseClass courseClass) {
    return state.data.data?.firstWhereOrNull(
      (value) => value.classId?.toString() == courseClass.classId,
    );
  }
}
