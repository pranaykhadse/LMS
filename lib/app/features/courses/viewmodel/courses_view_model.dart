import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/logic/data_state/paginated_data.dart';
import 'package:lms/app/core/logic/vm_helper/base_view_model.dart';
import 'package:lms/app/features/courses/model/course.dart';

import '../repository/course_repository.dart';

class CoursesViewModel extends BaseViewModel<Course> {
  static final provider =
      StateNotifierProvider<CoursesViewModel, PaginatedState<Course>>((ref) {
        return CoursesViewModel(
          repository: ref.watch(CourseRepository.provider),
        );
      });

  CoursesViewModel({required super.repository});

  @override
  Future<String?> fetch(int page) async {
    if (page != 0) {
      return super.fetch(page);
    }
    // Load ALL pages on initial fetch so My Courses tab can filter across
    // all enrolled courses, not just the 50 items on the current page.
    state = state.copyWith(data: DataState.loading());
    try {
      final first = await repository.getData(0);
      final all = List<Course>.from(first.data);
      final total = first.pageInfo.total ?? 0;
      final totalPages = first.pageInfo.pages ??
          (total > 0 ? ((total + 49) ~/ 50) : 1);
      for (int p = 1; p < totalPages; p++) {
        final next = await repository.getData(p);
        all.addAll(next.data);
      }
      state = PaginatedState(
        data: DataState.onData(all),
        pageInfo: first.pageInfo.copyWith(pages: 1),
      );
      return null;
    } catch (e) {
      final message = e.toString();
      state = state.copyWith(data: DataState.onError(message));
      return message;
    }
  }
}
