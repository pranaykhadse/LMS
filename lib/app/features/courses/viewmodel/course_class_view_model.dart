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

  // TODO: remove once backend includes training_session_recording_link
  //       in the allcourse/events response.
  static const _dummyRecordingUrl =
      'https://dwpfuyia3u2j6.cloudfront.net/fdNb996MNYiX2CK.m3u8';

  @override
  Future<void> fetch([int page = 0]) async {
    await super.fetch(page);
    final classes = state.data.data;
    if (classes != null && classes.isNotEmpty && courseId != null) {
      final patched = _injectDummyRecordingLinks(classes);
      _logAllEvents(patched);
      offlineCourseRepository.saveClasses(courseId!, patched);
      if (patched != classes) {
        state = PaginatedState(
          data: DataState.onData(patched),
          pageInfo: state.pageInfo,
        );
      }
    }
  }

  /// Temporary: injects a dummy recording URL into every Virtual Class (type 3)
  /// session that the backend hasn't provided a recording link for yet.
  /// Delete this method (and the _dummyRecordingUrl constant) once
  /// allcourse/events returns training_session_recording_link.
  List<CourseClass> _injectDummyRecordingLinks(List<CourseClass> classes) {
    bool changed = false;
    final result = classes.map((cc) {
      if (cc.classInfo?.type != '3') return cc;

      // Skip if real data already present
      final existingArray = cc.rawLec?['recording_links'];
      if (existingArray is List && (existingArray).isNotEmpty) return cc;
      final existingSingle =
          cc.rawLec?['training_session_recording_link']?.toString() ?? '';
      if (existingSingle.startsWith('http')) return cc;

      // Inject TWO dummy recording links to simulate the two-session scenario
      // visible in the admin panel (LEC ids 1300 + 1301).
      // Remove once backend sends real recording_links in allcourse/events.
      final mergedLec = Map<dynamic, dynamic>.from(cc.rawLec ?? {})
        ..['recording_links'] = [_dummyRecordingUrl, _dummyRecordingUrl];
      changed = true;
      return cc.copyWith(rawLec: mergedLec);
    }).toList();
    return changed ? result : classes;
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
