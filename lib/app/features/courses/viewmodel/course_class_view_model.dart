import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
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
  Future<void> fetch([int page = 0]) async {
    await super.fetch(page);
    final classes = state.data.data;
    if (classes != null && classes.isNotEmpty && courseId != null) {
      _logAllEvents(classes);
      offlineCourseRepository.saveClasses(courseId!, classes);
    }
  }

  // Logs every event at course-load time for debugging.
  // Virtual Class events log their rawLec fields so the recording link is visible.
  void _logAllEvents(List<CourseClass> classes) {
    if (!kDebugMode) return;
    debugPrint('══ [CourseEvents] courseId=$courseId  total=${classes.length} ══');
    for (var i = 0; i < classes.length; i++) {
      final cc = classes[i];
      final info = cc.classInfo;
      debugPrint(
        '── [${i + 1}/${classes.length}] '
        'classId=${cc.classId}  lecId=${cc.id}  '
        'type=${info?.type}  "${info?.name}"',
      );
      if (cc.rawLec != null) {
        for (final e in cc.rawLec!.entries) {
          final v = e.value?.toString() ?? '';
          if (v.isNotEmpty && v != 'null' && v != '0') {
            debugPrint('    ${e.key}: $v');
          }
        }
      }
      // For Virtual Class: log the recording link status explicitly
      if (info?.type == '3') {
        final rec = cc.rawLec?['training_session_recording_link']?.toString() ?? '';
        debugPrint(
          '    [VirtualClass] training_session_recording_link = '
          '"${rec.isEmpty ? "<not provided by API>" : rec}"',
        );
      }
    }
    debugPrint('══ [CourseEvents] end ══');
  }
}
