import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/model/course_class.dart';

import 'course_class_repository.dart';
import 'roaster_repository.dart';

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

    await roasterRepository.getData(
      courseId: course.id.toString(),
      userId: userId,
    );

    await storage.setString(course.id?.toString() ?? "", course.toRawJson());

    await storage.setString("cached_courses", jsonEncode(updatedKeys));
    return classes;
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
