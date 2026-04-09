import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/paginated_data.dart';
import 'package:lms/app/core/logic/vm_helper/base_view_model.dart';
import 'package:lms/app/features/courses/model/course.dart';

import '../repository/course_repository.dart';

class CoursesViewModel extends BaseViewModel<Course> {
  static final provider =
      StateNotifierProvider<CoursesViewModel, PaginatedState<Course>>((ref) {
        return CoursesViewModel(
          repository: ref.watch(CourseRepository.provider),
          // downladRepository: ref.watch(OfflineCourseRepository.provider)
        );
      });

  CoursesViewModel({required super.repository});
}
