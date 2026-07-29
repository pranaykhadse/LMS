import 'dart:convert';

import 'package:dio/dio.dart' show Headers, Options;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/provider/local_storage_provider.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/courses/model/course_join_detail.dart';

class CourseEnrollResult {
  const CourseEnrollResult({required this.success, this.message});
  final bool success;
  final String? message;
}

class CourseJoinDetailRepository with RepoNetworkHelper {
  CourseJoinDetailRepository(this.config, this.storage);

  static final provider = Provider<CourseJoinDetailRepository>((ref) {
    return CourseJoinDetailRepository(
      ref.watch(ServerProvider.repoConfigProvider),
      ref.watch(LocalStorage.provider),
    );
  });

  @override
  final RepoNetworkConfig config;
  final LocalStorage storage;

  String _cacheKey(int courseId) => 'join_course_detail_$courseId';

  /// Fetches the course's full join-detail (structure, download links,
  /// enrollment status, etc.). Every successful fetch is cached raw so the
  /// same course can still be opened with no internet connection - falls
  /// back to that cache on any failure (offline, timeout, server error),
  /// and only surfaces the error if there's nothing cached to fall back to.
  Future<CourseJoinDetail> fetch({
    required int userId,
    required int courseId,
  }) async {
    try {
      final response = await getRequest(
        'lms-screen/join-course-detail',
        queryParameters: {'user_id': userId, 'id': courseId},
        cacheType: RequestCacheType.none,
      );
      final data = Map<String, dynamic>.from(response as Map);
      if (data['status']?.toString() != '1') {
        throw Exception(
          data['message']?.toString() ?? 'Unable to load course details.',
        );
      }
      await storage.setString(_cacheKey(courseId), jsonEncode(data));
      return CourseJoinDetail.fromJson(data);
    } catch (error) {
      final cachedRaw = await storage.getString(_cacheKey(courseId));
      if (cachedRaw != null) {
        try {
          final cachedData = jsonDecode(cachedRaw) as Map<String, dynamic>;
          return CourseJoinDetail.fromJson(cachedData);
        } catch (_) {
          // Cached data is unreadable - fall through to the original error.
        }
      }
      rethrow;
    }
  }

  /// Drops the cached detail for [courseId] - called when the user
  /// unenrolls from the whole course, so a stale "still enrolled" detail
  /// isn't served from cache afterwards.
  Future<void> clearCachedDetail(int courseId) =>
      storage.setString(_cacheKey(courseId), null);

  /// Whole-course enrollment (POST lms-screen/register-course, form-urlencoded).
  /// `user_id` is admin-only (registering someone else) and is resolved
  /// from the auth token for the current user. [classLearningEvents] maps
  /// classId -> learningEventClassId for every Virtual/In Person class that
  /// has an upcoming session - the API rejects the whole registration
  /// ("some classes require a session selection") if a class needing one
  /// isn't included here.
  Future<CourseEnrollResult> register({
    required int courseId,
    Map<int, int> classLearningEvents = const {},
  }) async {
    try {
      final body = <String, dynamic>{'course_id': courseId};
      if (classLearningEvents.isNotEmpty) {
        body['class_learning_events'] = jsonEncode({
          for (final entry in classLearningEvents.entries)
            entry.key.toString(): entry.value,
        });
      }
      final response = await post(
        'lms-screen/register-course',
        data: body,
        options: Options(contentType: Headers.formUrlEncodedContentType),
        cacheType: RequestCacheType.none,
      );
      final data = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};
      if (data['status']?.toString() != '1') {
        return CourseEnrollResult(
          success: false,
          message: data['message']?.toString() ?? 'Unable to enroll in this course.',
        );
      }
      return CourseEnrollResult(success: true, message: data['message']?.toString());
    } catch (e) {
      return CourseEnrollResult(success: false, message: e.toString());
    }
  }

  /// Single-class registration (same endpoint, single-class mode): pass
  /// `class_id` and, for Virtual/In Person classes, `learning_event_class_id`
  /// to select a specific session. Used by the per-item "Register" button
  /// on a Virtual Class structure item.
  Future<CourseEnrollResult> registerClass({
    required int courseId,
    required int classId,
    int? learningEventClassId,
  }) async {
    try {
      final response = await post(
        'lms-screen/register-course',
        data: {
          'course_id': courseId,
          'class_id': classId,
          if (learningEventClassId != null)
            'learning_event_class_id': learningEventClassId,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
        cacheType: RequestCacheType.none,
      );
      final data = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};
      if (data['status']?.toString() != '1') {
        return CourseEnrollResult(
          success: false,
          message: data['message']?.toString() ?? 'Unable to register for this class.',
        );
      }
      return CourseEnrollResult(success: true, message: data['message']?.toString());
    } catch (e) {
      return CourseEnrollResult(success: false, message: e.toString());
    }
  }

  /// Cancels the learner's registration (POST lms-screen/cancel-registration,
  /// form-urlencoded). Pass only `course_id` to cancel the entire course
  /// registration, or also `class_id` to cancel a single class only.
  /// `user_id` is admin-only and omitted here, same as [register].
  Future<CourseEnrollResult> cancel({required int courseId, int? classId}) async {
    try {
      final response = await post(
        'lms-screen/cancel-registration',
        data: {
          'course_id': courseId,
          if (classId != null) 'class_id': classId,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
        cacheType: RequestCacheType.none,
      );
      final data = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};
      if (data['status']?.toString() != '1') {
        return CourseEnrollResult(
          success: false,
          message: data['message']?.toString() ?? 'Unable to cancel registration.',
        );
      }
      return CourseEnrollResult(success: true, message: data['message']?.toString());
    } catch (e) {
      return CourseEnrollResult(success: false, message: e.toString());
    }
  }
}
