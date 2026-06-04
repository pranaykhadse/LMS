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
      // Enrich Virtual Class events with full LEC data (recording link etc.) in
      // the background — state is already updated so the UI renders immediately.
      _enrichVirtualClassData(classes);
    }
  }

  // Dumps every event and every non-empty field at course-load time.
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
      // All top-level LEC fields from allcourse/events
      if (cc.rawLec != null) {
        for (final e in cc.rawLec!.entries) {
          final v = e.value?.toString() ?? '';
          if (v.isNotEmpty && v != 'null' && v != '0') {
            debugPrint('    ${e.key}: $v');
          }
        }
      }
      // Key ClassInfo fields not captured in rawLec
      final vcLink = info?.virtualClassLink ?? '';
      final alt    = info?.alternativeLearningEvent ?? '';
      if (vcLink.isNotEmpty && vcLink != '0') {
        debugPrint('    [ClassInfo.virtualClassLink] $vcLink');
      }
      if (alt.isNotEmpty && alt != '0') {
        debugPrint('    [ClassInfo.alternativeLearningEvent] $alt');
      }
    }
    debugPrint('══ [CourseEvents] end ══');
  }

  // For each Virtual Class event that is missing a recording link in rawLec,
  // call fetchLecView to get the full LEC record from the server and merge it
  // into rawLec. Runs after the initial state update so it doesn't block render.
  Future<void> _enrichVirtualClassData(List<CourseClass> classes) async {
    if (!mounted) return;

    final enriched = List<CourseClass>.from(classes);
    bool changed = false;

    for (var i = 0; i < enriched.length; i++) {
      final cc = enriched[i];
      if (cc.classInfo?.type != '3') continue;

      final existing =
          cc.rawLec?['training_session_recording_link']?.toString() ?? '';
      if (existing.startsWith('http')) {
        debugPrint(
          '[VirtualClass] classId=${cc.classId} '
          '— recording link already in rawLec',
        );
        continue;
      }

      final lecId = cc.id ?? '';
      if (lecId.isEmpty) {
        debugPrint(
          '[VirtualClass] classId=${cc.classId} '
          '— lecId empty, cannot fetch LEC record',
        );
        continue;
      }

      debugPrint(
        '[VirtualClass] classId=${cc.classId} lecId=$lecId '
        '— calling fetchLecView for full record...',
      );
      final lecData = await roasterRepository.fetchLecView(lecId);
      if (!mounted) return;

      if (lecData == null) {
        debugPrint(
          '[VirtualClass] classId=${cc.classId} '
          '— fetchLecView returned null',
        );
        continue;
      }

      debugPrint(
        '[VirtualClass] classId=${cc.classId} '
        '— LEC keys: ${lecData.keys.toList()}',
      );
      for (final e in lecData.entries) {
        final v = e.value?.toString() ?? '';
        if (v.isNotEmpty && v != 'null' && v != '0') {
          debugPrint('[VirtualClass] classId=${cc.classId}   ${e.key}: $v');
        }
      }

      final mergedLec = Map<dynamic, dynamic>.from(cc.rawLec ?? {})
        ..addAll(lecData);
      enriched[i] = cc.copyWith(rawLec: mergedLec);
      changed = true;
    }

    if (!changed || !mounted) return;

    debugPrint('[CourseClassVM] Updating state with enriched Virtual Class data');
    state = PaginatedState(
      data: DataState.onData(enriched),
      pageInfo: state.pageInfo,
    );
    if (courseId != null) {
      offlineCourseRepository.saveClasses(courseId!, enriched);
    }
  }
}
