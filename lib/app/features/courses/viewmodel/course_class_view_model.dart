import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/logic/data_state/paginated_data.dart';
import 'package:lms/app/core/logic/vm_helper/base_view_model.dart';
import 'package:lms/app/features/courses/model/course_class.dart';
import 'package:lms/app/features/courses/repository/offline_course_repository.dart';
import 'package:lms/app/features/courses/repository/roaster_repository.dart';

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
          roasterRepository: ref.watch(RoasterRepository.provider),
          courseId: courseId,
        );
      });

  final String? courseId;
  final OfflineCourseRepository offlineCourseRepository;
  final RoasterRepository roasterRepository;

  CourseClassViewModel({
    required super.repository,
    required this.offlineCourseRepository,
    required this.roasterRepository,
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
      // Enrich Virtual Class events with recording links in the background.
      _enrichVirtualClassData(classes);
    }
  }

  // Logs every event at course-load time for debugging.
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
      if (info?.type == '3') {
        final rec = cc.rawLec?['training_session_recording_link']?.toString() ?? '';
        debugPrint(
          '    [VirtualClass] recording_link from allcourse/events = '
          '"${rec.isEmpty ? "<absent>" : rec}"',
        );
      }
    }
    debugPrint('══ [CourseEvents] end ══');
  }

  // For each Virtual Class event missing training_session_recording_link,
  // call the LEC view endpoint to fetch the full record and merge it in.
  Future<void> _enrichVirtualClassData(List<CourseClass> classes) async {
    bool updated = false;
    final enriched = List<CourseClass>.from(classes);

    for (int i = 0; i < enriched.length; i++) {
      final cc = enriched[i];
      if (cc.classInfo?.type != '3') continue;

      // Skip if recording link is already present.
      final existing = cc.rawLec?['training_session_recording_link']?.toString() ?? '';
      if (existing.isNotEmpty && existing != '0') continue;

      debugPrint('[VirtualClass] classId=${cc.classId} lecId=${cc.id} — fetching full LEC record…');

      Map<dynamic, dynamic>? lecData;

      // Attempt 1: by LEC id
      if (cc.id != null) {
        lecData = await roasterRepository.fetchLecById(cc.id!);
        if (lecData != null) {
          debugPrint('[VirtualClass] fetchLecById(${cc.id}) keys: ${lecData.keys.toList()}');
        } else {
          debugPrint('[VirtualClass] fetchLecById(${cc.id}) returned null');
        }
      }

      // Attempt 2: by class_id + course_id
      if (lecData == null && cc.classId != null && cc.courseId != null) {
        lecData = await roasterRepository.fetchLecByClass(
          classId: cc.classId!,
          courseId: cc.courseId!,
        );
        if (lecData != null) {
          debugPrint('[VirtualClass] fetchLecByClass(classId=${cc.classId}) keys: ${lecData.keys.toList()}');
        } else {
          debugPrint('[VirtualClass] fetchLecByClass(classId=${cc.classId}) returned null');
        }
      }

      if (lecData == null) {
        debugPrint('[VirtualClass] classId=${cc.classId} — could not fetch LEC record from either endpoint');
        continue;
      }

      final recLink = lecData['training_session_recording_link']?.toString() ?? '';
      debugPrint('[VirtualClass] classId=${cc.classId}  training_session_recording_link="$recLink"');

      // Merge fetched data into rawLec (existing fields take lower priority).
      final mergedLec = <dynamic, dynamic>{
        if (cc.rawLec != null) ...cc.rawLec!,
        ...lecData,
      };
      enriched[i] = cc.copyWith(rawLec: mergedLec);
      updated = true;
    }

    if (updated) {
      debugPrint('[CourseClassVM] Updating state with enriched Virtual Class data');
      state = state.copyWith(
        data: DataState.onData(enriched),
      );
      if (courseId != null) {
        offlineCourseRepository.saveClasses(courseId!, enriched);
      }
    }
  }
}
