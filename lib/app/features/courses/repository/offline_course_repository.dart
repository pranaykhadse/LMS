import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/model/course_class.dart';

import 'course_class_repository.dart';
import 'roaster_repository.dart';

// Hive key prefix for per-course class lists
const _classesKeyPrefix = "offline_classes_";

class OfflineCourseRepository {
  static final provider = Provider<OfflineCourseRepository>((ref) {
    return OfflineCourseRepository(
      classRepository: ref.watch(CourseClassRepository.provider),
      roasterRepository: ref.watch(RoasterRepository.provider),
      storage: ref.watch(LocalStorage.provider),
      userId: ref.watch(AuthStateNotifier.provider)?.user?.id?.toString() ?? "",
    );
  });

  final LocalStorage storage;

  OfflineCourseRepository({
    required this.userId,
    required this.storage,
    required this.roasterRepository,
    required this.classRepository,
  });
  final RoasterRepository roasterRepository;
  final CourseClassRepository classRepository;
  final String userId;
  Future<List<CourseClass>> download(Course course) async {
    final keys = await _getCachedKeys();
    final updatedKeys = {...keys, course.id?.toString()}.toList();

    // Fetch all pages of course classes.
    int totalPages = 1;
    int currentPage = -1;
    List<CourseClass> classes = [];
    do {
      currentPage++;
      final response = await classRepository.getData(
        currentPage,
        queryParams: <String, dynamic>{"course_id": course.id.toString()},
      );
      classes.addAll(response.data);
      totalPages = response.pageInfo.pages ?? 1;
    } while (currentPage < totalPages);

    // Fetch roaster data and build classId → recording_local_url map so that
    // Virtual Class recording files are included in the offline download.
    final roasterResponse = await roasterRepository.getData(
      courseId: course.id.toString(),
      userId: userId,
    );
    final Map<String, String> recUrlByClassId = {};
    for (final roaster in roasterResponse.data) {
      final lec = roaster.learningEventClass;
      if (lec is! Map) continue;
      final localRecs = lec['localRecordings'];
      if (localRecs is! List || localRecs.isEmpty) continue;
      final firstRec = localRecs[0];
      if (firstRec is! Map) continue;
      final url = firstRec['recording_local_url']?.toString().trim();
      if (url == null || url.isEmpty || url == '0') continue;
      final classId = roaster.classId?.toString();
      if (classId != null) recUrlByClassId[classId] = url;
    }

    // Enrich Virtual Class (type=3) entries with the recording URL so that
    // CourseClass.recordingUrls returns it and OfflineViewModel queues it.
    final enrichedClasses = classes.map((c) {
      if (c.classInfo?.type != '3') return c;
      final recUrl = recUrlByClassId[c.classId];
      if (recUrl == null) return c;
      final newRawLec = Map<dynamic, dynamic>.from(c.rawLec ?? {})
        ..['training_session_recording_link'] = recUrl;
      return c.copyWith(rawLec: newRawLec);
    }).toList();

    await storage.setString(course.id?.toString() ?? "", course.toRawJson());
    await storage.setString("cached_courses", jsonEncode(updatedKeys));

    // Persist enriched class list (recordings included) for offline access.
    await saveClasses(course.id?.toString() ?? "", enrichedClasses);

    return enrichedClasses;
  }

  // ── Offline class list ─────────────────────────────────────────────────────

  /// Saves [classes] for [courseId] to local storage.
  Future<void> saveClasses(String courseId, List<CourseClass> classes) async {
    final encoded = jsonEncode(
      classes.map((c) => c.toJson()).toList(),
    );
    await storage.setString("$_classesKeyPrefix$courseId", encoded);
  }

  /// Returns the locally cached class list for [courseId], or an empty list.
  Future<List<CourseClass>> getCachedClasses(String courseId) async {
    try {
      final raw = await storage.getString("$_classesKeyPrefix$courseId");
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .map((e) => CourseClass.fromJson(e as Map<dynamic, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Course>> getCachedCourses() async {
    try {
      final decodedCC = await _getCachedKeys();
      final courses = <Course>[];
      for (var key in decodedCC) {
        try {
          final raw = await storage.getString(key);
          courses.add(Course.fromRawJson(raw ?? ""));
        } catch (e) {}
      }
      return courses;
    } catch (e) {}
    return [];
  }

  /// Removes a course and its class list from local storage.
  /// Does NOT delete the individual cached files (videos/PDFs) — the caller
  /// ([OfflineViewModel]) handles that via [FileCacheViewModel].
  Future<void> removeCourse(Course course) async {
    final courseKey = course.id?.toString() ?? "";
    final classesKey = "$_classesKeyPrefix$courseKey";

    // Remove from the cached-keys index.
    final keys = await _getCachedKeys();
    keys.remove(courseKey);
    await storage.setString("cached_courses", jsonEncode(keys));

    // Delete course JSON and class-list JSON.
    await storage.setString(courseKey, null);
    await storage.setString(classesKey, null);
  }

  Future<List<String>> _getCachedKeys() async {
    final cachedCoursesRaw = await storage.getString("cached_courses");
    if (cachedCoursesRaw == null || cachedCoursesRaw.isEmpty) return [];
    try {
      final decodedCC = jsonDecode(cachedCoursesRaw);
      if (decodedCC is! List) return [];
      return decodedCC.map((e) => e.toString()).toList();
    } catch (e) {}
    return [];
  }
}
