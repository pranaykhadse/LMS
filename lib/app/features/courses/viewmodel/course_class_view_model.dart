import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/paginated_data.dart';
import 'package:lms/app/core/logic/vm_helper/base_view_model.dart';
import 'package:lms/app/features/courses/model/course_class.dart';
import 'package:lms/app/features/courses/repository/offline_course_repository.dart';

import '../repository/course_class_repository.dart';

class CourseClassViewModel extends BaseViewModel<CourseClass> {
  static final provider = StateNotifierProvider.family
      .autoDispose<CourseClassViewModel, PaginatedState<CourseClass>, String?>((
        ref,
        courseId,
      ) {
        return CourseClassViewModel(
          repository: ref.watch(CourseClassRepository.provider),
          offlineCourseRepository: ref.watch(OfflineCourseRepository.provider),
          courseId: courseId,
        );
      });

  final String? courseId;
  final OfflineCourseRepository offlineCourseRepository;

  CourseClassViewModel({
    required super.repository,
    required this.offlineCourseRepository,
    required this.courseId,
  });

  @override
  Map<String, dynamic> get queryParams => {"course_id": courseId};

  @override
  Future<String?> fetch([int page = 0]) async {
    final error = await super.fetch(page);
    final classes = state.data.data;
    if (classes != null && classes.isNotEmpty && courseId != null) {
      offlineCourseRepository.saveClasses(courseId!, classes);
    }
    return error;
  }
}
